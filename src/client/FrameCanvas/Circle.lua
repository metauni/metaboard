-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)

	return e("Frame", {
		Size = UDim2.fromScale(props.ThicknessYScale, props.ThicknessYScale),
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
		Position = props.Position,

		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.5, 0)
			})
		}
	})
end