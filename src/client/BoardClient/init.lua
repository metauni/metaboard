-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Import
local Config = require(Common.Config)
local RunService = game:GetService("RunService")
local Board = require(Common.Board)
local PartCanvas = require(Common.Canvas.PartCanvas)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local Pen = require(Common.DrawingTool.Pen)
local Eraser = require(Common.DrawingTool.Eraser)
local History = require(Common.History)
local JobQueue = require(Config.Debug and Common.InstantJobQueue or Common.JobQueue)
local Signal = require(Common.Packages.GoodSignal)
local DrawingUI = require(script.Parent.DrawingUI)

-- Helper Functions
local connectEvents = require(script.connectEvents)
local makePart = require(script.makePart)

-- BoardClient
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes)
	local self = setmetatable(Board.new(instance, boardRemotes), BoardClient)

	
	self._jobQueue = JobQueue.new()
	
	self._provisionalJobQueue = JobQueue.new()
	self._provisionalDrawingTasks = {}
	
	self.LocalHistoryChangedSignal = Signal.new()
	
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
	
	self.Canvas = PartCanvas.new("Canvas", surfacePart)

	self.Canvas:ParentTo(self._instance)

	return self
end



function BoardClient:GetToolState()
	return self._toolState
end

function BoardClient:StoreToolState(toolState)
	self._toolState = toolState
end

function BoardClient:ToolDown(drawingTask, canvasPos, canvas)
	self._provisionalDrawingTasks[drawingTask.TaskId] = drawingTask

	self._provisionalJobQueue:Enqueue(function(yielder)
		self.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)
		drawingTask:Init(self, canvasPos, canvas)
	end)

	-- Not storing a local drawing task *history*
	-- This would mean that you have to wait til you're caught up on the global
	-- queue to execute an undo. Is that a bad thing? Maybe? Maybe not?
end

function BoardClient:ToolMoved(drawingTask, canvasPos, canvas)
	self._provisionalJobQueue:Enqueue(function(yielder)
		self.Remotes.UpdateDrawingTask:FireServer(canvasPos)
		drawingTask:Update(self, canvasPos, canvas)
	end)
end

function BoardClient:ToolLift(drawingTask, canvas)
	self._provisionalJobQueue:Enqueue(function()
		self.Remotes.FinishDrawingTask:FireServer()
		drawingTask:Finish(self, canvas)
	end)
end

function BoardClient:OpenUI()

	local connection = RunService.RenderStepped:Connect(function()
		self._provisionalJobQueue:RunJobsUntilYield(coroutine.yield)
	end)

	DrawingUI.Open(self, function()
		connection:Disconnect()
		self._provisionalJobQueue:Clear()
	end)
end

function BoardClient:LoadData()
	if not self._isClientLoaded then

		local connection
		connection = self.Remotes.RequestBoardData.OnClientEvent:Connect(function(drawingTasks, playerHistories)

			for taskId, drawingTask in pairs(drawingTasks) do
				DrawingTask[drawingTask.TaskType].AssignMetatables(drawingTask)
				if not drawingTask.Undone then
					 drawingTask:Show(self, self.Canvas)
				end
			end

			for player, playerHistory in pairs(playerHistories) do
				setmetatable(playerHistory, History)
			end

			self.DrawingTasks = drawingTasks
			self.PlayerHistory = playerHistories

			self._inactiveDestructor = Destructor.new()
			connectEvents(self, self._inactiveDestructor)
			self._isClientLoaded = true

			print("Loaded "..self._instance.Name)

			connection:Disconnect()
		end)

		self.Remotes.RequestBoardData:FireServer()
	end

end

function BoardClient:UnloadData()
	if self._isClientLoaded then
		self._inactiveDestructor:Destroy()
		self.PlayerHistory = nil
		self.DrawingTasks = nil
		self.Canvas:Clear()
		print("Unloaded "..self._instance.Name)
	end

	self._isClientLoaded = false
end

return BoardClient