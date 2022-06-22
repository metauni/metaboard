-- Services
local Common = script.Parent.Parent

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local set = Dictionary.set
local merge = Dictionary.merge

-- Array Operations
local Array = Sift.Array
local push = Array.push

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

function FreeHand.Update(drawingTask, board, canvasPos: Vector2)

	-- This means that the points array cannot be treated as immutable
	-- We still return a new drawingTask with a new curve in it.
	local newPoints = drawingTask.Curve.Points
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

		for taskId, otherDrawingTask in pairs(board.DrawingTasks) do
			if otherDrawingTask.Type == "Erase" then
				singletonMaskedFigure = DrawingTask.Commit(otherDrawingTask, singletonMaskedFigure)
			end
		end

		board.EraseGrid:AddCurve(drawingTask.Id, singletonMaskedFigure[drawingTask.Id])
	end

	return drawingTask
end

return FreeHand