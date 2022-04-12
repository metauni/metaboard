-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config =require(Common.Config)
local StraightLine = require(Common.DrawingTask.StraightLine)

-- StraightEdge
local StraightEdge = setmetatable({IsStraightEdge = true, HasStroke = true}, {})
StraightEdge.__index = StraightEdge

function StraightEdge.new(stroke)
  local self = setmetatable({}, StraightEdge)

  self.Stroke = stroke

  return self
end

function StraightEdge:NewDrawingTask(board, canvasHeightPixels)
  local taskId = Config.GenerateUUID()
  return StraightLine.new(board, taskId, true, self.Stroke.ShadedColor.Color, self.Stroke.Width / canvasHeightPixels, board:PeekZIndex())
end

function StraightEdge:Clone(newStroke)
  return StraightEdge.new(newStroke)
end

return StraightEdge