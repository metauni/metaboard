-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Import
local Config = require(Common.Config)
local Board = require(Common.Board)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local EraseGrid = require(Common.EraseGrid)
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

function BoardServer.new(instance: Model | Part, boardRemotes, persistId: string?, status: string)
	-- A server board has no canvas, so we pass nil
	local self = setmetatable(Board.new(instance, boardRemotes, persistId, status), BoardServer)


	self._jobQueue = JobQueue.new()

	-- Respond to each remote event by repeating it to all of the clients, then
	-- performing the described change to the server's copy of the board

	self._destructor:Add(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			local verifiedDrawingTask = merge(drawingTask, { Verified = true })
			self.Remotes.InitDrawingTask:FireAllClients(player, verifiedDrawingTask, canvasPos)

			-- Get or create the player history for this player
			local playerHistory = self.PlayerHistories[tostring(player.UserId)] or History.new(Config.History.Capacity)

			local initialisedDrawingTask = DrawingTask.Init(verifiedDrawingTask, self, canvasPos)
			self.DrawingTasks = set(self.DrawingTasks, initialisedDrawingTask.Id, initialisedDrawingTask)

			local pastForgetter = function(pastDrawingTask)
				self.Figures = DrawingTask.Commit(pastDrawingTask, self.Figures)
				self.DrawingTasks = set(self.DrawingTasks, initialisedDrawingTask.Id, nil)
			end

			local newHistory = playerHistory:Clone()
			newHistory:Push(initialisedDrawingTask, pastForgetter)

			self.PlayerHistories = set(self.PlayerHistories, tostring(player.UserId), newHistory)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.UpdateDrawingTask:FireAllClients(player, canvasPos)

			local drawingTask = self.PlayerHistories[tostring(player.UserId)]:MostRecent()
			assert(drawingTask)

			local updatedDrawingTask = DrawingTask.Update(drawingTask, self, canvasPos)

			local newHistory = self.PlayerHistories[tostring(player.UserId)]:Clone()
			newHistory:SetMostRecent(updatedDrawingTask)

			self.PlayerHistories = set(self.PlayerHistories, tostring(player.UserId), newHistory)

			self.DrawingTasks = set(self.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.FinishDrawingTask:FireAllClients(player, canvasPos)

			local drawingTask = self.PlayerHistories[tostring(player.UserId)]:MostRecent()
			assert(drawingTask)

			local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, self), "Finished", true)

			local newHistory = self.PlayerHistories[tostring(player.UserId)]:Clone()
			newHistory:SetMostRecent(finishedDrawingTask)

			self.PlayerHistories = set(self.PlayerHistories, tostring(player.UserId), newHistory)

			self.DrawingTasks = set(self.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)

			local playerHistory = self.PlayerHistories[tostring(player.UserId)]
			
			if playerHistory == nil or playerHistory:CountPast() < 1 then
				-- error("Cannot undo, past empty")
				-- No error so clients can just attempt undo
				return
			end

			self.Remotes.Undo:FireAllClients(player)

			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepBackward()
			assert(drawingTask)

			self.DrawingTasks = set(self.DrawingTasks, drawingTask.Id, nil)
			self.PlayerHistories = set(self.PlayerHistories, tostring(player.UserId), newHistory)

			DrawingTask.Undo(drawingTask, self)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)

			local playerHistory = self.PlayerHistories[tostring(player.UserId)]
			
			if playerHistory == nil or playerHistory:CountFuture() < 1 then
				-- error("Cannot redo, future empty")
				-- No error so clients can just attempt redo
				return
			end

			self.Remotes.Redo:FireAllClients(player)
			
			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepForward()
			assert(drawingTask)

			DrawingTask.Redo(drawingTask, self)

			self.DrawingTasks = set(self.DrawingTasks, drawingTask.Id, drawingTask)
			self.PlayerHistories = set(self.PlayerHistories, tostring(player.UserId), newHistory)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(self.Remotes.Clear.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)

			self.Remotes.Clear:FireAllClients(player)

			self.PlayerHistories = {}
			self.DrawingTasks = {}
			self.Figures = {}
			self.EraseGrid = EraseGrid.new(self:SurfaceSize().X / self:SurfaceSize().Y)

			self.DataChangedSignal:Fire()

		end)
	end))

	self._destructor:Add(RunService.Heartbeat:Connect(function()
		self._jobQueue:RunJobsUntilYield(coroutine.yield)
	end))

	return self

end


return BoardServer