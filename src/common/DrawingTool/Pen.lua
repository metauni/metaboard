-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config =require(Common.Config)
local FreeHand = require(Common.DrawingTask.FreeHand)

-- Pen
local Pen = setmetatable({IsPen = true, HasStroke = true}, {})
Pen.__index = Pen

function Pen.new(stroke)
  local self = setmetatable({}, Pen)

  self.Stroke = stroke

  return self
end

function Pen:NewDrawingTask(board, canvasHeightPixels)
  local taskId = Config.GenerateUUID()
  return FreeHand.new(board, taskId, true, self.Stroke.ShadedColor.Color, self.Stroke.Width / canvasHeightPixels, board:PeekZIndex())
end

function Pen:Clone(newStroke)
  return Pen.new(newStroke)
end

return Pen