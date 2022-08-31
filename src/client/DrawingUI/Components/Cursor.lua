-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
	local width = props.Width
	local color = props.Color or Color3.new(0,0,0)
	local position = props.Position

	return e("Frame", {
		Size = UDim2.fromOffset(width - 2, width - 2),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = position,
		BackgroundTransparency = 0.8,
		BackgroundColor3 = color,

		[Roact.Children] = {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0.5,0) }),
			UIStroke = e("UIStroke", { Thickness = 1, Color = color })
		}
	})
end
