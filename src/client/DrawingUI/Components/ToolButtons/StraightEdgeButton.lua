-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Assets = require(Common.Assets)

local StraightEdgeButton = Roact.PureComponent:extend("StraightEdgeButton")
StraightEdgeButton.defaultProps = {
  LayoutOrder = 0
}

function StraightEdgeButton:init()
  self:setState({ Hovering = false })
end

function StraightEdgeButton:render()
  local size = self.props.Size
  local layoutOrder = self.props.LayoutOrder
  local onClick = self.props.OnClick
  local selected = self.props.Selected
  local hovering = self.state.Hovering

  local baseSize = selected and UDim2.fromOffset(48,48) or UDim2.fromOffset(40,40)
  local position = UDim2.fromScale(0.5, 0.5) + (selected and UDim2.fromOffset(0,0) or UDim2.new())

  local icon = e("ImageLabel", {
    Image = selected and Assets["straightedge-selected"] or Assets["straightedge-deselected"],
    ImageTransparency = 0,
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = position,
    Size = hovering and UDim2.fromOffset(53,53) or UDim2.fromOffset(48,48),
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

return StraightEdgeButton