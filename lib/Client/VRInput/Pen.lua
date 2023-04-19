-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Config = require(root.Config)
local FreeHand = require(root.DrawingTask.FreeHand)

return {
	-- selene: allow(unused_variable)
	newDrawingTask = function(self)
		local taskId = Config.GenerateUUID()
		local stroke = {
			Width = 0.001,
			ShadedColor = {
				Color = Color3.new(1,1,1),
				BaseName = "White",
			}
		}
		local color = stroke.ShadedColor.Color

		return FreeHand.new(taskId, color, stroke.Width)
	end,
}