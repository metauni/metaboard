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

local StraightLine = {}

function StraightLine.new(taskId: string, color: Color3, thicknessYScale: number)

	return {
		Id = taskId,
		Type = script.Name,
		Line = {
			Type = "Line",
			P0 = nil, -- Not sure if this value has any consequences
			P1 = nil, -- Not sure if this value has any consequences
			Width = thicknessYScale,
			Color = color,
		} :: Figure.Line
	}
end

function StraightLine.Render(drawingTask): Figure.AnyFigure

	return drawingTask.Line
end

function StraightLine.Init(drawingTask, board, canvasPos: Vector2)

	local zIndex = board.NextFigureZIndex

	if drawingTask.Verified then
		board.NextFigureZIndex += 1
	end

	local newLine = merge(drawingTask.Line, {
		
		P0 = canvasPos,
		P1 = canvasPos,
		ZIndex = zIndex,

	})

	return set(drawingTask, "Line", newLine)
end

function StraightLine.Update(drawingTask, board, canvasPos: Vector2)

	local newLine = set(drawingTask.Line, "P1", canvasPos)

	return set(drawingTask, "Line", newLine)
end

function StraightLine.Finish(drawingTask, board)

	if drawingTask.Verified then
		board.EraseGrid:AddLine(drawingTask.Id, drawingTask.Line)
	end

	return drawingTask
end

function StraightLine.Commit(drawingTask, figures)

	return set(figures, drawingTask.Id, drawingTask.Line)
end

function StraightLine.Undo(drawingTask, board)

	if drawingTask.Verified then
		board.EraseGrid:RemoveFigure(drawingTask.Id, drawingTask.Line)
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

		local singletonMaskedFigure = { [drawingTask.Id] = drawingTask.Line }

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