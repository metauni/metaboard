-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local History = require(Common.History)
local DrawingTask = require(Common.DrawingTask)
local EraseGrid = require(Common.EraseGrid)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Dictionary Operations
local set = Dictionary.set

return function(board, destructor)

	destructor:Add(RunService.RenderStepped:Connect(function()
		if board._changedThisFrame then
			board.DataChangedSignal:Fire()
		end

		board._changedThisFrame = false
	end))

	-- Connect remote event callbacks to respond to init/update/finish's of a drawing task.
	-- The callbacks queue the changes to be made in the order they are triggered
	-- The order these remote events are received is the globally agreed order

	destructor:Add(board.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

		board._jobQueue:Enqueue(function(yielder)

			-- Get or create the player history for this player
			local playerHistory = board.PlayerHistories[tostring(player.UserId)] or History.new(Config.History.Capacity)

			local initialisedDrawingTask = DrawingTask.Init(drawingTask, board, canvasPos)
			board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

			local newHistory = playerHistory:Clone()
			newHistory:Push(initialisedDrawingTask)
			board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

			-- Any drawing task which doesn't appear in any player history is a candidate for committing
			local needsCommitDrawingTasks = table.clone(board.DrawingTasks)
			for playerId, pHistory in pairs(board.PlayerHistories) do

				for historyDrawingTask in pHistory:IterPastAndFuture() do

					needsCommitDrawingTasks[historyDrawingTask.Id] = nil

				end
			end

			for taskId, dTask in pairs(needsCommitDrawingTasks) do
				local canCommit

				if dTask.Type == "Erase" then
					-- Every figure being (partially) erased must be gone from DrawingTasks
					canCommit = Dictionary.every(dTask.FigureIdToMask, function(mask, figureId)
						return board.DrawingTasks[figureId] == nil
					end)
				else
					canCommit = true
				end

				if canCommit then
					board.Figures = DrawingTask.Commit(dTask, board.Figures)
					board.DrawingTasks = set(board.DrawingTasks, dTask.Id, nil)
				end

				-- Drawing Tasks not committed now will be committed later when canCommitt == true

			end


			board:DataChanged()
		end)
	end))

	destructor:Add(board.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, canvasPos: Vector2)
		board._jobQueue:Enqueue(function(yielder)

			local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
			assert(drawingTask)

			local updatedDrawingTask = DrawingTask.Update(drawingTask, board, canvasPos)

			local newHistory = board.PlayerHistories[tostring(player.UserId)]:Clone()
			newHistory:SetMostRecent(updatedDrawingTask)

			board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

			board.DrawingTasks = set(board.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

			board:DataChanged()
		end)
	end))

	destructor:Add(board.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player)
		board._jobQueue:Enqueue(function(yielder)
			local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
			assert(drawingTask)

			local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, board), "Finished", true)

			local newHistory = board.PlayerHistories[tostring(player.UserId)]:Clone()
			newHistory:SetMostRecent(finishedDrawingTask)

			board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

			board.DrawingTasks = set(board.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

			board:DataChanged()
		end)
	end))


	destructor:Add(board.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
		board._jobQueue:Enqueue(function(yielder)
			local playerHistory = board.PlayerHistories[tostring(player.UserId)]

			if playerHistory:CountPast() < 1 then
				error("Cannot undo, past empty")
			end

			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepBackward()
			assert(drawingTask)

			board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, nil)
			board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

			DrawingTask.Undo(drawingTask, board)

			board:DataChanged()
		end)
	end))

	destructor:Add(board.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
		board._jobQueue:Enqueue(function(yielder)

			local playerHistory = board.PlayerHistories[tostring(player.UserId)]

			if playerHistory:CountFuture() < 1 then
				error("Cannot redo, future empty")
			end

			local newHistory = playerHistory:Clone()

			local drawingTask = newHistory:StepForward()
			assert(drawingTask)

			board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, drawingTask)
			board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

			DrawingTask.Redo(drawingTask, board)

			board:DataChanged()

		end)
	end))

	destructor:Add(board.Remotes.Clear.OnClientEvent:Connect(function(player: Player)
		board._jobQueue:Enqueue(function(yielder)

			board.PlayerHistories = {}
			board.DrawingTasks = {}
			board.Figures = {}
			board.NextFigureZIndex = 0
			board.EraseGrid = EraseGrid.new(board:SurfaceSize().X / board:SurfaceSize().Y)

			board:DataChanged()

		end)
	end))

	destructor:Add(RunService.RenderStepped:Connect(function()
		board._jobQueue:RunJobsUntilYield(coroutine.yield)
	end))
end