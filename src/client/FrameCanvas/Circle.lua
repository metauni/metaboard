-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)

	return e("Frame", {
		Size = UDim2.fromScale(props.Width, props.Width),
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(props.Position.X, props.Position.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),

		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.5, 0)
			})
		}
	})
end