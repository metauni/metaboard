-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Assets = require(Common.Assets)

local PenButton = Roact.PureComponent:extend("PenButton")
PenButton.defaultProps = {
	LayoutOrder = 0
}

function PenButton:init()
	self:setState({ Hovering = false })
end

function PenButton:render()
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder
	local onClick = self.props.OnClick
	local selected = self.props.Selected
	local hovering = self.state.Hovering

	local icon = e("ImageLabel", {
		Image = selected and Assets["pen-selected"] or Assets["pen-deselected"],
		ImageTransparency = 0,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = hovering and UDim2.fromOffset(60,60) or UDim2.fromOffset(55,55),
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

return PenButton