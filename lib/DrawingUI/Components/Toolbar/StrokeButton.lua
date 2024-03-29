-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement

local StrokeButton = Roact.PureComponent:extend("StrokeButton")

function StrokeButton:init()
	self:setState({ Hovering = false })
end
StrokeButton.defaultProps = {
	Size = UDim2.fromScale(1, 1),
	LayoutOrder = 0,
}

function StrokeButton:render()
	local selected = self.props.Selected
	local onClick = self.props.OnClick
	local color = self.props.Color
	local width = self.props.Width
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder
	local subMenu = self.props.SubMenu

	local hovering = self.state.Hovering

	local icon = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, width),
		ZIndex = 1
	},
		{ uICorner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) })
	})

	local highlight = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = selected and 0.5 or 0.75,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(55, 55),
		ZIndex = 0,
	},
		{ uICorner = e("UICorner", { CornerRadius = UDim.new(0.2, 0) })
	})

	return e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5,0.5),
		LayoutOrder = layoutOrder,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		[Roact.Event.MouseEnter] = function()
			self:setState({ Hovering = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ Hovering = false })
		end,
		[Roact.Event.Activated] = onClick,

		[Roact.Children] = {
			icon = icon,
			highlight = (hovering or selected) and highlight or nil,
			SubMenu = subMenu
		}
	})

end

return StrokeButton