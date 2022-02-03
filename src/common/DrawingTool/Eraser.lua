-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local DrawingTool = require(script.Parent)
local Erase = require(Common.DrawingTask.Erase)

-- Eraser
local Eraser = setmetatable({IsEraser = true}, DrawingTool)
Eraser.__index = Eraser

function Eraser.new(thicknessYScale: number)
  local self = setmetatable(DrawingTool.new(), Eraser)

  self.ThicknessYScale = thicknessYScale

  return self
end

function Eraser:CreateDrawingTask(board, taskId)
  return Erase.new(taskId)
end

function Eraser:Update(thicknessYScale)
  self.ThicknessYScale = thicknessYScale or self.ThicknessYScale
  DrawingTool.Update(self)
end

return Eraser