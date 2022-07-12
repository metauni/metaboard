-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Erase = require(Common.DrawingTask.Erase)

return {
	newDrawingTask = function(self)
		local taskId = Config.GenerateUUID()

		return Erase.new(taskId, self.EraserSize)
	end,
}