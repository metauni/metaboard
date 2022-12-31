-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent
local Figure = require(root.Figure)
local Sift = require(root.Parent.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge
local set = Dictionary.set

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

	local DrawingTask = require(script.Parent)

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

		local DrawingTask = require(script.Parent)

		local affectedFigures = {}

		-- Gather figures which were affected by this erase

		for figureId, figure in pairs(board.Figures) do
			if drawingTask.FigureIdToMask[figureId] then
				affectedFigures[figureId] = figure
			end
		end

		-- Gather figures from drawing tasks which were affected by this erase
		
		for taskId, otherDrawingTask in pairs(board.DrawingTasks) do

			if otherDrawingTask == drawingTask then
				continue
			end

			if drawingTask.FigureIdToMask[otherDrawingTask.Id] and otherDrawingTask.Type ~= "Erase" then
				affectedFigures[taskId] = DrawingTask.Render(otherDrawingTask)
			end
		end
		
		-- Reapply remaining erase drawing task masks to all affected figures 

		local remaskedFigures = affectedFigures
		for taskId, otherDrawingTask in pairs(board.DrawingTasks) do

			if otherDrawingTask == drawingTask then
				continue
			end

			if otherDrawingTask.Type == "Erase" then
				remaskedFigures = DrawingTask.Commit(otherDrawingTask, remaskedFigures)
			end
		end

		-- Update figures in Erase Grid

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
