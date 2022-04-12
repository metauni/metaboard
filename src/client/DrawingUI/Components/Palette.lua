-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary

local ColorButton = require(script.Parent.ColorButton)


local Palette = Roact.PureComponent:extend("Palette")

Palette.defaultProps = {
  Height = UDim.new(0,50),
  Position = UDim2.fromScale(0.5,0.5),
  Spacing = UDim.new(0,10),
  ButtonDim = UDim.new(0,40),
}

-- function Palette:MakeColorButton(namedColor, layoutOrder)
--   local buttonDim = self.props.ButtonDim
--   local onNamedColorClick = self.props.OnNamedColorClick
  
--   return e(ColorButton, {
--     Color = namedColor.Color,
--     LayoutOrder = layoutOrder,
--     Selected = selectedColorName == namedColor.Name,
--     Expandable = selectedColorName == namedColor.Name,
--     Size = UDim2.new(buttonDim, buttonDim),
--     OnClick = function()
--       onNamedColorClick(namedColor)
--     end
--   })
-- end


function Palette:render()
  local spacing = self.props.Spacing
  local position = self.props.Position
  local height = self.props.Height
  local layoutOrder = self.props.LayoutOrder
  local selectedColorWellIndex = self.props.SelectedColorWellIndex
  local onColorWellClick = self.props.OnColorWellClick
  local colorWells = self.props.ColorWells
  local subMenu = self.props.SubMenu

  local buttons = {} do
    for i, shadedColor in ipairs(colorWells) do
      local selected = i == selectedColorWellIndex
      buttons[i] = e(ColorButton, {
        Color = shadedColor.Color,
        LayoutOrder = layoutOrder,
        Selected = selected,
        Expandable = selected,
        Size = UDim2.fromOffset(50,50),
        OnClick = function()
          onColorWellClick(i)
        end
      })
    end
  end

  local buttonList = e("Frame", {
    Size = UDim2.fromScale(1,1),
    BackgroundTransparency = 1,
  },
  {
    UIListLayout = e("UIListLayout", {
      Padding = UDim.new(0,0),
      FillDirection = Enum.FillDirection.Horizontal,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      VerticalAlignment = Enum.VerticalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
    }),
    UIPadding = e("UIPadding", {
      PaddingLeft = spacing,
      PaddingRight = spacing,
    }),
    buttons = Roact.createFragment(buttons),
  })

  
  
  return e("Frame", {
    Size = UDim2.new(UDim.new(0,250), height),
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = position,
    LayoutOrder = layoutOrder,
    BackgroundTransparency = 1,
    
    [Roact.Children] = Dictionary.merge(self.props[Roact.Children], {
      ButtonList = buttonList,
      SubMenu = subMenu,
    })
  })



end

return Palette