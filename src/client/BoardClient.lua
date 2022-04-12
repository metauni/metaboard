-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Import
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local PartCanvas = require(Common.Canvas.PartCanvas)
local BoardRemotes = require(Common.BoardRemotes)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local Pen = require(Common.DrawingTool.Pen)
local Eraser = require(Common.DrawingTool.Eraser)
local History = require(Common.History)
local JobQueue = require(Common.JobQueue)
local Signal = require(Common.Packages.GoodSignal)

local DrawingUI = require(script.Parent.DrawingUI)

-- BoardClient
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes)
	local self = setmetatable(Board.new(instance, boardRemotes), BoardClient)

	self._jobQueue = JobQueue.new()

	self._provisionalJobQueue = JobQueue.new()
	self._provisionalDrawingTasks = {}

	local destructor = Destructor.new()
	self._destructor = destructor

	self.LocalHistoryChangedSignal = Signal.new()

	-- Connect remote event callbacks to respond to init/update/finish's of a drawing task.
	-- The callbacks queue the changes to be made in the order they are triggered
	-- The order these remote events are received is the globally agreed order

	destructor:Add(self.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, taskType: string, drawingTask, pos: Vector2)
		drawingTask = setmetatable(drawingTask, DrawingTask[taskType])

		self._jobQueue:Enqueue(function(yielder)
			local playerHistory = self.PlayerHistory[player]
			if playerHistory == nil then
				playerHistory = History.new(Config.History.Capacity, function(dTask)
					return dTask.TaskId
				end)
				self.PlayerHistory[player] = playerHistory
			end

			do
				local pastForgetter = function(pastDrawingTask)
					pastDrawingTask:Commit(self, self.Canvas)
				end
				playerHistory:Push(drawingTask, pastForgetter)
			end
			
			drawingTask:Init(self, pos, self.Canvas)

			if player == Players.LocalPlayer then
				self.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
			end
		end)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, pos: Vector2)
		self._jobQueue:Enqueue(function(yielder)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Update(self, pos, self.Canvas)
		end)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Finish(self, self.Canvas)

			if player == Players.LocalPlayer then
				local provisionalDrawingTask = self._provisionalDrawingTasks[drawingTask.TaskId]
    		provisionalDrawingTask:Undo(self, self._provisionalCanvas)
			end
		end)
	end))


	destructor:Add(self.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)
			local playerHistory = self.PlayerHistory[player]
			local drawingTask = playerHistory:StepBackward()
			assert(drawingTask)
			drawingTask:Undo(self, self.Canvas)
			
			if player == Players.LocalPlayer then
				self.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
			end
		end)
	end))

	destructor:Add(self.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)
			local playerHistory = self.PlayerHistory[player]
			local drawingTask = self.PlayerHistory[player]:StepForward()
			assert(drawingTask)
			drawingTask:Redo(self, self.Canvas)

			if player == Players.LocalPlayer then
				self.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
			end
		end)
	end))

	RunService:BindToRenderStep("JobQueueProcessor", Enum.RenderPriority.Input.Value + 1, function()
		self._jobQueue:RunJobsUntilYield()
	end)

	destructor:Add(function()
		RunService:UnbindFromRenderStep("JobQueueProcessor")
	end)

	return self
end

function BoardClient.InstanceBinder(instance)
	-- This will yield until the remotes have replicated from the server
	local boardRemotes = BoardRemotes.WaitForRemotes(instance)

	local board = BoardClient.new(instance, boardRemotes)

	local canvas = PartCanvas.new(board, true, "MainCanvas")
	board:SetCanvas(canvas)
	canvas._instance.Parent = board._instance

	canvas.ClickedSignal:Connect(function()

		board._provisionalCanvas = PartCanvas.new(board, false, "ProvisionalCanvas")

		RunService:BindToRenderStep("ProvisionalJobQueueProcessor", Enum.RenderPriority.Input.Value + 1, function()
			board._provisionalJobQueue:RunJobsUntilYield()
		end)

		DrawingUI.Open(board, function()
			RunService:UnbindFromRenderStep("ProvisionalJobQueueProcessor")
      board._provisionalJobQueue:Clear()
			board._provisionalCanvas:Destroy()
		end)
	end)

	return board
end

function BoardClient:GetToolState()
	return self._toolState
end

function BoardClient:StoreToolState(toolState)
	self._toolState = toolState
end

function BoardClient:ToolDown(drawingTask, canvasPos)
	self._provisionalDrawingTasks[drawingTask.TaskId] = drawingTask

	self._provisionalJobQueue:Enqueue(function(yielder)
		self.Remotes.InitDrawingTask:FireServer(drawingTask.TaskType, drawingTask, canvasPos)
		drawingTask:Init(self, canvasPos, self._provisionalCanvas)
	end)

	-- Not storing a local drawing task *history*
	-- This would mean that you have to wait til you're caught up on the global
	-- queue to execute an undo. Is that a bad thing? Maybe? Maybe not?
end

function BoardClient:ToolMoved(drawingTask, canvasPos)
	self._provisionalJobQueue:Enqueue(function(yielder)
		self.Remotes.UpdateDrawingTask:FireServer(canvasPos)
		drawingTask:Update(self, canvasPos, self._provisionalCanvas)
	end)
end

function BoardClient:ToolLift(drawingTask)
	self._provisionalJobQueue:Enqueue(function()
		self.Remotes.FinishDrawingTask:FireServer()
		drawingTask:Finish(self, self._provisionalCanvas)
	end)
end

return BoardClient