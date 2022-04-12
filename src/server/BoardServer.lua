-- Services
local CollectionService = game:GetService("CollectionService")

-- Import
local RunService = game:GetService("RunService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Canvas = require(Common.Canvas)
local BoardRemotes = require(Common.BoardRemotes)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local JobQueue = require(Common.JobQueue)

-- BoardServer
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part, boardRemotes)
  -- A server board has no canvas, so we pass nil
  local self = setmetatable(Board.new(instance, boardRemotes, nil), BoardServer)

	self._jobQueue = JobQueue.new()

  local destructor = Destructor.new()
  self._destructor = destructor

  -- Respond to each remote event by repeating it to all of the clients, then
  -- performing the described change to the server's copy of the board

	destructor:Add(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, taskType: string, drawingTask, pos)
		
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
					pastDrawingTask:Commit(self, nil)
				end
				playerHistory:Push(drawingTask, pastForgetter)
			end
			
			drawingTask:RenewVerified(self)
			drawingTask:Init(self, pos)
			self.Remotes.InitDrawingTask:FireAllClients(player, taskType, drawingTask, pos)
		end)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
		
		
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.UpdateDrawingTask:FireAllClients(player, pos)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Update(self, pos, nil)
		end)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
		
		
		self._jobQueue:Enqueue(function(yielder)
			self.Remotes.FinishDrawingTask:FireAllClients(player, pos)
			local drawingTask = self.PlayerHistory[player]:MostRecent()
			assert(drawingTask)
			drawingTask:Finish(self, nil)
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
		self._jobQueue:RunJobsUntilYield()
	end))
end

function BoardServer.InstanceBinder(instance)
	local boardRemotes = BoardRemotes.new(instance)
	local board = BoardServer.new(instance, boardRemotes)

end


return BoardServer