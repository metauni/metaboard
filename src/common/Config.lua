local HttpService = game:GetService("HttpService")

local Config = {
	Version = "v0.3.4",
	BoardTag = "metaboard",
	DataStoreTag = "metaboardv2.",

	GenerateUUID = function() return HttpService:GenerateGUID(false) end
}

Config.Drawing = {
	DouglasPeuckerEpsilon = 1/1000,
	CatRomLength = 3/1000,
	-- "DouglasPeucker", "CatRom", or nil (no smoothing)
	SmoothingAlgorithm = nil,

	MinLineLengthYScale = 0,
	MaxLineLengthTouchYScale = 200/1000,

	MinThicknessYScale = 1.5/1000,
	MaxThicknessYScale = 40/1000,

	LineSubdivisionLength = 20/1000,

	EraserSmallThicknessYScale = 10/1000,
	EraserMediumThicknessYScale = 80/1000,
	EraserLargeThicknessYScale = 250/1000,
}

Config.Drawing.Defaults = {
	PenAColor = Color3.new(0, 122/255, 255/255),
	PenBColor = Color3.new(0, 122/255, 255/255),
	PenAThicknessYScale = 2/1000,
	PenBThicknessYScale  = 10/1000,
	EraserThicknessYScale = Config.Drawing.EraserSmallThicknessYScale,
}

Config.Gui = {
	-- Pixel width of line before adding UICorner
	UICornerThreshold = 4,
	-- Transparency of shadow behind selected button
	HighlightTransparency = 0.75,
}

Config.WorldBoard = {
	-- "HandleAdornments" or "Parts" or "RoundedParts"
	LineType = "Parts",
	-- The line z-thickness (in studs) on the axis normal to the board
	ZThicknessStuds = 0.01,
	-- How far above the previous curve to draw the next one, in studs
	StudsPerZIndex = 0.001,
	-- When using Type="RoundedParts", lines which are thicker than this in
	-- studs (not z-thickness) will have circles (cylinder parts) at each end
	-- of the line
	RoundThresholdStuds = 0.05,
	-- The thickness of the invisible canvas that is spawned on top of the 
	-- drawing surface
	-- Will be able to draw n = (CanvasThickness - ZThicknessStuds)/StudsPerIndex
	-- many curves before the curves appear above the SurfaceGui button
	-- e.g. (0.5 - 0.1)/0.001 = 400
	CanvasThickness = 0.5,
}

Config.PersonalBoard = {
	Enabled = true,
	TorsoOffset = Vector3.new(0,2,-5),
}

return Config