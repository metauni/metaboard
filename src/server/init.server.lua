do
	-- Move folder/guis around if this is the package version of metaboard

	local metaBoardCommon = script.Parent:FindFirstChild("MetaBoardCommon")
	if metaBoardCommon then
		metaBoardCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local metaBoardPlayer = script.Parent:FindFirstChild("MetaBoardPlayer")
	if metaBoardPlayer then
		metaBoardPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

end

-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local BoardService = require(Common.BoardService)

-- Imports
local Config = require(Common.Config)
local BoardServer = require(script.BoardServer)
local BoardRemotes = require(Common.BoardRemotes)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge

-- Helper Functions
local miniPersistence = require(script.miniPersistence)

local Boards = {}


local function bindInstance(instance: Model | Part)
	if not instance:IsDescendantOf(workspace) then return end

	local persistId: string? = instance:GetAttribute("PersistId")

	local boardRemotes = BoardRemotes.new(instance)

	local board = BoardServer.new(instance, boardRemotes, persistId)
	Boards[instance] = board

	board.Remotes.RequestBoardData.OnServerEvent:Connect(function(player)

		if board:Status() == "NotLoaded" then

			local connection
			connection = board.StatusChangedSignal:Connect(function(newStatus)
				if newStatus == "Loaded" then
					board.Remotes.RequestBoardData:FireClient(player, true, board.Figures, board.DrawingTasks, board.PlayerHistories, board.NextFigureZIndex)
					connection:Disconnect()
				end
			end)

		else

			board.Remotes.RequestBoardData:FireClient(player, true, board.Figures, board.DrawingTasks, board.PlayerHistories, board.NextFigureZIndex)

		end
	end)

	BoardService.BoardAdded:FireAllClients(instance, board)

	if persistId then

		task.spawn(function()

			local success, figures, nextFigureZIndex = miniPersistence.Restore(persistId)

			if success then
				board:LoadData(figures, {}, {}, nextFigureZIndex)
			else
				board:LoadData({}, {}, {}, 0)
			end

			board:SetStatus("Loaded")

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

	--[[ Cannot just pass `Boards` table, since the instance-keys get converted
		to strings, so if two boards instances have the same name, only one
		key-value pair will survive. Instead, we pass a numeric table of boards,
		and the client can extract the instance from each board. --]]

	local numericBoardTable = {}
	for _, board in pairs(Boards) do
		table.insert(numericBoardTable, board)
	end

	return numericBoardTable
end

task.delay(10, function()

	while true do
		print('Storing')
		for instance, board in pairs(Boards) do
			if board.PersistId then

				local committedFigures = board:CommitAllDrawingTasks()

				local removals = {}

				for figureId, figure in pairs(committedFigures) do
					if Figure.FullyMasked(figure) then
						removals[figureId] = Sift.None
					end
				end

				committedFigures = merge(committedFigures, removals)

				task.spawn(miniPersistence.Store, committedFigures, board.NextFigureZIndex, board.PersistId)
			end
		end
		task.wait(10)
	end

end)

	-- MetaBoard.Init()
-- PersonalBoardManager.Init()
-- ServerDrawingTasks.Init()

-- -- Delay loading persistent boards so as to avoid delaying server startup
-- task.delay( 5, Persistence.Init )