-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Import
local Config = require(Common.Config)
local RunService = game:GetService("RunService")
local Board = require(Common.Board)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local JobQueue = require(Config.Debug and Common.InstantJobQueue or Common.JobQueue)
local Signal = require(Common.Packages.GoodSignal)
local Figure = require(Common.Figure)
local EraseGrid = require(Common.EraseGrid)
local Sift = require(Common.Packages.Sift)
local Dictionary = Sift.Dictionary

-- Helper Functions
local connectEvents = require(script.connectEvents)
local makePart = require(script.makePart)

-- BoardClient
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes, persistId: string?)
	local self = setmetatable(Board.new(instance, boardRemotes, persistId), BoardClient)

	self._status = "NotLoaded"
	self.StatusChangedSignal = Signal.new()

	self.BoardDataChangedSignal = Signal.new()
	self._changedSinceHeartbeat = false

	self._jobQueue = JobQueue.new()

	self._provisionalJobQueue = JobQueue.new()
	self._provisionalDrawingTasks = {}

	self.LocalHistoryChangedSignal = Signal.new()
	self.DrawingTaskChangedSignal = Signal.new()

	self._isClientLoaded = false

	self.ClickedSignal = Signal.new()
	self._destructor = Destructor.new()
	self._destructor:Add(function() self.ClickedSignal:DisconnectAll() end)

	local surfacePart do
		surfacePart = makePart("SurfacePart")
		surfacePart.CanQuery = true -- critical for buttons on surface gui
		surfacePart.Transparency = 1
		surfacePart.Size = Vector3.new(self:SurfaceSize().X, self:SurfaceSize().Y, Config.Canvas.CanvasThickness)
		surfacePart.CFrame = self:SurfaceCFrame()
		surfacePart.Parent = instance
		self._surfacePart = surfacePart

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Adornee = surfacePart
		surfaceGui.Parent = surfacePart

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = surfacePart

		local button = Instance.new("TextButton")
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Parent = surfaceGui

		self._destructor:Add(button.Activated:Connect(function()
			self.ClickedSignal:Fire()
		end))
	end

	return self
end

function BoardClient:DataChanged()
	self._changedSinceHeartbeat = true
end

function BoardClient:ConnectToRemoteClientEvents()
	connectEvents(self, Destructor.new())
end

function BoardClient:SetToolState(toolState)
	self._toolState = toolState
end

function BoardClient:GetToolState()
	return self._toolState
end

return BoardClient