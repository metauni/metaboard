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
local BoardRemotes = require(Common.BoardRemotes)
local Figure = require(Common.Figure)
local Persistence = require(script.Persistence)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Dictionary Operations
local merge = Dictionary.merge

-- Helper Functions
local indicateInvalidBoard = require(script.indicateInvalidBoard)

-- Script Globals
local InstanceToBoard = {}
local ChangedSinceStore = {}

BoardService.GetBoards.OnServerInvoke = function(player)
	--[[
		Cannot just pass `Boards` table, since the instance-keys get converted
		to strings, so if two boards instances have the same name, only one
		key-value pair will survive. Instead, we pass a numeric table of boards,
		and the client can extract the instance from each board.

		We also don't pass the whole board, just the critical data the client needs.
		Complex class-objects like Signals will probably trigger "tables cannot be
		cyclic".
	--]]

	local numericBoardTable = {}
	for _, board in pairs(InstanceToBoard) do

		-- Client will be a watcher now
		-- TODO: is there a better way to do this?
		board.Watchers[player] = true

		table.insert(numericBoardTable, {
			Instance = board._instance,
			Remotes = board.Remotes,
			PersistId = board.PersistId,
		})
	end

	return numericBoardTable
end

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

local function bindInstance(instance: Model | Part)
	if not instance:IsDescendantOf(workspace) then
		return
	end

	local persistIdValue = instance:FindFirstChild("PersistId")
	local persistId = persistIdValue and persistIdValue.Value

	local boardRemotes = BoardRemotes.new(instance)

	local board = BoardServer.new(instance, boardRemotes, persistId, persistId == nil)
	InstanceToBoard[instance] = board

	BoardService.BoardAdded:FireAllClients(instance, boardRemotes, persistId)

	-- Connect the remote events to receive updates when the board is loaded.

	if not persistId then
		board._destructor:Add(board.Remotes:Connect(board, nil))
	else

		task.spawn(function()

			local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)

			local success, result = Persistence.Restore(dataStore, boardKey, board)

			if success then
				
				board:LoadData(result.Figures, {}, {}, result.NextFigureZIndex, result.EraseGrid, result.ClearCount)
				board.Loaded = true
				board.LoadedSignal:Fire()

				local onClear = function()
					task.spawn(function()
						board.ClearCount += 1
						local historyKey = Config.Persistence.BoardKeyToHistoryKey(boardKey, board.ClearCount)
						Persistence.StoreWhenBudget(dataStore, historyKey, board)
					end)
				end
	
				board.Remotes:Connect(board, onClear)
			else

				indicateInvalidBoard(board, result)

			end

		end)
	end

	if persistId then

		board.DataChangedSignal:Connect(function()
			ChangedSinceStore[board] = true
		end)
	end

	--[[
		Clients request the data for boards via this event. The data is sent
		back via the same event immediately if the board is already loaded,
		otherwise it will be sent back when the loaded signal fires.
	--]]
	board.Remotes.RequestBoardData.OnServerEvent:Connect(function(player)

		if board.Loaded then

			board.Remotes.RequestBoardData:FireClient(
				player,
				true, -- indicate successful request
				board.Figures,
				board.DrawingTasks,
				board.PlayerHistories,
				board.NextFigureZIndex
			)

			board.Watchers[player] = true
		else

			local connection
			connection = board.LoadedSignal:Connect(function()

				board.Remotes.RequestBoardData:FireClient(
					player,
					true, -- indicate successful request
					board.Figures,
					board.DrawingTasks,
					board.PlayerHistories,
					board.NextFigureZIndex
				)

				board.Watchers[player] = true

				connection:Disconnect()
			end)

		end
	end)
end

--[[
	The server is in charge of deciding what becomes a metaboard. Clients
	retrieve boards directly from the server via BoardService, not via
	CollectionService.
--]]
CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(instance)
	bindInstance(instance)
end)

for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
	bindInstance(instance)
	task.wait()
end

if Config.Persistence.ReadOnly then

	warn("[metaboard] Persistence is in ReadOnly mode, no changes will be saved.")
else

	-- Once all boards are restored, trigger auto-saving
	game:BindToClose(function()

		if next(ChangedSinceStore) then
			
			print(
				string.format(
					"[metaboard] Storing %d boards on-close. SetIncrementAsync budget is %s.",
					Set.count(ChangedSinceStore),
					DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
				)
			)
		end

		for board in pairs(ChangedSinceStore) do

			local boardKey = Config.Persistence.PersistIdToBoardKey(board.PersistId)
			Persistence.StoreNow(dataStore, boardKey, board)
		end

		ChangedSinceStore = {}
	end)

	task.spawn(function()
		while true do

			task.wait(Config.Persistence.AutoSaveInterval)

			if next(ChangedSinceStore) then
				print(("[metaboard] Storing %d boards"):format(Set.count(ChangedSinceStore)))
			end

			for board in pairs(ChangedSinceStore) do

				local boardKey = Config.Persistence.PersistIdToBoardKey(board.PersistId)
				task.spawn(Persistence.StoreWhenBudget, dataStore, boardKey, board)
			end

			ChangedSinceStore = {}
		end
	end)
end

print(("[metaboard] Initialised (%s)"):format(script:FindFirstChild("version") and script.version.Value or "dev version"))