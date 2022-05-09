-- Services
local CollectionService = game:GetService("CollectionService")

-- Import
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local JobQueue = require(Config.Debug and Common.InstantJobQueue or Common.JobQueue)
local DelayedJobQueue = require(Common.DelayedJobQueue)
local Signal = require(Common.Packages.GoodSignal)

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

	destructor:Add(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, drawingTask, pos)
		
		setmetatable(drawingTask, DrawingTask[drawingTask.TaskType])
		
		self._jobQueue:Enqueue(function(yielder)
			local playerHistory = self.PlayerHistory[player]
			if playerHistory == nil then
				playerHistory = History.new(Config.History.Capacity, function(dTask)
					return dTask.TaskId
				end)
				self.PlayerHistory[player] = playerHistory
			end
			
			drawingTask:Verify()
			self.Remotes.InitDrawingTask:FireAllClients(player, drawingTask, pos)
			
			drawingTask:Init(self, pos)
			self.DrawingTasks[drawingTask.TaskId] = drawingTask

			do
				local pastForgetter = function(pastDrawingTask)
					-- TODO
				end
				playerHistory:Push(drawingTask, pastForgetter)
			end
			
		end)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
		
		
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.UpdateDrawingTask:FireAllClients(player, pos)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Update(self, pos)
		end)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
		
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.FinishDrawingTask:FireAllClients(player, pos)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Finish(self)
		end)
	end))

	destructor:Add(self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.Undo:FireAllClients(player)
			local drawingTask = self.PlayerHistory[player]:StepBackward()
			assert(drawingTask)
			drawingTask:Undo(self, nil)
		end)
	end))
	
	destructor:Add(self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.Redo:FireAllClients(player)
			local drawingTask = self.PlayerHistory[player]:StepForward()
			assert(drawingTask)
			drawingTask:Redo(self, nil)
		end)
	end))
	
	destructor:Add(RunService.Heartbeat:Connect(function()
		self._jobQueue:RunJobsUntilYield(coroutine.yield)
	end))

	destructor:Add(self.Remotes.RequestBoardData.OnServerEvent:Connect(function(player)
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.RequestBoardData:FireClient(player, self.Figures, self.DrawingTasks, self.PlayerHistory)
		end)
	end))

	return self

end


return BoardServer