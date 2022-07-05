-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local VRService = game:GetService("VRService")

-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)
local BoardRemotes = require(Common.BoardRemotes)
local EraseGrid = require(Common.EraseGrid)
local DrawingUI = require(script.DrawingUI)
local BoardService = require(Common.BoardService)
local Assets = require(Common.Assets)
local ViewStateManager = require(script.ViewStateManager)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local Roact: Roact = require(Common.Packages.Roact)

Roact.setGlobalConfig({
	defaultHostProps = {
		["Part"] = {
			Material = Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Anchored = true,
			CanCollide = false,
			CastShadow = false,
			CanTouch = false, -- Do not trigger Touch events
			CanQuery = false, -- Does not take part in e.g. GetPartsInPart
		},
	},
})

local InstanceToBoard = {}

local openedBoard = nil

local function bindBoardInstance(instance, remotes, persistId)
	-- Ignore if already seen this board
	if InstanceToBoard[instance] then
		return
	end

	local board = BoardClient.new(instance, remotes, persistId, "NotLoaded")

	do
		local connection
		connection = board.Remotes.RequestBoardData.OnClientEvent:Connect(
			function(success, figures, drawingTasks, playerHistories, nextFigureZIndex)
				if success then
					board:LoadData(figures, drawingTasks, playerHistories, nextFigureZIndex)
				end

				board:SetStatus("Loaded")

				connection:Disconnect()
			end
		)
	end

	board.Remotes.RequestBoardData:FireServer()

	local whenLoaded = function()

		local boardViewMode = "Gui"
		if not VRService.VREnabled then
			board.ClickedSignal:Connect(function()
				if openedBoard == nil then
					DrawingUI.Open(board, boardViewMode, function()
						openedBoard = nil
					end)
					openedBoard = board
				end
			end)
		end

		board:ConnectToRemoteClientEvents()

		InstanceToBoard[instance] = board
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
	local boards = BoardService.GetBoards:InvokeServer()

	for _, board in ipairs(boards) do
		bindBoardInstance(board.Instance, board.Remotes, board.PersistId)
	end
end

local viewStateManager = ViewStateManager.new()

task.spawn(function()
	while true do
		local loadedBoards = Dictionary.filter(InstanceToBoard, function(board)
			return board:Status() == "Loaded"
		end)

		viewStateManager:UpdateWithAllActive(loadedBoards)
		task.wait(2)
	end
end)
