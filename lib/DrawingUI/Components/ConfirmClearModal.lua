-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement
local Config = require(root.Config)

return function(props)

  return e("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Config.UITheme.Background,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 180),
  }, {
    ConfirmClearButton = e("TextButton", {
      AutoButtonColor = true,
      Font = Enum.Font.GothamMedium,
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
      Font = Enum.Font.GothamMedium,
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