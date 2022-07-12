do
	-- Move folder/guis around if this is the package version of metaboard

	local metaBoardCommon = script:FindFirstChild("metaboardCommon")
	if metaBoardCommon then
		metaBoardCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local metaBoardPlayer = script:FindFirstChild("metaboardPlayer")
	if metaBoardPlayer then
		metaBoardPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end
end

-- Services
local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local BoardService = require(Common.BoardService)
--[[
	If a game is published this becomes the actual DataStoreService, otherwise
	it's a mock one that won't error in offline place files.
--]]
local DataStoreService = require(Common.Packages.MockDataStoreService)

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
local randomFigures = require(script.randomFigures)

-- Script Globals
local InstanceToBoard = {}
local PersistentBoards = {}
local ChangedSinceStore = {}
local persistenceDataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

local function bindInstance(instance: Model | Part)
	if not instance:IsDescendantOf(workspace) then
		return
	end

	-- For testing
	local randomised = CollectionService:HasTag(instance, "Randomised")

	local persistId: string? = instance:GetAttribute("PersistId")
	local loaded = not (persistId or randomised)

	local boardRemotes = BoardRemotes.new(instance)

	local board = BoardServer.new(instance, boardRemotes, persistId, loaded)
	InstanceToBoard[instance] = board

	--Connect the remote events to recieve updates when the board is loaded.
	if loaded then
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

		board._destructor:Add(board.DataChangedSignal:Connect(function()
			Set.add(ChangedSinceStore, board)
		end))
	elseif randomised then
		local figures = randomFigures(board:AspectRatio(), 5000, 10, 20)

		board:LoadData(figures, {}, {}, Dictionary.count(figures), nil)

		board.Loaded = true
		board.LoadedSignal:Fire()
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

	BoardService.BoardAdded:FireAllClients(instance, board.Remotes, board.PersistId)


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
local function saveChangedBoards()

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
			persistenceDataStore,
			committedFigures,
			board.NextFigureZIndex,
			board.PersistId
		)

		task.wait() -- TODO
	end

	ChangedSinceStore = {}
end

-- 5 seconds after startup, start restoring all of the boards.
task.delay(5, function()

	Persistence.RestoreAll(persistenceDataStore, PersistentBoards)

	-- Once all boards are restored, trigger auto-saving

	while true do
		task.wait(Config.AutoSaveInterval)
		saveChangedBoards()
	end
end)

game:BindToClose(function()
	saveChangedBoards()
end)
