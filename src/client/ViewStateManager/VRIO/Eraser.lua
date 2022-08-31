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
	newDrawingTask = function(self)
		local taskId = Config.GenerateUUID()

		return Erase.new(taskId, self.EraserSize)
	end,
}