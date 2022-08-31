-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

--[[
	Creates the largest box (frame) of a fixed aspect ratio that fits within
	the given props.Position and props.Size.

	Also fires callbacks to record the resulting box absolutePosition and
	absoluteSize whenever it changes (e.g. window resize).
--]]
local ConstrainedBox = Roact.PureComponent:extend("ConstrainedBox")

function ConstrainedBox:render()

	local box = e("Frame", {

		BackgroundTransparency = 1,

		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		Size = UDim2.fromScale(1,1),

		[Roact.Change.AbsoluteSize] = function(rbx)
			self.props.OnAbsoluteSizeUpdate(rbx.AbsoluteSize)
		end,
		[Roact.Change.AbsolutePosition] = function(rbx)
			self.props.OnAbsolutePositionUpdate(rbx.AbsolutePosition)
		end,

		[Roact.Children] = {
			UIAspectRatioConstraint = e("UIAspectRatioConstraint", {
				AspectRatio = self.props.AspectRatio,
			})
		}
	})

	return e("Frame", {

		BackgroundTransparency = 1,

		Position = self.props.Position,
		Size = self.props.Size,

		[Roact.Children] = {
			Box = box
		}

	})
end

return ConstrainedBox