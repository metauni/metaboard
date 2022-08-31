-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local merge = Dictionary.merge

return function (self)
	local toolQueue = {}

	local connection = RunService.RenderStepped:Connect(function()
		if #toolQueue > 0 then
			self:setState(function(state)
				local stateUpdate = {}
				for i, action in ipairs(toolQueue) do
					stateUpdate = merge(stateUpdate, action(merge(state, stateUpdate)))
				end

				return stateUpdate
			end)
			toolQueue = {}
		end
	end)

	return {

		Enqueue = function(toolAction)
			table.insert(toolQueue, toolAction)
		end,

		Destroy = function ()
			connection:Disconnect()
		end

	}
end