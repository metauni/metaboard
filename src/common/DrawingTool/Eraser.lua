-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Erase = require(Common.DrawingTask.Erase)

-- Eraser
local Eraser = setmetatable({IsEraser = true, HasStroke = false}, {})
Eraser.__index = Eraser

local nameToWidth = {
  Small = Config.Drawing.EraserSmallStrokeWidth,
  Medium = Config.Drawing.EraserMediumStrokeWidth,
  Large = Config.Drawing.EraserLargeStrokeWidth,
}

function Eraser.new(sizeName: string)
  local self = setmetatable({}, Eraser)

  self.Width = nameToWidth[sizeName]

  return self
end

function Eraser:NewDrawingTask(board, canvasHeightPixels)
  local taskId = Config.GenerateUUID()
  return Erase.new(board, taskId, true, self.Width / canvasHeightPixels)
end

return Eraser