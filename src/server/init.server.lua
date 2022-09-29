-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local Common= script:FindFirstChild("metaboardCommon")
Common.Parent = game:GetService("ReplicatedStorage")

-- Services
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local BoardService = require(Common.BoardService)

-- Imports
local Config = require(Common.Config)
local DataStoreService = Config.Persistence.DataStoreService
local BoardServer = require(script.BoardServer)
local Persistence = require(script.Persistence)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Helper Functions
local indicateInvalidBoard = require(script.indicateInvalidBoard)

-- Script Globals
local ChangedSinceStore = {}

--[[
	Manually deliver the client scripts once the AdminCommands module has written
	the "canwrite" permissions" (if installed)
--]]
task.spawn(function()

	local Chat = game:GetService("Chat")
	local ChatModules = Chat:FindFirstChild("ChatModules")
	local AdminCommands = ChatModules and ChatModules:FindFirstChild("AdminCommands")

	if AdminCommands and not AdminCommands:GetAttribute("CanWritePermissionsSet") then

		if AdminCommands:GetAttribute("CanWritePermissionsSet") == nil then
			AdminCommands:GetAttributeChangedSignal("CanWritePermissionsSet"):Wait()
		end

		if not AdminCommands:GetAttribute("CanWritePermissionsSet") then
			error("Cannot start metaboard for clients without CanWritePermissionsSet")
		end

	end

	local metaBoardPlayer = script:FindFirstChild("metaboardPlayer")

	--[[
		When the player dies/respawns, children of the PlayerGui are deleted and
		replaced by the contents of StarterGui, unless they have `ResetOnSpawn`
		set to false.
	--]]
	local respawnProtector = Instance.new("ScreenGui")
	respawnProtector.Name = "metaboardPlayer-RespawnProtector"
	respawnProtector.ResetOnSpawn = false
	metaBoardPlayer.Parent = respawnProtector

	for _, player in ipairs(Players:GetPlayers()) do
		respawnProtector:Clone().Parent = player.PlayerGui
	end

	Players.PlayerAdded:Connect(function(player)
		respawnProtector:Clone().Parent = player.PlayerGui
	end)
end)


--[[
	Retrieve the datastore name (possibly waiting for MetaPortal)
--]]
local dataStore do
	local dataStoreName
	-- TODO: this fails to distinguish between places in Studio.
	-- See (PrivateServerKey appearance delay #14 issue)
	local metaPortal = ServerScriptService:FindFirstChild("metaportal")

	if metaPortal and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then

		if metaPortal:GetAttribute("PocketId") == nil then
			metaPortal:GetAttributeChangedSignal("PocketId"):Wait()
		end

		local pocketId = metaPortal:GetAttribute("PocketId")

		dataStoreName = "Pocket-"..pocketId

	else

		dataStoreName = Config.Persistence.DataStoreName
	end

	print("[metaboard] Using "..dataStoreName.." for Persistence DataStore")

	if not dataStoreName then
		warn("[metaboard] No DataStoreName given, not loading any boards")
		return
	end

	if Config.Persistence.RestoreDelay then
		
		task.wait(Config.Persistence.RestoreDelay)
	end

	dataStore = DataStoreService:GetDataStore(dataStoreName)
end

local function bindInstanceAsync(instance: Model | Part)
	
	if not instance:IsDescendantOf(workspace) then

		return
	end

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

	else

		local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)

		local success, result = Persistence.Restore(dataStore, boardKey, board)

		if success then
			
			board:LoadData({

				Figures = result.Figures,
				DrawingTasks = {},
				PlayerHistories = {},
				NextFigureZIndex = result.NextFigureZIndex,
				EraseGrid = result.EraseGrid,
				ClearCount = result.ClearCount,
			})

			board.DataChangedSignal:Connect(function()

				ChangedSinceStore[persistId] = board
			end)

			local beforeClear = function()
				task.spawn(function()
					board.ClearCount += 1
					local historyKey = Config.Persistence.BoardKeyToHistoryKey(boardKey, board.ClearCount)
					Persistence.StoreWhenBudget(dataStore, historyKey, board)
				end)
			end

			board:ConnectRemotes(beforeClear)
			board.Remotes.GetBoardData.OnServerInvoke = handleBoardDataRequest

		else

			indicateInvalidBoard(board, result)

		end
	end

	-- For external code to access 
	BoardService.Boards[instance] = board
end


for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do

	task.spawn(bindInstanceAsync, instance)
end

CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(bindInstanceAsync)

if Config.Persistence.ReadOnly then

	warn("[metaboard] Persistence is in ReadOnly mode, no changes will be saved.")
else

	-- Once all boards are restored, trigger auto-saving
	game:BindToClose(function()

		if next(ChangedSinceStore) then
			
			print(
				string.format(
					"[metaboard] Storing %d boards on-close. SetIncrementAsync budget is %s.",
					Dictionary.count(ChangedSinceStore),
					DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
				)
			)
		end

		for persistId, board in pairs(ChangedSinceStore) do

			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
			Persistence.StoreNow(dataStore, boardKey, board)
		end

		ChangedSinceStore = {}
	end)

	task.spawn(function()
		while true do

			task.wait(Config.Persistence.AutoSaveInterval)

			if next(ChangedSinceStore) then
				print(("[metaboard] Storing %d boards"):format(Dictionary.count(ChangedSinceStore)))
			end

			for persistId, board in pairs(ChangedSinceStore) do

				local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
				task.spawn(Persistence.StoreWhenBudget, dataStore, boardKey, board)
			end

			ChangedSinceStore = {}
		end
	end)
end

print(("[metaboard] Initialised (%s)"):format(script:FindFirstChild("version") and script.version.Value or "dev version"))