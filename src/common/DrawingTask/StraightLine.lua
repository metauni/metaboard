--!strict

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

local StraightLine = {}

function StraightLine.new(taskId: string, color: Color3, thicknessYScale: number)

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

function StraightLine.Render(drawingTask): Figure.AnyFigure

	return drawingTask.Curve
end

function StraightLine.Init(drawingTask, board, canvasPos: Vector2)

	local zIndex = board.NextFigureZIndex

	if drawingTask.Verified then
		board.NextFigureZIndex += 1
	end

	local newLine = merge(drawingTask.Curve, {

		Points = {canvasPos, canvasPos},
		ZIndex = zIndex,

	})

	return set(drawingTask, "Curve", newLine)
end

function StraightLine.Update(drawingTask, board, canvasPos: Vector2)

	local newPoints = Array.set(drawingTask.Curve.Points, 2, canvasPos)

	local newLine = set(drawingTask.Curve, "Points", newPoints)

	return set(drawingTask, "Curve", newLine)
end

function StraightLine.Finish(drawingTask, board)

	local function lerp(a, b, t)
		if t < 0.5 then
			return a + (b - a) * t
		else
			return b - (b - a) * (1 - t)
		end
	end

	local line = drawingTask.Curve
	local p0, p1 = unpack(line.Points)
	local length = (p0 - p1).Magnitude
	local numSegments = math.ceil(length/Config.Drawing.LineSubdivisionLengthYScale)
	local newPoints = {}

	for i=0, numSegments do
		newPoints[i+1] = lerp(p0, p1, i/numSegments)
	end

	local newCurve = set(drawingTask.Curve, "Points", newPoints)

	if drawingTask.Verified then
		board.EraseGrid:AddCurve(drawingTask.Id, newCurve)
	end

	return set(drawingTask, "Curve", newCurve)
end

function StraightLine.Commit(drawingTask, figures)

	return set(figures, drawingTask.Id, drawingTask.Curve)
end

function StraightLine.Undo(drawingTask, board)

	if drawingTask.Verified then
		board.EraseGrid:RemoveFigure(drawingTask.Id, drawingTask.Curve)
	end

	return drawingTask
end

function StraightLine.Redo(drawingTask, board)

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

		board.EraseGrid:AddLine(drawingTask.Id, singletonMaskedFigure[drawingTask.Id])
	end

	return drawingTask
end


return StraightLine