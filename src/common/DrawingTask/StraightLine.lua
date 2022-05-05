--!strict

-- Services
local Common = script.Parent.Parent

-- Imports
local Config = require(Common.Config)
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Collision = require(Common.Collision)
local Figure = require(Common.Figure)

local StraightLine = setmetatable({}, AbstractDrawingTask)
StraightLine.__index = StraightLine

function StraightLine.newUnverified(taskId: string, color: Color3, thicknessYScale: number)
	local self = setmetatable(AbstractDrawingTask.new(script.Name, taskId, false), StraightLine)

	self.Color = color
	self.ThicknessYScale = thicknessYScale

	return self
end

function StraightLine:Render(): Figure.AnyFigure

	local line: Figure.Line = {
		Type = "Line",
		P0 = self.PointA,
		P1 = self.PointB,
		Width = self.ThicknessYScale,
		Color = self.Color,
		ZIndex = self.ZIndex,
	}

	return line
end

function StraightLine:RenderFigureMask(figureIds)
	return figureIds["Line"]
end

function StraightLine:Init(board, canvasPos)
	self.PointA = canvasPos
	self.PointB = canvasPos
	self.ZIndex = board.NextFigureZIndex

	if self.Verified then
		board.NextFigureZIndex += 1
	end
end

function StraightLine:Update(board, canvasPos)
	self.PointB = canvasPos
end

function StraightLine:Finish(board)
	if self.Verified then
		board.EraseGrid:AddLine(self.TaskId, "Line", self.PointA, self.PointB, self.ThicknessYScale)
	end
end

function StraightLine:CheckCollision(eraserCentre: Vector2, eraserThicknessYScale: number, figureId: string)
	assert(figureId == "Line")
	return Collision.CircleLine(eraserCentre, eraserThicknessYScale/2, self.PointA, self.PointB, self.ThicknessYScale)
end

return StraightLine