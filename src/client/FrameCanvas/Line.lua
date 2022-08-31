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

return function(props)
	if props.Mask then
		return nil
	end

	local length = (props.P0 - props.P1).Magnitude
	local rotation = props.P1 == props.P0 and 0 or math.deg(math.atan2((props.P0 - props.P1).Y, (props.P0 - props.P1).X))
	local centre = (props.P0 + props.P1)/2

	return e("Frame", {

		Position = UDim2.fromOffset(centre.X * props.CanvasAbsoluteSize.Y + props.CanvasAbsolutePosition.X, centre.Y * props.CanvasAbsoluteSize.Y + props.CanvasAbsolutePosition.Y + 36),
		Size = UDim2.fromOffset(math.max(1, length * props.CanvasAbsoluteSize.Y), math.max(1, props.Width * props.CanvasAbsoluteSize.Y)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,

		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,

		[Roact.Children] = {
			UICorner = props.Rounded and e("UICorner", {
				CornerRadius = UDim.new(0.5, 0)
			}) or nil
		}
	})
end