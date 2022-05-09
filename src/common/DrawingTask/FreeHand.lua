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
		board.EraseGrid:AddCurve(self.TaskId, {
			Type = "Curve",
			Points = self.Points,
			Width = self.ThicknessYScale,
			Color = self.Color,
			ZIndex = self.ZIndex,
		})
	end
end

return FreeHand