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