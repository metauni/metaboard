-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Config = require(Common.Config)
local StrokeButton = require(script.Parent.StrokeButton)
local Slider = require(script.Parent.Slider)


local StrokeWidthSubMenu = Roact.PureComponent:extend("StrokeWidthSubMenu")
StrokeWidthSubMenu.defaultProps = {
  ColorPalette = Config.ColorPalette,
  AnchorPoint = Vector2.new(0.5,0.5),
  Position = UDim2.fromScale(0.5,0.5),
}

function StrokeWidthSubMenu:render()
  local anchorPoint = self.props.AnchorPoint
  local position = self.props.Position
  local strokeWidths = self.props.StrokeWidths
  local selectedStrokeWidthName = self.props.SelectedStrokeWidthName
  local selectStrokeWidth = self.props.SelectStrokeWidth
  local updateStrokeWidth = self.props.UpdateStrokeWidth
  local color = self.props.Color

  local strokeButton = function(props)
    return e(StrokeButton, {
      Size = UDim2.fromOffset(55, 55),
      Color = color,
      Width = math.round(strokeWidths[props.StrokeWidthName]),
      LayoutOrder = props.LayoutOrder,
      Selected = props.StrokeWidthName == selectedStrokeWidthName,
      OnClick = function()
        selectStrokeWidth(props.StrokeWidthName)
      end,
    })
  end
  
  local buttons = e("Frame", {
    Size = UDim2.fromOffset(185, 75),
    AnchorPoint = anchorPoint,
    Position = position,
    BackgroundTransparency = 1,
  },
  {
    UIListLayout = e("UIListLayout", {
      Padding = UDim.new(0,10),
      FillDirection = Enum.FillDirection.Horizontal,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      VerticalAlignment = Enum.VerticalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
    }),
    Small = e(strokeButton, {
      LayoutOrder = 1,
      StrokeWidthName = "Small"
    }),
    Medium = e(strokeButton, {
      LayoutOrder = 2,
      StrokeWidthName = "Medium"
    }),
    Large = e(strokeButton, {
      LayoutOrder = 3,
      StrokeWidthName = "Large"
    }),
  })


  local selectedStrokeWidth = strokeWidths[selectedStrokeWidthName]

  local slider do
    local function thicknessToAlpha(thickness)
      local scale = (thickness - Config.Drawing.MinStrokeWidth) / (Config.Drawing.MaxStrokeWidth - Config.Drawing.MinStrokeWidth)
      return math.pow(scale, 1/2)
    end

    local function alphaToThickness(alpha)
      local scale = math.pow(alpha,2)
      return Config.Drawing.MinStrokeWidth * (1-scale) + Config.Drawing.MaxStrokeWidth * scale
    end

    local knobAlpha = thicknessToAlpha(selectedStrokeWidth)


    slider = e(Slider, {
      OnKnobPositionUpdate = function(alpha)
        updateStrokeWidth(alphaToThickness(alpha))
      end,
      KnobAlpha = knobAlpha,
      KnobLabelText = tostring(math.round(selectedStrokeWidth)),
      LayoutOrder = 3,
      State = self.props.SliderState,
      SetState = self.props.SetSliderState
    })
  end
  
  return e("Frame", {
    Size = UDim2.fromOffset(220, 135),
    AnchorPoint = anchorPoint,
    Position = position,
    BackgroundColor3 = Config.UITheme.Background,
    BorderSizePixel = 0,
  },
  {
    UIListLayout = e("UIListLayout", {
      Padding = UDim.new(0,0),
      FillDirection = Enum.FillDirection.Vertical,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      VerticalAlignment = Enum.VerticalAlignment.Top,
      SortOrder = Enum.SortOrder.LayoutOrder,
    }),
    UICorner = e("UICorner", {CornerRadius = UDim.new(0, 10)}),

    Buttons = buttons,
    
    Divider = e("Frame", {
      Size = UDim2.fromOffset(185, 3),
      BackgroundColor3 = Config.UITheme.Stroke,
      BorderSizePixel = 0,
      LayoutOrder = 2,
    }),

    Slider = slider,
  })



end

return StrokeWidthSubMenu