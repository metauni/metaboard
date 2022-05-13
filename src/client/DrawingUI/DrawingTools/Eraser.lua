-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Erase = require(Common.DrawingTask.Erase)

return {
	newDrawingTask = function(self)
		local taskId = Config.GenerateUUID()
		local thicknessYScale = Config.Drawing.EraserStrokeWidths[self.state.ToolState.SelectedEraserSizeName] / self.CanvasAbsoluteSizeBinding:getValue().Y

		return Erase.new(taskId, thicknessYScale)
	end,
}