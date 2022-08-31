-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Erase = require(Common.DrawingTask.Erase)

return {
	newDrawingTask = function(self, state)
		local taskId = Config.GenerateUUID()
		local thicknessYScale = Config.DrawingTools.EraserStrokeWidths[state.ToolState.SelectedEraserSizeName] / self.state.CanvasAbsoluteSize.Y

		return Erase.new(taskId, thicknessYScale)
	end,
}