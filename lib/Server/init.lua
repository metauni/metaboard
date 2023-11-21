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
local Remotes = root.Remotes
local Config = require(root.Config)
local DataStoreService = Config.Persistence.DataStoreService
local BoardServer = require(script.BoardServer)
local Maid = require(script.Parent.Util.Maid)
local Persistence = require(root.Persistence)
local Binder = require(root.Util.Binder)
local Rxi = require(root.Util.Rxi)
-- local GoodSignal = require(root.Parent.GoodSignal)
local Promise = require(root.Util.Promise)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local Server = {

	_changedSinceStore = {},
}
Server.__index = Server

function Server:Init()
	self.BoardServerBinder = Binder.new("BoardServer", function(part: Part)
		return self:_bindBoardServer(part)
	end)
	self.BoardServerBinder:Init()
end

function Server:Start()

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
		1. Clients request things tagged as "metaboard" when they are close to them
			(and they don't have a local board setup yet)
		2. Server binds board as "BoardServer" object and loads data from datastore
		3. Once ready, Server tags board as "BoardClient"
		4. Client binds local board behaviour to this tag.
	]]
	Remotes.RequestBoardInit.OnServerEvent:Connect(function(_player: Player, part: Part)
		local board = self.BoardServerBinder:Bind(part)
		-- This will do nothing unless there's a datastore
		if board and self.DataStore and not board:IsLoadPending() then
			board:LoadFromDataStore(self.DataStore)
		end
	end)

	self.BoardServerBinder:Start()
end

function Server:_bindBoardServer(part: Part)

	local board = BoardServer.new(part)
	local persistId = board:GetPersistId()
	
	self._boardMaid = self._boardMaid or Maid.new()
	local cleanup = {}
	self._boardMaid[part] = cleanup

	table.insert(cleanup, board.Loaded.Changed:Connect(function(isLoaded: boolean)
		if isLoaded then
			board:ConnectRemotes()
			board:GetPart():AddTag("BoardClient")
		else -- Don't expect this to happen. Loaded is only changed to true
			board:GetPart():RemoveTag("BoardClient")
		end
	end))

	if persistId then
		table.insert(cleanup, board.StateChanged:Connect(function()
			self._changedSinceStore[persistId] = board
		end))
		table.insert(cleanup, board.BeforeClearSignal:Connect(function()
			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
			board.State.ClearCount = (board.State.ClearCount or 0) + 1
			local historyKey = Config.Persistence.BoardKeyToHistoryKey(boardKey, board.State.ClearCount)
			Persistence.StoreWhenBudget(self.DataStore, historyKey, board.State)
		end))
	end

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
			Persistence.StoreNow(self.DataStore, boardKey, board.State)
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
				task.spawn(Persistence.StoreWhenBudget, self.DataStore, boardKey, board.State)
			end
	
			self._changedSinceStore = {}
		end
	end)
end

function Server:GetBoard(instance: Part)
	return self.BoardServerBinder:Get(instance)
end

function Server:WaitForBoard(instance: Part)
	return self.BoardServerBinder:Promise(instance):Wait()
end

return Server