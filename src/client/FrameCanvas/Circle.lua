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

	return e("Frame", {
		Size = UDim2.fromOffset(math.max(1, props.Width * props.CanvasAbsoluteSize.Y), math.max(1, props.Width * props.CanvasAbsoluteSize.Y)),
		Position = UDim2.fromOffset(props.Position.X  * props.CanvasAbsoluteSize.Y + props.CanvasAbsolutePosition.X, props.Position.Y  * props.CanvasAbsoluteSize.Y + props.CanvasAbsolutePosition.Y + 36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,

		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.5, 0)
			})
		}
	})
end