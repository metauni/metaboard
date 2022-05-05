return function(name: string, partType: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CanTouch = false -- Do not trigger Touch events
	part.CanQuery = false -- Does not take part in e.g. GetPartsInPart

	if name then
		part.Name = name
	end

	if partType then
		part.Shape = partType
	end

	return part
end