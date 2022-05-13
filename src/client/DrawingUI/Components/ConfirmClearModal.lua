-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Config = require(Common.Config)

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)

  return e("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Config.UITheme.Background,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 180),
  }, {
    ConfirmClearButton = e("TextButton", {
      AutoButtonColor = true,
      Font = Enum.Font.GothamSemibold,
      Text = "Confirm Clear",
      TextColor3 = Config.UITheme.Stroke,
      TextSize = 24,
      AnchorPoint = Vector2.new(0.5, 0.5),
      BackgroundColor3 = Color3.fromRGB(210, 0, 0),
      Position = UDim2.new(0.5, 0, 0.5, -40),
      Size = UDim2.fromOffset(180, 50),
      
      [Roact.Event.Activated] = props.OnConfirm,

    }, {
      UICorner = e("UICorner", { CornerRadius =  UDim.new(0,8) }),
    }),

    CancelButton = e("TextButton", {
      AutoButtonColor = true,
      Font = Enum.Font.GothamSemibold,
      Text = "Cancel",
      TextColor3 = Config.UITheme.Stroke,
      TextSize = 24,
      AnchorPoint = Vector2.new(0.5, 0.5),
      BackgroundColor3 = Config.UITheme.Highlight,
      BackgroundTransparency = 0.5,
      Position = UDim2.new(0.5, 0, 0.5, 40),
      Size = UDim2.fromOffset(180, 50),

      [Roact.Event.Activated] = props.OnCancel,

    }, {
      UICorner = e("UICorner", { CornerRadius =  UDim.new(0,8) }),
    }),

    UICorner = e("UICorner", { CornerRadius =  UDim.new(0,8) }),
  })
end