-- Services
local Common = script.Parent.Parent

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge
local set = Dictionary.set

-- Erase Module
local Erase = {}

function Erase.new(taskId: string, thicknessYScale: number)

	return {
		Id = taskId,
		Type = script.Name,
		ThicknessYScale = thicknessYScale,
		FigureIdToMask = {},
	}
end

function Erase.Render(drawingTask)
	return drawingTask.FigureIdToMask
end

function Erase.EraseTouched(drawingTask, board, canvasPos: Vector2)

	local DrawingTask = require(Common.DrawingTask)

	local changedMasks = {}

	board.EraseGrid:QueryCircle(canvasPos, drawingTask.ThicknessYScale/2, function(figureId: string, figureType: string, maybeTouchedMask: Figure.AnyMask)

		local figure = board.DrawingTasks[figureId] and DrawingTask.Render(board.DrawingTasks[figureId]) or board.Figures[figureId]

		local doesActuallyIntersect = Figure.IntersectsCircle(canvasPos, drawingTask.ThicknessYScale/2, figureType, figure, maybeTouchedMask)

		if not doesActuallyIntersect then
			return false
		end

		local oldMask = changedMasks[figureId] or drawingTask.FigureIdToMask[figureId]
		if oldMask == nil then
			changedMasks[figureId] = maybeTouchedMask
		else
			changedMasks[figureId] = Figure.MergeMask(figureType, oldMask, maybeTouchedMask)
		end

		-- The return value of this function decides whether the touched part of this figure should be removed from the erase grid.
		-- We only want t8o remove it if this is a verified drawing task.
		return drawingTask.Verified

	end)

	if next(changedMasks) then

		return set(drawingTask, "FigureIdToMask", merge(drawingTask.FigureIdToMask, changedMasks))

	else

		return drawingTask

	end
end

function Erase.Init(drawingTask, board, canvasPos: Vector2)
	return Erase.EraseTouched(drawingTask, board, canvasPos)
end

function Erase.Update(drawingTask, board, canvasPos: Vector2)
	return Erase.EraseTouched(drawingTask, board, canvasPos)
end

function Erase.Finish(drawingTask, board)
	return drawingTask
end

function Erase.Commit(drawingTask, figures)
	local updatedFigures = {}
	local removals = {}

	for figureId, figure in pairs(figures) do
		local mask = drawingTask.FigureIdToMask[figureId]
		local mergedMask = Figure.MergeMask(figure.Type, figure.Mask, mask)
		local newFigure = set(figure, "Mask", mergedMask)

		if Figure.FullyMasked(newFigure) then
			removals[figureId] = Sift.None
		else
			updatedFigures[figureId] = newFigure
		end

	end

	return merge(figures, updatedFigures, removals)
end

function Erase.Undo(drawingTask, board)
	
	if drawingTask.Verified then

		local DrawingTask = require(Common.DrawingTask)

		local affectedFigures = {}

		for figureId, figure in pairs(board.Figures) do
			if drawingTask.FigureIdToMask[figureId] then
				affectedFigures[figureId] = figure
			end
		end
		
		for taskId, otherDrawingTask in pairs(board.DrawingTasks) do
			if drawingTask.FigureIdToMask[otherDrawingTask.Id] and otherDrawingTask.Type ~= "Erase" then
				affectedFigures[taskId] = DrawingTask.Render(otherDrawingTask)
			end
		end

		local remaskedFigures = affectedFigures
		for taskId, otherDrawingTask in pairs(board.DrawingTasks) do
			if otherDrawingTask.Type == "Erase" then
				remaskedFigures = DrawingTask.Commit(otherDrawingTask, remaskedFigures)
			end
		end

		for figureId, figure in pairs(remaskedFigures) do
			board.EraseGrid:RemoveFigure(figureId, figure)
			board.EraseGrid:AddFigure(figureId, figure)
		end

	end
end

function Erase.Redo(drawingTask, board)
	for figureId, mask in pairs(drawingTask.FigureIdToMask) do
		board.EraseGrid:SubtractMask(figureId, mask)
	end
end

return Erase
