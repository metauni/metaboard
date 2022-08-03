-- Services
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Common= script:FindFirstChild("metaboardCommon")
Common.Parent = game:GetService("ReplicatedStorage")
local BoardService = require(Common.BoardService)

-- Imports
local Config = require(Common.Config)
local BoardServer = require(script.BoardServer)
local BoardRemotes = require(Common.BoardRemotes)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Dictionary Operations
local merge = Dictionary.merge

-- Helper Functions
local Persistence = require(script.Persistence)

-- Script Globals
local InstanceToBoard = {}
local PersistentBoards = {}
local ChangedSinceStore = {}

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
	if persistId then
		board._destructor:Add(board.Remotes:Connect(board))
	else
		local connection
		connection = board.LoadedSignal:Connect(function()
			board.Remotes:Connect(board)
			connection:Disconnect()
		end)
	end

	if persistId then
		-- This table will be passed to persistence to load from the datastore
		table.insert(PersistentBoards, board)

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
CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(bindInstance)

for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
	bindInstance(instance)
end

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
	Save all of the persistent boards which have changed since the last save.
--]]
local function saveChangedBoards(dataStoreName)

	if next(ChangedSinceStore) then
		print(string.format("[Persistence] Storing %d boards", Set.count(ChangedSinceStore)))
	end

	for board in pairs(ChangedSinceStore) do
		-- Commit all of the drawing task changes (like masks) to the figures

		local committedFigures = board:CommitAllDrawingTasks()

		local removals = {}

		-- Remove the figures that have been completely erased
		for figureId, figure in pairs(committedFigures) do
			if Figure.FullyMasked(figure) then
				removals[figureId] = Sift.None
			end
		end

		committedFigures = merge(committedFigures, removals)

		task.spawn(
			Persistence.Store,
			dataStoreName,
			committedFigures,
			board.NextFigureZIndex,
			board.PersistId
		)

		task.wait() -- TODO
	end

	ChangedSinceStore = {}
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
local dataStoreName do
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
end

print("[Metaboard] Using "..dataStoreName.." for Persistence DataStore")

if Config.Persistence.ReadOnly then
	warn("[Metaboard] Persistence is in ReadOnly mode, no changes will be saved.")
end

Persistence.RestoreAll(dataStoreName, PersistentBoards)

-- Once all boards are restored, trigger auto-saving

if not Config.Persistence.ReadOnly then

	game:BindToClose(function()
		saveChangedBoards(dataStoreName)
	end)

	while true do
		task.wait(Config.Persistence.AutoSaveInterval)
		saveChangedBoards(dataStoreName)
	end
end