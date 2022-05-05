-- Read AbstractDrawingTask for details

local DrawingTaskDictionary = {}

for _, module in ipairs(script:GetChildren()) do
	DrawingTaskDictionary[module.Name] = require(module)
end

return DrawingTaskDictionary