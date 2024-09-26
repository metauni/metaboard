-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local root = script.Parent
local Remotes = root.Remotes
local Map = require(ReplicatedStorage.Util.Map)
local Stream = require(ReplicatedStorage.Util.Stream)
local Config = require(root.Config)
local DataStoreService = Config.Persistence.DataStoreService
local BoardServer = require(script.BoardServer)
local t = require(script.Parent.Parent.t)
local Persistence = require(root.Persistence)
local Promise = require(root.Util.Promise)
local Sift = require(root.Parent.Sift)

local ChangedSinceStore = {}

local Server = {
	Boards = Map({} :: {[BasePart]: BoardServer.BoardServer}),
}

function Server:Start()

	PhysicsService:RegisterCollisionGroup("Board")

	local promise = self:promiseDataStore()
		:Then(function(datastore: DataStore)
			self.DataStore = datastore
			if Config.Persistence.ReadOnly then
				warn("[metaboard] Persistence is in ReadOnly mode, no changes will be saved.")
			else
				self:_startAutoSaver()
			end
		end)
		:Catch(function(msg)
			error(`[metaboard] Failed to initialise datastore: {msg}`)
		end)

	task.delay(10, function()
		if promise:IsPending() then
			warn("[metaboard] Infinite yield possible for datastore")
		end
	end)

	--[[
		1. Clients fire remote event to request things tagged as "metaboard" when they are close to them
			(and they don't have a local board setup yet)
		2. Server tags valid metaboards as "BoardServer", and loads data from datastore
		3. Once ready, server tags board as "BoardClient"
		4. Client binds local board behaviour to this tag.
	]]
	Remotes.RequestBoardInit.OnServerEvent:Connect(function(_player: Player, part: Part)
		Server:MakeBoardServer(part)
	end)

	Remotes.RequestVRChalk.OnServerEvent:Connect(function(player: Player)
		local penToolTemplate = ReplicatedStorage:FindFirstChild("Chalk")
		assert(t.instanceOf("Tool", {
			Handle = t.instanceOf("MeshPart", {
				Attachment = t.instanceOf("Attachment")
			})
		})(penToolTemplate))

		local penTool: Tool = penToolTemplate:Clone()
		penTool.CanBeDropped = false
		penTool.Parent = player:WaitForChild("Backpack")
	end)
end

function Server:MakeBoardServer(part: BasePart)
	assert(t.instanceIsA("BasePart")(part))
	if not part:HasTag("metaboard") then
		error(`[metaboard] Remotes.RequestBoardInit for {part:GetFullName()} not tagged as metaboard`)
	end

	local board = Server.Boards:Get(part)
	if board then
		return board
	end

	board = BoardServer.new(part)

	local cleanup = {}

	-- This will do nothing unless there's a datastore
	if board and self.DataStore and not board:IsLoadPending() then
		board:LoadFromDataStore(self.DataStore)
	end

	-- I think my refactor of the Rupe-Goldberg machine has collapsed
	-- into what could just be "do this, yield, then do that" (see LoadFromDataStore above)
	table.insert(cleanup, board.Loaded.Changed:Connect(function(isLoaded: boolean)
		if isLoaded then
			board:ConnectRemotes()
			board:GetPart():AddTag("BoardClient")
		else -- Don't expect this to happen. Loaded is only changed to true
			board:GetPart():RemoveTag("BoardClient")
		end
	end))

	local persistId = board:GetPersistId()
	if persistId then
		table.insert(cleanup, board.StateChanged:Connect(function()
			ChangedSinceStore[persistId] = board
		end))
		table.insert(cleanup, board.BeforeClearSignal:Connect(function()
			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
			board.State.ClearCount = (board.State.ClearCount or 0) + 1
			local historyKey = Config.Persistence.BoardKeyToHistoryKey(boardKey, board.State.ClearCount)
			Persistence.StoreWhenBudget(self.DataStore, historyKey, board.State)
		end))
	end

	Server.Boards:SetTidy(part, board, cleanup)
	return board
end

function Server:promiseDataStore()

	return Promise.new(function(resolve, reject)

		-- TODO: this fails to distinguish between places in Studio.
		-- See (PrivateServerKey appearance delay #14 issue)

		local Pocket = ReplicatedStorage:FindFirstChild("OS"):FindFirstChild("Pocket")
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

function Server:_startAutoSaver()
	game:BindToClose(function()
	
		if next(ChangedSinceStore) then
			
			print(
				string.format(
					"[metaboard] Storing %d boards on-close. SetIncrementAsync budget is %s.",
					Sift.Dictionary.count(ChangedSinceStore),
					DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
				)
			)
		end
	
		for persistId, board in ChangedSinceStore do
	
			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
			Persistence.StoreNow(self.DataStore, boardKey, board.State)
		end
	
		ChangedSinceStore = {}
	end)
	
	task.spawn(function()
		while true do
	
			task.wait(Config.Persistence.AutoSaveInterval)
	
			if next(ChangedSinceStore) then
				print(("[BoardService] Storing %d boards"):format(Sift.Dictionary.count(ChangedSinceStore)))
			end
	
			for persistId, board in ChangedSinceStore do
	
				local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
				task.spawn(Persistence.StoreWhenBudget, self.DataStore, boardKey, board.State)
			end
	
			ChangedSinceStore = {}
		end
	end)
end

function Server:GetBoard(instance: Part)
	return self.Boards:Get(instance)
end

function Server:WaitForBoard(instance: Part)
	return self.Boards:Wait(instance)
end

return Server