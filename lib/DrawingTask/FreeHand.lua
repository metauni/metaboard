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
local set = Dictionary.set
local merge = Dictionary.merge

local FreeHand = {}

function FreeHand.new(taskId: string, color: Color3, thicknessYScale: number)

	return {
		Id = taskId,
		Type = script.Name,
		Curve = {
			Type = "Curve",
			Points = nil, -- Not sure if this value has any consequences
			Width = thicknessYScale,
			Color = color,
		} :: Figure.Curve
	}
end

function FreeHand.Render(drawingTask): Figure.AnyFigure

	return drawingTask.Curve
end

function FreeHand.Init(drawingTask, board, canvasPos: Vector2)

	local zIndex = board.NextFigureZIndex

	if drawingTask.Verified then
		board.NextFigureZIndex += 1
	end

	local newCurve = merge(drawingTask.Curve, {
		
		Points = {canvasPos, canvasPos},
		ZIndex = zIndex,

	})

	return set(drawingTask, "Curve", newCurve)
end

function FreeHand.Update(drawingTask, _board, canvasPos: Vector2)

	local newPoints = table.clone(drawingTask.Curve.Points)
	table.insert(newPoints, canvasPos)

	local newCurve = set(drawingTask.Curve, "Points", newPoints)

	return set(drawingTask, "Curve", newCurve)
end

function FreeHand.Finish(drawingTask, board)
	
	if drawingTask.Verified then
		board.EraseGrid:AddCurve(drawingTask.Id, drawingTask.Curve)
	end

	return drawingTask
end

function FreeHand.Commit(drawingTask, figures)

	return set(figures, drawingTask.Id, drawingTask.Curve)
end

function FreeHand.Undo(drawingTask, board)

	if drawingTask.Verified then
		board.EraseGrid:RemoveFigure(drawingTask.Id, drawingTask.Curve)
	end

	return drawingTask
end

function FreeHand.Redo(drawingTask, board)

	local DrawingTask = require(script.Parent)

	if drawingTask.Verified then
		
		--[[
			The figure produced by this drawing task might be partially erased
			by other drawing tasks, so we need to "Commit" them to the figure before
			adding the result back to the erase grid.
			--]]
			
		local singletonMaskedFigure = { [drawingTask.Id] = drawingTask.Curve }

		for _, otherDrawingTask in pairs(board.DrawingTasks) do
			if otherDrawingTask.Type == "Erase" then
				singletonMaskedFigure = DrawingTask.Commit(otherDrawingTask, singletonMaskedFigure)
			end
		end

		board.EraseGrid:AddCurve(drawingTask.Id, singletonMaskedFigure[drawingTask.Id])
	end

	return drawingTask
end

return FreeHand