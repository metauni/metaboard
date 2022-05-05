-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local History = require(Common.History)
local DrawingTask = require(Common.DrawingTask)

return function(board, destructor)

		-- Connect remote event callbacks to respond to init/update/finish's of a drawing task.
		-- The callbacks queue the changes to be made in the order they are triggered
		-- The order these remote events are received is the globally agreed order

		destructor:Add(board.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)
			setmetatable(drawingTask, DrawingTask[drawingTask.TaskType])

			board._jobQueue:Enqueue(function(yielder)
				local playerHistory = board.PlayerHistory[player]
				if playerHistory == nil then
					playerHistory = History.new(Config.History.Capacity, function(dTask)
						return dTask.TaskId
					end)
					board.PlayerHistory[player] = playerHistory
				end

				board.DrawingTasks[drawingTask.TaskId] = drawingTask
				drawingTask:Init(board, canvasPos)
				board.DrawingTaskChangedSignal:Fire(drawingTask, player, "Init")

				do
					local pastForgetter = function(pastDrawingTask)
						-- TODO
					end
					playerHistory:Push(drawingTask, pastForgetter)
				end

				if player == Players.LocalPlayer then
					board.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
				end

			end)
		end))

		destructor:Add(board.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, canvsPos: Vector2)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistory[player]:MostRecent()
				assert(drawingTask)
				drawingTask:Update(board, canvsPos)
				board.DrawingTaskChangedSignal:Fire(drawingTask, player, "Update")
			end)
		end))

		destructor:Add(board.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistory[player]:MostRecent()
				assert(drawingTask)
				drawingTask:Finish(board)
				board.DrawingTaskChangedSignal:Fire(drawingTask, player, "Finish")
			end)
		end))


		destructor:Add(board.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local playerHistory = board.PlayerHistory[player]
				local drawingTask = playerHistory:StepBackward()
				assert(drawingTask)
				drawingTask:Undo(board, board.Canvas)

				if player == Players.LocalPlayer then
					board.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
				end
			end)
		end))

		destructor:Add(board.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local playerHistory = board.PlayerHistory[player]
				local drawingTask = board.PlayerHistory[player]:StepForward()
				assert(drawingTask)
				drawingTask:Redo(board, board.Canvas)

				if player == Players.LocalPlayer then
					board.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
				end
			end)
		end))

		destructor:Add(RunService.RenderStepped:Connect(function()
			board._jobQueue:RunJobsUntilYield(coroutine.yield)
		end))
end