-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
	if props.Mask then
		return nil
	end

	local length = (props.P0 - props.P1).Magnitude + props.Width
	local rotation = props.P1 == props.P0 and 0 or math.deg(math.atan2((props.P0 - props.P1).Y, (props.P0 - props.P1).X))
	local centre = (props.P0 + props.P1)/2

	return e("Frame", {

		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(centre.X, centre.Y),
		Size = UDim2.fromScale(length, props.Width),
		Rotation = rotation,

		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,

		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.5, 0)
			})
		}

	})
end