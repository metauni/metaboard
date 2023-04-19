-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement

local Assets = require(root.Assets)

local ClearButton = Roact.PureComponent:extend("ClearButton")
ClearButton.defaultProps = {
	LayoutOrder = 0
}

function ClearButton:init()
	self:setState({ Hovering = false })
end

function ClearButton:render()
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder
	local onClick = self.props.OnClick
	local clickable = self.props.Clickable
	local hovering = self.state.Hovering

	local icon = e("ImageLabel", {
		Image = clickable and Assets["trash-clickable"] or Assets["trash-unclickable"],
		ImageTransparency = 0,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = hovering and UDim2.fromOffset(45,45) or UDim2.fromOffset(40,40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})


	return e("TextButton", {
		LayoutOrder = layoutOrder,
		Size = size,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Text = "",
		[Roact.Event.Activated] = onClick or nil,
		[Roact.Event.MouseEnter] = function()
			self:setState({ Hovering = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ Hovering = false })
		end,

		[Roact.Children] = {
			Icon = icon
		}
	})
end

return ClearButton