-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local FreeHand = require(Common.DrawingTask.FreeHand)

-- Helper Functions
local deriveStroke = require(script.Parent.deriveStroke)

return {
	newDrawingTask = function(self, state)
		local taskId = Config.GenerateUUID()
		local stroke = deriveStroke(state)
		local thicknessYScale = stroke.Width / self.state.CanvasAbsoluteSize.Y
		local color = stroke.ShadedColor.Color

		return FreeHand.new(taskId, color, thicknessYScale)
	end,
}