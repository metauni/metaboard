-- Read AbstractDrawingTask for details

local DrawingTaskDictionary = {}

for _, module in ipairs(script:GetChildren()) do
	DrawingTaskDictionary[module.Name] = require(module)
end

return {

	Render = function(drawingTask)
		return DrawingTaskDictionary[drawingTask.Type].Render(drawingTask)
	end,

	Init = function(drawingTask, board, canvasPos: Vector2)
		return DrawingTaskDictionary[drawingTask.Type].Init(drawingTask, board, canvasPos)
	end,

	Update = function(drawingTask, board, canvasPos: Vector2)
		return DrawingTaskDictionary[drawingTask.Type].Update(drawingTask, board, canvasPos)
	end,

	Finish = function(drawingTask, board)
		return DrawingTaskDictionary[drawingTask.Type].Finish(drawingTask, board)
	end,

	Commit = function(drawingTask, figures)
		return DrawingTaskDictionary[drawingTask.Type].Commit(drawingTask, figures)
	end,

	Undo = function(drawingTask, board)
		return DrawingTaskDictionary[drawingTask.Type].Undo(drawingTask, board)
	end,

	Redo = function(drawingTask, board)
		return DrawingTaskDictionary[drawingTask.Type].Redo(drawingTask, board)
	end,

}