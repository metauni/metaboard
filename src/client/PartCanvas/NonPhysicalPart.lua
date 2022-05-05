
-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Dictionary = require(Common.Packages.Llama).Dictionary

return function(props)

	return e("Part", Dictionary.merge({
		
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Anchored = true,
		CanCollide = false,
		CastShadow = false, 
		CanTouch = false, -- Do not trigger Touch events
		CanQuery = false, -- Does not take part in e.g. GetPartsInPart

	}, props))
end