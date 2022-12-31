-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Config = require(root.Config)
local StraightLine = require(root.DrawingTask.StraightLine)

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