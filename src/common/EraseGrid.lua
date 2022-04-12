-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)

local EraseGrid = {}
EraseGrid.__index = EraseGrid

function EraseGrid.new()
  return setmetatable({
    DrawingTasks = {}
  }, EraseGrid)
end

return EraseGrid