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

--[[
	We use a fork of Roact so that Instances can have customised default
	properties, without blowing up the size of large roact trees.
--]]
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

	local board = BoardClient.new(instance, remotes, persistId, false)

	InstanceToBoard[instance] = board

	--[[
		Get prepared to receive the board data from the server and load it,
		then fire request event.
	--]]
	do
		local connection
		connection = board.Remotes.RequestBoardData.OnClientEvent:Connect(
			function(success, figures, drawingTasks, playerHistories, nextFigureZIndex)

				if success then
					board:LoadData(figures, drawingTasks, playerHistories, nextFigureZIndex)
					board.Loaded = true

					board.Remotes:Connect(board)
				else
					error("Failed board data request")
				end
				
				connection:Disconnect()
			end
		)

		board.Remotes.RequestBoardData:FireServer()
	end
end

--[[
	Preload all of the assets (so that they are shown immediately when needed)
	TODO: this doesn't work and seems to be a known bug.
	Explore subtle workarounds?
	Like showing the assets on screen at 95% transparency and very small?
--]]
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

BoardService.BoardAdded.OnClientEvent:Connect(function(instance: Part | Model, remotes, persistId: number?)
	bindBoardInstance(instance, setmetatable(remotes, BoardRemotes), persistId)
end)

do
	local boards = BoardService.GetBoards:InvokeServer()

	for _, board in ipairs(boards) do
		bindBoardInstance(board.Instance, setmetatable(board.Remotes, BoardRemotes), board.PersistId)
	end
end

local viewStateManager = ViewStateManager.new()

task.spawn(function()
	while true do
		local loadedBoards = Dictionary.filter(InstanceToBoard, function(board)
			return board.Loaded
		end)

		viewStateManager:UpdateWithAllActive(loadedBoards)
		task.wait(2)
	end
end)
