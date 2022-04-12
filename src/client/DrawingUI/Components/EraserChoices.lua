-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Config = require(Common.Config)
local Assets = require(Common.Assets)

local ThicknessButton = Roact.PureComponent:extend("ThicknessButton")

function ThicknessButton:init()
  self:setState({ Hovering = false })
end

function ThicknessButton:render()
  local layoutOrder = self.props.LayoutOrder
  local selected = self.props.Selected
  local selectedIcon = self.props.SelectedIcon
  local deselectedIcon = self.props.DeselectedIcon
  local onClick = self.props.OnClick
  local position = self.props.Position
  local size = self.props.Size

  local hovering = self.state.Hovering

  local icon = e("ImageLabel", {
    Image = selected and selectedIcon or deselectedIcon,
    Size = (hovering and not selected) and UDim2.fromOffset(85,85) or UDim2.fromOffset(80,80),
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    BackgroundTransparency = 1,
  })
  
  return e("TextButton", {
    Text = "",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = position,
    Size = UDim2.fromOffset(60,60),
    LayoutOrder = layoutOrder,
    AutoButtonColor = false,
    [Roact.Event.Activated] = onClick,
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


local EraserChoices = Roact.PureComponent:extend("EraserChoices")
EraserChoices.defaultProps = {
  Height = UDim.new(0,40),
  Position = UDim2.fromScale(0.5,0.5),
  Spacing = UDim.new(0,20),
  ButtonDim = UDim.new(0,70),
}


function EraserChoices:render()
  local size = self.props.Size
  local position = self.props.Position
  local layoutOrder = self.props.LayoutOrder
  local selectedEraserSizeName = self.props.SelectedEraserSizeName
  local onSmallClick = self.props.OnSmallClick
  local onMediumClick = self.props.OnMediumClick
  local onLargeClick = self.props.OnLargeClick


  return e("Frame", {
    Size = size,
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = position,
    BackgroundTransparency = 1,
    LayoutOrder = layoutOrder,
    -- ClipsDescendants = true,


    [Roact.Children] = {

      Small = e(ThicknessButton, {
        Position = UDim2.new(0,30,0.5,0),
        OnClick = onSmallClick,
        Selected = selectedEraserSizeName == "Small",
        SelectedIcon = Assets["eraser-small-selected"],
        DeselectedIcon = Assets["eraser-small-deselected"]
      }),
      Medium = e(ThicknessButton, {
        Position = UDim2.new(0,80,0.5,0),
        OnClick = onMediumClick,
        Selected = selectedEraserSizeName == "Medium",
        SelectedIcon = Assets["eraser-medium-selected"],
        DeselectedIcon = Assets["eraser-medium-deselected"]
      }),
      Large = e(ThicknessButton, {
        Position = UDim2.new(0,150,0.5,0),
        OnClick = onLargeClick,
        Selected = selectedEraserSizeName == "Large",
        SelectedIcon = Assets["eraser-large-selected"],
        DeselectedIcon = Assets["eraser-large-deselected"]
      }),
    }
  })


end

return EraserChoices