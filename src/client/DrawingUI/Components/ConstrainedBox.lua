-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)

	local box = e("Frame", {

		BackgroundTransparency = 0.9,

		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		Size = UDim2.fromScale(1,1),

		[Roact.Change.AbsoluteSize] = function(rbx)
			props.OnAbsoluteSizeUpdate(rbx.AbsoluteSize)
		end,
		[Roact.Change.AbsolutePosition] = function(rbx)
			props.OnAbsolutePositionUpdate(rbx.AbsolutePosition)
		end,

		[Roact.Children] = {
			UIAspectRatioConstraint = e("UIAspectRatioConstraint", {
				AspectRatio = props.AspectRatio,
			})
		}
	})

	return e("Frame", {

		BackgroundTransparency = 1,

		Position = props.Position,
		Size = props.Size,

		[Roact.Children] = {
			Box = box
		}

	})
end