-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local DrawingTool = require(script.Parent)
local FreeHand = require(Common.DrawingTask.FreeHand)
local StraightLine = require(Common.DrawingTask.StraightLine)

-- Drawing Tool
local Pen = setmetatable({IsPen = true}, DrawingTool)
Pen.__index = Pen

function Pen.new(thicknessYScale: number, color: Color3, mode: string)
  local self = setmetatable(DrawingTool.new(), Pen)

  self.ThicknessYScale = thicknessYScale
  self.Color = color
  self.Mode = mode

  return self
end

function Pen:CreateDrawingTask(board, taskId)
  if self.Mode == "FreeHand" then
    FreeHand.new(taskId, self.Color, self.ThicknessYScale, board:NextZIndex())
  elseif self.Mode == "StraightLine" then
    StraightLine.new(taskId, self.Color, self.ThicknessYScale, board:NextZIndex())
  else
    error("Unknown Pen.Mode: '"..self.Mode.."'")
  end
end

function Pen:Update(thicknessYScale, color, mode)
  self.ThicknessYScale = thicknessYScale or self.ThicknessYScale
  self.Color = color or self.Color
  self.Mode = mode or self.Mode
  DrawingTool.Update(self)
end

function Pen:ToggleMode()
  if self.Mode == "FreeHand" then
    self.Mode = "StraightLine"
  else
    self.Mode = "FreeHand"
  end
end

return Pen