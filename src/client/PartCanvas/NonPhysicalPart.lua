
-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Dictionary = Sift.Dictionary

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