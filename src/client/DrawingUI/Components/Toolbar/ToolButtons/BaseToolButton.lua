-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Assets = require(Common.Assets)

local BaseToolButton = Roact.PureComponent:extend("BaseToolButton")
BaseToolButton.defaultProps = {
	LayoutOrder = 0
}

function BaseToolButton:init()
	self:setState({ Hovering = false })
end

function BaseToolButton:render()
	local size = self.props.Size
	local layoutOrder = self.props.LayoutOrder
	local onClick = self.props.OnClick
	local selectedIcon = self.props.SelectedIcon
	local deselectedIcon = self.props.DeselectedIcon
	local selected = self.props.Selected
	local hovering = self.state.Hovering

	-- local iconButton = e("ImageButton", {
	-- 	Image = selected and selectedIcon or deselectedIcon,
	-- 	ImageTransparency = 0,
	-- 	AutoButtonColor = false,
	-- 	AnchorPoint = Vector2.new(0.5,0.5),
	-- 	Position = UDim2.fromScale(0.5, 0.5),
	-- 	Size = hovering and UDim2.fromOffset(37,37) or UDim2.fromOffset(35,35),
	-- 	BackgroundTransparency = 1,
	-- 	BorderSizePixel = 0,

	-- 	[Roact.Children] = {
	-- 		UICorner = e("UICorner", {
	-- 			CornerRadius = UDim.new(0.1, 0),
	-- 		}),
	-- 	}
	-- })

	return e("Frame", {
		LayoutOrder = layoutOrder,
		Size = size,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		[Roact.Event.Activated] = onClick or nil,
		[Roact.Event.MouseEnter] = function()
			self:setState({ Hovering = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ Hovering = false })
		end,

		[Roact.Children] = {
			Icon = e(selected and selectedIcon or deselectedIcon, {
				Hovering = hovering,
			})
		}
	})
end

return BaseToolButton