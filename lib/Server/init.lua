-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local root = script.Parent
local Config = require(root.Config)
local DataStoreService = Config.Persistence.DataStoreService
local BoardServer = require(script.BoardServer)
local Persistence = require(root.Persistence)
local GoodSignal = require(root.Parent.GoodSignal)
local Promise = require(root.Parent.Promise)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Helper Functions
local indicateInvalidBoard = require(script.indicateInvalidBoard)

local Server = {

	Boards = {},
	_changedSinceStore = {},
	BoardAdded = GoodSignal.new(),
}
Server.__index = Server

function Server:promiseDataStore()

	return Promise.new(function(resolve, reject)

		-- TODO: this fails to distinguish between places in Studio.
		-- See (PrivateServerKey appearance delay #14 issue)

		local Pocket = ReplicatedStorage:FindFirstChild("Pocket")
		if not Pocket then
			resolve(DataStoreService:GetDataStore(Config.Persistence.DataStoreName))
		end
	
		if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
	
			if Pocket:GetAttribute("PocketId") == nil then
				Pocket:GetAttributeChangedSignal("PocketId"):Wait()
			end
	
			local pocketId = Pocket:GetAttribute("PocketId")
	
			resolve(DataStoreService:GetDataStore("Pocket-"..pocketId))
		elseif game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
			reject("[metaboard] Private Server use is not supported")
		else
			resolve(DataStoreService:GetDataStore(Config.Persistence.DataStoreName))
		end
	end)
end

function Server:Start()

	local function onRemoved(instance)
		
		local board = self.Boards[instance]
		if board then
			board:Destroy()
		end

		self.Boards[instance] = nil
	end
	
	local function bindInstanceAsync(instance: Part)
		if not instance:IsDescendantOf(workspace) and not instance:IsDescendantOf(ReplicatedStorage) then
			onRemoved(instance)
			return
		end

		if instance:IsA("Model") then
			error(`[metaboard] Model {instance:GetFullName()} tagged as metaboard. Must tag PrimaryPart instead.`)
		end
		assert(instance:IsA("Part"), "[metaboard] Tagged instance must be a Part: "..tostring(instance:GetFullName()))

		local persistIdValue = instance:FindFirstChild("PersistId")
		local persistId = persistIdValue and persistIdValue.Value
	
		local board = BoardServer.new(instance)
	
		-- Indicate that the board has been setup enough for clients to do their setup
		-- and request the board data.
		instance:SetAttribute("BoardServerInitialised", true)
	
		local handleBoardDataRequest = function(player)
			
			board.Watchers[player] = true
	
			return {
				
				Figures = board.Figures,
				DrawingTasks = board.DrawingTasks,
				PlayerHistories = board.PlayerHistories,
				NextFigureZIndex = board.NextFigureZIndex,
				EraseGrid = nil,
				ClearCount = nil
			}
		end
	
		if not persistId then
	
			board:ConnectRemotes(nil)
			board.Remotes.GetBoardData.OnServerInvoke = handleBoardDataRequest
			
			-- For external code to access
			self.Boards[instance] = board
			self.BoardAdded:Fire(board)
		else
	
			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
	
			self:promiseDataStore()
				:andThen(function(datastore: DataStore)
					
					local success, result = Persistence.Restore(datastore, boardKey, board)
					if success then
						return result, datastore
					else
						return result
					end
				end)
				:andThen(function(data, datastore: DataStore)
	
					board:LoadData({
						Figures = data.Figures,
						DrawingTasks = {},
						PlayerHistories = {},
						NextFigureZIndex = data.NextFigureZIndex,
						EraseGrid = data.EraseGrid,
						ClearCount = data.ClearCount,
					})
		
					board.DataChangedSignal:Connect(function()
						self._changedSinceStore[persistId] = board
					end)
		
					local beforeClear = function()
						task.spawn(function()
							board.ClearCount += 1
							local historyKey = Config.Persistence.BoardKeyToHistoryKey(boardKey, board.ClearCount)
							Persistence.StoreWhenBudget(datastore, historyKey, board)
						end)
					end
		
					board:ConnectRemotes(beforeClear)
					board.Remotes.GetBoardData.OnServerInvoke = handleBoardDataRequest
		
					-- For external code to access
					self.Boards[instance] = board
					self.BoardAdded:Fire(board)
				end)
				:catch(function(err)
					indicateInvalidBoard(board, tostring(err))
				end)
		end
	end
	
	for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
		task.spawn(bindInstanceAsync, instance)
	end
	
	CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(bindInstanceAsync)
	CollectionService:GetInstanceRemovedSignal(Config.BoardTag):Connect(onRemoved)
	
	if Config.Persistence.ReadOnly then
	
		warn("[metaboard] Persistence is in ReadOnly mode, no changes will be saved.")
	else


		Promise.retryWithDelay(function()
			return self:promiseDataStore()
				:andThen(function(datastore: DataStore)
					
					-- Once all boards are restored, trigger auto-saving
					game:BindToClose(function()
				
						if next(self._changedSinceStore) then
							
							print(
								string.format(
									"[metaboard] Storing %d boards on-close. SetIncrementAsync budget is %s.",
									Dictionary.count(self._changedSinceStore),
									DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
								)
							)
						end
				
						for persistId, board in pairs(self._changedSinceStore) do
				
							local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
							Persistence.StoreNow(datastore, boardKey, board)
						end
				
						self._changedSinceStore = {}
					end)
				
					task.spawn(function()
						while true do
				
							task.wait(Config.Persistence.AutoSaveInterval)
				
							if next(self._changedSinceStore) then
								print(("[BoardService] Storing %d boards"):format(Dictionary.count(self._changedSinceStore)))
							end
				
							for persistId, board in pairs(self._changedSinceStore) do
				
								local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
								task.spawn(Persistence.StoreWhenBudget, datastore, boardKey, board)
							end
				
							self._changedSinceStore = {}
						end
					end)
				end)
		end, 3, 1) -- retry 5 times, 10 second delay
		:catch(function(msg)
			warn("[metaboard] Failed to initialise Persistence: "..tostring(msg))
		end)
	end
end

function Server:GetBoard(instance: Part)
	return self.Boards[instance]
end

function Server:WaitForBoard(instance: Part)
	if self.Boards[instance] then
		return self.Boards[instance]
	end
	while true do
		local board = self.BoardAdded:Wait()
		if board._instance == instance then
			return board
		end
	end
end

return Server