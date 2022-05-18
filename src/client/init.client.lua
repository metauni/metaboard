-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")


-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)
local BoardRemotes = require(Common.BoardRemotes)
local EraseGrid = require(Common.EraseGrid)
local DrawingUI = require(script.DrawingUI)
local BoardService = require(Common.BoardService)
local Assets = require(Common.Assets)

-- Helper functions
local boardLoader = require(script.boardLoader)
local makeSurfaceCanvas = require(script.makeSurfaceCanvas)

local Boards = {}

local openedBoard = nil
local canvasFolder = Instance.new("Folder")
canvasFolder.Name = "Canvases"
canvasFolder.Parent = workspace

local function bindBoardInstance(instance, remotes, persistId)

	-- Ignore if already seen this board
	if Boards[instance] then return end

	local board = BoardClient.new(instance, remotes, persistId)

	if board:Status() == "NotLoaded" then

		local connection
		connection = board.Remotes.RequestBoardData.OnClientEvent:Connect(function(success, figures, drawingTasks, playerHistories, nextFigureZIndex, eraseGrid)

			if success then
				board:LoadData(figures, drawingTasks, playerHistories, nextFigureZIndex, eraseGrid)
			end

			board:SetStatus("Loaded")

			connection:Disconnect()

		end)

		board.Remotes.RequestBoardData:FireServer()

	end

	local whenLoaded = function()

		local surfaceCanvasDestroyer = makeSurfaceCanvas(board, canvasFolder)

		--[[
			Pick one of these for different board view modes.
			Notice the workspace one destroys the surface canvas when the drawing UI
			opens and recreates it on close, whereas the gui one doesn't touch it.
		--]]

		----------------------------------------------------------------------------
		-- Workspace Board View Mode (move the camera to the board)
		----------------------------------------------------------------------------

		-- local boardViewMode = "Workspace"
		-- board.ClickedSignal:Connect(function()
		-- 	if openedBoard == nil then
		-- 		surfaceCanvasDestroyer()
		-- 		DrawingUI.Open(board, boardViewMode, function()
		-- 			openedBoard = nil
		-- 			surfaceCanvasDestroyer = makeSurfaceCanvas(board, canvasFolder)
		-- 		end)
		-- 		openedBoard = board
		-- 	end
		-- end)

		----------------------------------------------------------------------------
		-- Gui Board View Mode (show the board inside a viewport and draw gui curves)
		----------------------------------------------------------------------------

		local boardViewMode = "Gui"
		makeSurfaceCanvas(board, canvasFolder)
		board.ClickedSignal:Connect(function()
			if openedBoard == nil then
				DrawingUI.Open(board, boardViewMode, function()
					openedBoard = nil
				end)
				openedBoard = board
			end
		end)

		----------------------------------------------------------------------------

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


-- Preload all of the assets
do
	local assetList = {}
	for _, asset in pairs(Assets) do
		table.insert(assetList, asset)
	end

	task.spawn(function()
		ContentProvider:PreloadAsync(assetList)
		print("[metaboard] Assets preloaded")
	end)
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