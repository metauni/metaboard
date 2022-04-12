-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local CloseButton = Roact.PureComponent:extend("CloseButton")

CloseButton.defaultProps = {
  Size = UDim2.fromScale(1, 1),
  Position = UDim2.fromScale(0.5, 0.5),
  LayoutOrder = 0
}

function CloseButton:init()
  self:setState({ Hovering = false })
end

function CloseButton:render()
  local layoutOrder = self.props.LayoutOrder
  local onClick = self.props.OnClick
  local size = self.props.Size
  local position = self.props.Position
  local anchorPoint = self.props.AnchorPoint
  local hovering = self.state.Hovering

  local iconButton = e("ImageButton", {
    Image = "rbxassetid://5198838744",
    AutoButtonColor = true,
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    Size = hovering and (UDim2.fromScale(1,1) + UDim2.fromOffset(2,2)) or UDim2.fromScale(1,1),
    BackgroundTransparency = 1,
    [Roact.Event.Activated] = onClick,
    [Roact.Event.MouseEnter] = function()
      self:setState({ Hovering = true })
    end,
    [Roact.Event.MouseLeave] = function()
      self:setState({ Hovering = false })
    end,
  })

  return e("Frame", {
    LayoutOrder = layoutOrder,
    Size = size,
    AnchorPoint = anchorPoint,
    Position = position,
    SizeConstraint = Enum.SizeConstraint.RelativeYY,
    BackgroundTransparency = 1,

    [Roact.Children] = {
      iconButton
    }
  })
end

return CloseButton