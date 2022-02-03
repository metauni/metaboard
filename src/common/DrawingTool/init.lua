local DataStoreService = game:GetService("DataStoreService")
-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Signal = require(Common.Signal)

-- Drawing Tool
local DrawingTool = {}
DrawingTool.__index = DrawingTool

-- A Drawing Tool is a Drawing Task spawner
-- Calling the :CreateDrawingTask method will return a Drawing Task
-- which corresponds to the internal state of the Drawing Tool
-- (e.g. thickness, color for a Pen)

-- Additionally Drawing Tools come with Signals for equipping, unequipping and
-- updating the properties of the Drawing Tool. These should be connected
-- to the Gui to show the state and equipped-status of a Drawing Tool.
function DrawingTool.new()
  return setmetatable({
    UpdateSignal = Signal.new(),
  }, DrawingTool)
end

function DrawingTool:CreateDrawingTask(board)
  error("No Drawing Task spawner method implemented for subclass of Drawing Tool")
end

-- This should be overloaded by the subclass
function DrawingTool:Update(...)
  self.UpdateSignal:Fire()
end