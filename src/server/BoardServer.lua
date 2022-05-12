-- Services

-- Import
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local JobQueue = require(Config.Debug and Common.InstantJobQueue or Common.JobQueue)
local DelayedJobQueue = require(Common.DelayedJobQueue)
local Signal = require(Common.Packages.GoodSignal)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge
local set = Dictionary.set

-- BoardServer
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part, boardRemotes, persistId: string?)
	-- A server board has no canvas, so we pass nil
	local self = setmetatable(Board.new(instance, boardRemotes, persistId), BoardServer)

	self._status = persistId and "NotLoaded" or "Loaded"
	self.StatusChangedSignal = Signal.new()

	self._jobQueue = JobQueue.new()

	local destructor = Destructor.new()
	self._destructor = destructor

	-- Respond to each remote event by repeating it to all of the clients, then
	-- performing the described change to the server's copy of the board

	destructor:Add(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			local verifiedDrawingTask = merge(drawingTask, { Verified = true })
			self.Remotes.InitDrawingTask:FireAllClients(player, verifiedDrawingTask, canvasPos)

			-- Get or create the player history for this player
			local playerHistory = self.PlayerHistories[player] or History.new(Config.History.Capacity)

			local initialisedDrawingTask = DrawingTask.Init(verifiedDrawingTask, self, canvasPos)
			self.DrawingTasks = set(self.DrawingTasks, initialisedDrawingTask.Id, initialisedDrawingTask)

			local pastForgetter = function(pastDrawingTask)
				self.Figures = DrawingTask.Commit(pastDrawingTask, self.Figures)
				self.DrawingTasks = set(self.DrawingTasks, initialisedDrawingTask.Id, nil)
			end

			local newHistory = playerHistory:Clone()
			newHistory:Push(initialisedDrawingTask, pastForgetter)

			self.PlayerHistories = set(self.PlayerHistories, player, newHistory)

		end)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.UpdateDrawingTask:FireAllClients(player, canvasPos)

			local drawingTask = self.PlayerHistories[player]:MostRecent()
			assert(drawingTask)

			local updatedDrawingTask = DrawingTask.Update(drawingTask, self, canvasPos)

			local newHistory = self.PlayerHistories[player]:Clone()
			newHistory:SetMostRecent(updatedDrawingTask)

			self.PlayerHistories = set(self.PlayerHistories, player, newHistory)

			self.DrawingTasks = set(self.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)
		end)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.FinishDrawingTask:FireAllClients(player, canvasPos)

			local drawingTask = self.PlayerHistories[player]:MostRecent()
			assert(drawingTask)

			local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, self), "Finished", true)

			local newHistory = self.PlayerHistories[player]:Clone()
			newHistory:SetMostRecent(finishedDrawingTask)

			self.PlayerHistories = set(self.PlayerHistories, player, newHistory)

			self.DrawingTasks = set(self.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

		end)
	end))

	destructor:Add(self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.Undo:FireAllClients(player)

			local playerHistory = self.PlayerHistories[player]

			if playerHistory:CountPast() < 1 then
				error("Cannot undo, past empty")
			end

			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepBackward()
			assert(drawingTask)

			self.DrawingTasks = set(self.DrawingTasks, drawingTask.Id, nil)
			self.PlayerHistories = set(self.PlayerHistories, player, newHistory)

			DrawingTask.Undo(drawingTask, self)

		end)
	end))

	destructor:Add(self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.Redo:FireAllClients(player)

			local playerHistory = self.PlayerHistories[player]

			if playerHistory:CountFuture() < 1 then
				error("Cannot redo, future empty")
			end

			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepForward()
			assert(drawingTask)

			DrawingTask.Redo(drawingTask, self)

			self.DrawingTasks = set(self.DrawingTasks, drawingTask.Id, drawingTask)
			self.PlayerHistories = set(self.PlayerHistories, player, newHistory)

		end)
	end))

	destructor:Add(RunService.Heartbeat:Connect(function()
		self._jobQueue:RunJobsUntilYield(coroutine.yield)
	end))

	return self

end


return BoardServer