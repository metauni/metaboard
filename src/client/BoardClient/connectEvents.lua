-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local History = require(Common.History)
local DrawingTask = require(Common.DrawingTask)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local set = Sift.Dictionary.set

return function(board, destructor)

		-- Connect remote event callbacks to respond to init/update/finish's of a drawing task.
		-- The callbacks queue the changes to be made in the order they are triggered
		-- The order these remote events are received is the globally agreed order

		destructor:Add(board.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

			board._jobQueue:Enqueue(function(yielder)

				-- Get or create the player history for this player
				local playerHistory = board.PlayerHistories[player] or History.new(Config.History.Capacity)

				local initialisedDrawingTask = DrawingTask.Init(drawingTask, board, canvasPos)
				board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

				local pastForgetter = function(pastDrawingTask)
					board.Figures = DrawingTask.Commit(pastDrawingTask, board.Figures)
					board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, nil)
				end

				local newHistory = playerHistory:Clone()
				newHistory:Push(initialisedDrawingTask, pastForgetter)

				board.PlayerHistories = set(board.PlayerHistories, player, newHistory)

				board.BoardDataChangedSignal:Fire()
			end)
		end))

		destructor:Add(board.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, canvasPos: Vector2)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistories[player]:MostRecent()
				assert(drawingTask)

				local updatedDrawingTask = DrawingTask.Update(drawingTask, board, canvasPos)

				local newHistory = board.PlayerHistories[player]:Clone()
				newHistory:SetMostRecent(updatedDrawingTask)

				board.PlayerHistories = set(board.PlayerHistories, player, newHistory)

				board.DrawingTasks = set(board.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

				board.BoardDataChangedSignal:Fire()
			end)
		end))

		destructor:Add(board.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local drawingTask = board.PlayerHistories[player]:MostRecent()
				assert(drawingTask)

				local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, board), "Finished", true)

				local newHistory = board.PlayerHistories[player]:Clone()
				newHistory:SetMostRecent(finishedDrawingTask)

				board.DrawingTasks = set(board.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

				board.BoardDataChangedSignal:Fire()
			end)
		end))


		destructor:Add(board.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)
				local playerHistory = board.PlayerHistories[player]

				if playerHistory:CountPast() < 1 then
					error("Cannot undo, past empty")
				end

				local newHistory = playerHistory:Clone()

				local drawingTask = newHistory:StepBackward()
				assert(drawingTask)

				board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, nil)
				board.PlayerHistories = set(board.PlayerHistories, player, newHistory)

				DrawingTask.Undo(drawingTask, board)

				board.BoardDataChangedSignal:Fire()
			end)
		end))

		destructor:Add(board.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
			board._jobQueue:Enqueue(function(yielder)

				local playerHistory = board.PlayerHistories[player]

				if playerHistory:CountFuture() < 1 then
					error("Cannot redo, future empty")
				end

				local newHistory = playerHistory:Clone()

				local drawingTask = newHistory:StepForward()
				assert(drawingTask)

				board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, drawingTask)
				board.PlayerHistories = set(board.PlayerHistories, player, newHistory)

				DrawingTask.Redo(drawingTask, board)

				board.BoardDataChangedSignal:Fire()

			end)
		end))

		destructor:Add(RunService.RenderStepped:Connect(function()
			board._jobQueue:RunJobsUntilYield(coroutine.yield)
		end))
end