-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")


-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)
local BoardRemotes = require(Common.BoardRemotes)
local DrawingUI = require(script.DrawingUI)
local BoardService = require(Common.BoardService)

-- Helper functions
local boardLoader = require(script.boardLoader)
local makeSurfaceCanvas = require(script.makeSurfaceCanvas)

local Boards = {}

local openedBoard = nil

local function bindBoardInstance(instance, remotes, persistId)

	-- Ignore if already seen this board
	if Boards[instance] then return end

	local board = BoardClient.new(instance, remotes, persistId)

	if board:Status() == "NotLoaded" then

		local connection
		connection = board.Remotes.RequestBoardData.OnClientEvent:Connect(function(success, figures, drawingTasks, playerHistories, nextFigureZIndex)

			if success then
				board:LoadData(figures, drawingTasks, playerHistories, nextFigureZIndex)
			end

			board:SetStatus("Loaded")

			connection:Disconnect()

		end)

		board.Remotes.RequestBoardData:FireServer()

	end

	local whenLoaded = function()

		board.ClickedSignal:Connect(function()
			if openedBoard == nil then
				DrawingUI.Open(board, function()
					openedBoard = nil
				end)
				openedBoard = board
			end
		end)

		makeSurfaceCanvas(board)
		board:ConnectToRemoteClientEvents()


	end

	if board:Status() == "NotLoaded" then
		local connection
		connection = board.StatusChangedSignal:Connect(function(newStatus)
			if newStatus ~= "NotLoaded" then
				whenLoaded()
				connection:Disconnect()
			end
		end)
	else
		whenLoaded()
	end

end

BoardService.BoardAdded.OnClientEvent:Connect(function(instance, serverBoard)
	bindBoardInstance(instance, serverBoard.Remotes, serverBoard.PersistId)
end)

do
	local serverBoards = BoardService.GetBoards:InvokeServer()

	for _, serverBoard in ipairs(serverBoards) do
		bindBoardInstance(serverBoard._instance, serverBoard.Remotes, serverBoard.PersistId)
	end
end