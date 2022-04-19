-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
  local threshold = props.ThicknessYScale >= Config.Canvas.RoundThresholdPixels
  local length = (props.Stop - props.Start).Magnitude + threshold and props.ThicknessYScale or 0

  return e("Frame", {
    Size = UDim2.fromScale(length, props.ThicknessYScale),
    BackgroundColor3 = props.Color,
    BorderSizePixel = 0,
    Rotation = props.Start == props.Stop and 0 or math.deg(math.atan2((props.Stop - props.Start).Y, (props.Stop-props.Start).X)),

    [Roact.Children] = {
      UICorner = threshold and e("UICorner", {
        CornerRadius = UDim.new(0.5, 0)
      }) or nil
    }
  })
end