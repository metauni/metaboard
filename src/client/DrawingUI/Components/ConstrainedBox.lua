-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

--[[
	Creates the largest box (frame) of a fixed aspect ratio that fits within
	the given props.Position and props.Size.

	Also fires callbacks to record the resulting box absolutePosition and
	absoluteSize whenever it changes (e.g. window resize).
--]]
return function(props)

	local box = e("Frame", {

		BackgroundTransparency = 1,

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