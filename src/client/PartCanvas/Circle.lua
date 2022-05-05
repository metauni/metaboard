-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local NonPhysicalPart = require(script.Parent.NonPhysicalPart)

local function lerp(a, b, t)
	if t < 0.5 then
		return a + (b - a) * t
	else
		return b - (b - a) * (1 - t)
	end
end

return function(props)
	local canvasSize = props.CanvasSize
	local canvasCFrame = props.CanvasCFrame
	
	local aspectRatio = canvasSize.X / canvasSize.Y

	local point = props.Point
	local zIndex = props.ZIndex
	local width = props.Width
	local color = props.Color

	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, point.X / aspectRatio)
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, point.Y)
	local z =
		- Config.Canvas.ZThicknessStuds / 2
		- Config.Canvas.InitialZOffsetStuds
		- zIndex * Config.Canvas.StudsPerZIndex

	return e(NonPhysicalPart, {
		
		Size = Vector3.new(
			Config.Canvas.ZThicknessStuds,
			width * canvasSize.Y,
			width * canvasSize.Y
		),

		Color = color,

		Shape = Enum.PartType.Cylinder,

		CFrame = canvasCFrame * CFrame.new(x,y,z) * CFrame.Angles(0,math.pi/2,0),

	})
end