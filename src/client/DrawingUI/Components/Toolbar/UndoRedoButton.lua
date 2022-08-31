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

local UndoRedoButton = Roact.PureComponent:extend("UndoRedoButton")
UndoRedoButton.defaultProps = {
	LayoutOrder = 0
}

function UndoRedoButton:init()
	self:setState({ Hovering = false })
end

function UndoRedoButton:render()
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder
	local onClick = self.props.OnClick
	local clickable = self.props.Clickable
	local icon = self.props.Icon
	local hovering = self.state.Hovering

	local iconButton = e("ImageButton", {
		Image = icon,
		ImageTransparency = clickable and 0 or 0.5,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = (hovering and clickable) and UDim2.fromOffset(40,40) or UDim2.fromOffset(35,35),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Roact.Event.Activated] = clickable and onClick or nil,
		[Roact.Event.MouseEnter] = function()
			self:setState({ Hovering = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ Hovering = false })
		end,

		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.1, 0),
			}),
		}
	})

	return e("Frame", {
		LayoutOrder = layoutOrder,
		Size = size,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,

		[Roact.Children] = {
			iconButton
		}
	})
end

return UndoRedoButton