-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local NonPhysicalPart = require(script.Parent.NonPhysicalPart)
local Circle = require(script.Parent.Circle)

local function lerp(a, b, t)
	if t < 0.5 then
		return a + (b - a) * t
	else
		return b - (b - a) * (1 - t)
	end
end

return function(props)
	if props.Mask then
		return nil
	end

	local canvasSize = props.CanvasSize
	local canvasCFrame = props.CanvasCFrame
	
	local aspectRatio = canvasSize.X / canvasSize.Y

	local roundedP0 = props.RoundedP0
	local roundedP1 = props.RoundedP1

	local length = (props.P0 - props.P1).Magnitude + ((roundedP0 or roundedP1) and 0 or props.Width)
	local centre = (props.P0 + props.P1)/2
	local rotation = math.atan2((props.P0 - props.P1).Y, (props.P0 - props.P1).X)

	-- Position of the centre of the line relative to the surface of the board
	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, centre.X / aspectRatio)
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, centre.Y)
	local z =
		- Config.Canvas.ZThicknessStuds / 2
		- Config.Canvas.InitialZOffsetStuds
		- props.ZIndex * Config.Canvas.StudsPerZIndex

	return e(NonPhysicalPart, {
		
		Size = Vector3.new(
			length * canvasSize.Y,
			props.Width * canvasSize.Y,
			Config.Canvas.ZThicknessStuds
		),

		Color = props.Color,

		CFrame = canvasCFrame * CFrame.new(x,y,z) * CFrame.Angles(0, 0, rotation),

		[Roact.Children] = {
			
			P0 = roundedP0 and e(Circle, {
				
				Point = props.P0,
				Width = props.Width,
				Color = props.Color,
				ZIndex = props.ZIndex,

				CanvasSize = canvasSize,
				CanvasCFrame = canvasCFrame,

			}) or nil,

			P1 = roundedP1 and e(Circle, {
				
				Point = props.P1,
				Width = props.Width,
				Color = props.Color,
				ZIndex = props.ZIndex,

				CanvasSize = canvasSize,
				CanvasCFrame = canvasCFrame,

			}) or nil,

		}

	})
end