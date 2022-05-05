-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local Line = require(script.Parent.Line)

local Curve = Roact.PureComponent:extend("Curve")

function Curve:render()
	local points = self.props.Points
	local lineMask = self.props.Mask
	local elements = {}

	local ithline = function(i)
		return not lineMask[i] and e(Line, {
			P0 = points[i],
			P1 = points[i+1],
			Width = self.props.Width,
			Color = self.props.Color,
			Rounded = true
		}) or nil
	end
	
	for i=1, #points-1 do
		elements[i] = ithline(i)
	end

	return e("Folder", {}, elements)
end

return Curve