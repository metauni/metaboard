--!strict

-- Services
local Common = script.Parent.Parent

-- Imports
local Config = require(Common.Config)
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Collision = require(Common.Collision)
local Figure = require(Common.Figure)

local FreeHand = setmetatable({}, AbstractDrawingTask)
FreeHand.__index = FreeHand

function FreeHand.newUnverified(taskId: string, color: Color3, thicknessYScale: number)
	local self = setmetatable(AbstractDrawingTask.new(script.Name, taskId, false), FreeHand)

	self.Color = color
	self.ThicknessYScale = thicknessYScale

	return self
end

function FreeHand:Render(): Figure.AnyFigure

	local curve: Figure.Curve = {
		Type = "Curve",
		Points = table.clone(self.Points),
		Width = self.ThicknessYScale,
		Color = self.Color,
		ZIndex = self.ZIndex,
	}

	return curve
end

function FreeHand:RenderFigureMask(figureIds)
	local mask = table.create(#self.Points, false)
	for figureId in pairs(figureIds) do
		mask[tonumber(figureId)] = true
	end

	return mask
end

function FreeHand:Init(board, canvasPos)
	self.Points = {canvasPos, canvasPos}
	self.ZIndex = board.NextFigureZIndex

	if self.Verified then
		board.NextFigureZIndex += 1
	end
end

function FreeHand:Update(board, canvasPos)
	table.insert(self.Points, canvasPos)
end

function FreeHand:Finish(board)
	if self.Verified then
		for i=1, #self.Points-1 do
			board.EraseGrid:AddLine(self.TaskId, tostring(i), self.Points[i], self.Points[i+1], self.ThicknessYScale)
		end
	end
end

function FreeHand:CheckCollision(eraserCentre: Vector2, eraserDiameterYScale: number, figureId: string)
	local index = tonumber(figureId)
	local p0, p1 = self.Points[index], self.Points[index + 1]

	return Collision.CircleLine(eraserCentre, eraserDiameterYScale/2, p0, p1, self.ThicknessYScale)
end

return FreeHand