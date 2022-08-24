-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local StraightLine = require(Common.DrawingTask.StraightLine)

-- Helper Functions
local deriveStroke = require(script.Parent.deriveStroke)

return {
	newDrawingTask = function(self, state)
		local taskId = Config.GenerateUUID()
		local stroke = deriveStroke(state)
		local thicknessYScale = stroke.Width / self.state.CanvasAbsoluteSize.Y
		local color = stroke.ShadedColor.Color

		return StraightLine.new(taskId, color, thicknessYScale)
	end,
}