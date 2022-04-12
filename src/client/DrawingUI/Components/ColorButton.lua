-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Config = require(Common.Config)
local Assets = require(Common.Assets)

local ColorButton = Roact.PureComponent:extend("ColorButton")

function ColorButton:init()
  self:setState({ Hovering = false })
end
ColorButton.defaultProps = {
  Size = UDim2.fromScale(1, 1),
  LayoutOrder = 0,
  Expandable = false,
}

function ColorButton:render()
  local color = self.props.Color
  local layoutOrder = self.props.LayoutOrder
  local selected = self.props.Selected
  local expandable = self.props.Expandable
  local onClick = self.props.OnClick
  local size = self.props.Size

  local hovering = self.state.Hovering

  local expandButton = e("ImageLabel", {
    Image = Assets["expand-down"],
    Size = UDim2.fromOffset(24,24),
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    BackgroundTransparency = 1,
    ZIndex = 2,
  })

  local icon = e("Frame", {
    AnchorPoint = Vector2.new(0.5,0.5),
    BackgroundColor3 = color,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = hovering and UDim2.fromOffset(30, 30) or UDim2.fromOffset(25,25),
    ZIndex = 1,

    [Roact.Children] = {
      UICorner = e("UICorner", { CornerRadius = UDim.new(0.5,0) }),
      UIStroke = selected and e("UIStroke", { Thickness = 3, Color = Config.UITheme.Highlight }) or nil,
      ExpandButton = expandable and expandButton or nil
    }
  })

  -- local highlight = e("Frame", {
  --   AnchorPoint = Vector2.new(0.5, 0.5),
  --   BackgroundColor3 = Color3.fromRGB(255, 255, 255),
  --   BackgroundTransparency = selected and 0.5 or 0.75,
  --   Position = UDim2.fromScale(0.5, 0.5),
  --   Size = UDim2.fromOffset(36,36),
  --   ZIndex = 0,
  -- },
  --   { uICorner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) })
  -- })

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
  }, {
    icon = icon,
  })
end

return ColorButton