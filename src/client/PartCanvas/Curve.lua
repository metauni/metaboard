-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local Line = require(script.Parent.Line)

return function(props)
	local canvasSize = props.CanvasSize
	local canvasCFrame = props.CanvasCFrame

	local points = props.Points
	local lineMask = props.Mask
	
	local ithline = function(i)
		local roundedP0 = i == 1 or lineMask[tostring(i-1)]
		local roundedP1 = true

		return not lineMask[tostring(i)] and e(Line, {
			P0 = points[i],
			P1 = points[i+1],
			Width = props.Width,
			Color = props.Color,
			ZIndex = props.ZIndex,

			RoundedP0 = roundedP0,
			RoundedP1 = roundedP1,

			CanvasSize = canvasSize,
			CanvasCFrame = canvasCFrame,
		}) or nil
	end
	
	local lines = {}
	for i=1, #points-1 do
		lines[i] = ithline(i)
	end

	return e("Folder", {}, lines)
end