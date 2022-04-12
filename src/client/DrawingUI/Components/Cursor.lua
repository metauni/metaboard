-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
  local size = props.Size
  local color = props.Color or Color3.new(0,0,0)
  local position = props.Position

  return e("Frame", {
    Size = size,
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = position,
    BackgroundTransparency = 0.8,
    BackgroundColor3 = color,

    [Roact.Children] = {
      UICorner = e("UICorner", { CornerRadius = UDim.new(0.5,0) }),
      UIStroke = e("UIStroke", { Thickness = 2, Color = color })
    }
  })
end
