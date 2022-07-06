do
	-- Move folder/guis around if this is the package version of metaboard

	local metaBoardCommon = script.Parent:FindFirstChild("metaboardCommon")
	if metaBoardCommon then
		metaBoardCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local metaBoardPlayer = script.Parent:FindFirstChild("metaboardPlayer")
	if metaBoardPlayer then
		metaBoardPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end
end

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
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
local miniPersistence = require(script.miniPersistence)
local randomFigures = require(script.randomFigures)

local InstanceToBoard = {}
local PersistentBoards = {}
local ChangedSinceStore = {}

local persistenceDataStore
--local persistenceDataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

local function bindInstance(instance: Model | Part)
	if not instance:IsDescendantOf(workspace) then
		return
	end

	local randomised = CollectionService:HasTag(instance, "Randomised")

	local persistId: string? = instance:GetAttribute("PersistId")
	local status = (persistId or randomised) and "NotLoaded" or "Loaded"

	local boardRemotes = BoardRemotes.new(instance)

	local board = BoardServer.new(instance, boardRemotes, persistId, status)
	InstanceToBoard[instance] = board

	board.Remotes.RequestBoardData.OnServerEvent:Connect(function(player)
		if board:Status() == "NotLoaded" then

			local connection
			connection = board.StatusChangedSignal:Connect(function(newStatus)
				if newStatus == "Loaded" then
					board.Remotes.RequestBoardData:FireClient(
						player,
						true, -- indicate successful request
						board.Figures,
						board.DrawingTasks,
						board.PlayerHistories,
						board.NextFigureZIndex
					)
					connection:Disconnect()
				end
			end)
		else
			board.Remotes.RequestBoardData:FireClient(
				player,
				true, -- indicate successful request
				board.Figures,
				board.DrawingTasks,
				board.PlayerHistories,
				board.NextFigureZIndex
			)
		end
	end)

	BoardService.BoardAdded:FireAllClients(instance, board)

	if persistId then
		table.insert(PersistentBoards, board)

		board.DataChangedSignal:Connect(function()
			Set.add(ChangedSinceStore, board)
		end)
	elseif randomised then
		local figures = randomFigures(board:AspectRatio(), math.random(1000, 8000), 10, 100)
		board:LoadData(figures, {}, {}, Dictionary.count(figures), nil)
	
		board:SetStatus("Loaded")
	else
		board:SetStatus("Loaded")
	end
end

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
		table.insert(numericBoardTable, {
			Instance = board._instance,
			Remotes = board.Remotes,
			PersistId = board.PersistId,
		})
	end

	return numericBoardTable
end

local function saveChangedBoards()
	if next(ChangedSinceStore) then
		print(string.format("[MiniPersistence] Storing %d boards", Set.count(ChangedSinceStore)))
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
			miniPersistence.Store,
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
	miniPersistence.RestoreAll(persistenceDataStore, PersistentBoards)

	-- Once all boards are restored, trigger auto-saving

	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveInterval)
			saveChangedBoards()
		end
	end)
end)

game:BindToClose(function()
	saveChangedBoards()
end)
