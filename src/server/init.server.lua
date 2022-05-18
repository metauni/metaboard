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
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local BoardService = require(Common.BoardService)

-- Imports
local Config = require(Common.Config)
local BoardServer = require(script.BoardServer)
local BoardRemotes = require(Common.BoardRemotes)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)
local Array = Sift.Array

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge

-- Helper Functions
local miniPersistence = require(script.miniPersistence)

local InstanceToBoard = {}
local PersistentBoards = {}
local ChangedSinceStore = {}

local persistenceDataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

local function bindInstance(instance: Model | Part)
	if not instance:IsDescendantOf(workspace) then return end

	local persistId: string? = instance:GetAttribute("PersistId")

	local boardRemotes = BoardRemotes.new(instance)

	local board = BoardServer.new(instance, boardRemotes, persistId)
	InstanceToBoard[instance] = board

	board.Remotes.RequestBoardData.OnServerEvent:Connect(function(player)

		if board:Status() == "NotLoaded" then
			
			local connection
			connection = board.StatusChangedSignal:Connect(function(newStatus)
				if newStatus == "Loaded" then
					board.Remotes.RequestBoardData:FireClient(player, true, board.Figures, board.DrawingTasks, board.PlayerHistories, board.NextFigureZIndex, nil)
					connection:Disconnect()
				end
			end)

		else
			board.Remotes.RequestBoardData:FireClient(player, true, board.Figures, board.DrawingTasks, board.PlayerHistories, board.NextFigureZIndex, nil)

		end
	end)

	BoardService.BoardAdded:FireAllClients(instance, board)

	if persistId then

		table.insert(PersistentBoards, board)

		board.DataChangedSignal:Connect(function()
			ChangedSinceStore[board] = true
		end)


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
			_instance = board._instance,
			Remotes = board.Remotes,
			PersistId = board.PersistId
		})
	end

	return numericBoardTable
end


-- -- Delay loading persistent boards so as to avoid delaying server startup
task.delay(5, function()
	miniPersistence.RestoreAll(persistenceDataStore, PersistentBoards)

	-- task.delay(10, function()

	-- 	while true do
	-- 		print("checking if need to store")
	-- 		print(ChangedSinceStore)
	-- 		if next(ChangedSinceStore) then
	-- 			print('Storing')
	-- 		end
	
	-- 		for board in pairs(ChangedSinceStore) do
	-- 			local committedFigures = board:CommitAllDrawingTasks()
	
	-- 			local removals = {}
	
	-- 			for figureId, figure in pairs(committedFigures) do
	-- 				if Figure.FullyMasked(figure) then
	-- 					removals[figureId] = Sift.None
	-- 				end
	-- 			end
	
	-- 			committedFigures = merge(committedFigures, removals)
	
	-- 			task.spawn(miniPersistence.Store, persistenceDataStore, committedFigures, board.NextFigureZIndex, board.PersistId)
	-- 		end
			
	-- 		ChangedSinceStore = {}
	
	-- 		task.wait(10)
	-- 	end
	
	-- end)
end)

