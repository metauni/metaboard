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

		destructor:Add(board.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, drawingTask, pos: Vector2)
			DrawingTask[drawingTask.TaskType].AssignMetatables(drawingTask)

			board._jobQueue:Enqueue(function(yielder)
				local playerHistory = board.PlayerHistory[player]
				if playerHistory == nil then
					playerHistory = History.new(Config.History.Capacity, function(dTask)
						return dTask.TaskId
					end)
					board.PlayerHistory[player] = playerHistory
				end

				board.DrawingTasks[drawingTask.TaskId] = drawingTask
				drawingTask:Init(board, pos, board.Canvas)

				do
					local pastForgetter = function(pastDrawingTask)
						pastDrawingTask:Commit(board, board.Canvas)
					end
					playerHistory:Push(drawingTask, pastForgetter)
				end


				if player == Players.LocalPlayer then
					board.LocalHistoryChangedSignal:Fire(playerHistory:CountPast() > 0, playerHistory:CountFuture() > 0)
				end
			end)
		end))

		destructor:Add(board.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, pos: Vector2)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistory[player]:MostRecent()
				assert(drawingTask)
				drawingTask:Update(board, pos, board.Canvas)
			end)
		end))

		destructor:Add(board.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistory[player]:MostRecent()
				assert(drawingTask)
				drawingTask:Finish(board, board.Canvas)

				if player == Players.LocalPlayer then
					local provisionalDrawingTask = board._provisionalDrawingTasks[drawingTask.TaskId]
					provisionalDrawingTask:Hide(board, board._provisionalCanvas)
					board._provisionalDrawingTasks[drawingTask.TaskId] = nil
				end
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
			board._jobQueue:RunJobsUntilYield()
		end))
end