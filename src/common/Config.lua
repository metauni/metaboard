local Config = {
	Version = "v0.3.4",
	BoardTag = "metaboard",
	DataStoreTag = "metaboardv2.",

	MinThicknessYScale = 1.5/1000,
	MaxThicknessYScale = 40/1000,
	MinLineLengthScale = 0,
	MaxLineLengthTouchScale = 200/1000,

	-- Pixel width of line before adding UICorner
	UICornerThreshold = 4,

	EraserSmallRadiusYScale = 10/1000,
	EraserMediumRadiusYScale = 80/1000,
	EraserLargeRadiusYScale = 250/1000,

	Gui = {
		HighlightTransparency = 0.75,
	},

	IntersectionResolution = 1/1000,

	DouglasPeuckerEpsilon = 1/1000,
	CatRomLength = 3/1000,

	-- "DouglasPeucker", "CatRom", or nil (no smoothing)
	SmoothingAlgorithm = nil,

	-- Will be able to draw n = (CanvasThickness - ZThicknessStuds)/StudsPerIndex
	-- many curves before the curves appear above the SurfaceGui button
	-- e.g. (0.5 - 0.1)/0.001 = 400
	CanvasThickness = 0.5,

	-- "HandleAdornments" or "Parts" or "RoundedParts"
	WorldLineType = "Parts",

	UseCache = false,
}

Config.Defaults = {
	PenAColor = Color3.new(0, 122/255, 255/255),
	PenBColor = Color3.new(0, 122/255, 255/255),
	PenAThicknessYScale = 2/1000,
	PenBThicknessYScale = 10/1000,
	EraserRadiusYScale = Config.EraserSmallRadiusYScale,
}

Config.WorldLine = {
	ZThicknessStuds = 0.01,
	StudsPerZIndex = 0.001,
	RoundThresholdStuds = 0.05
}

Config.PersonalBoard = {
	Enabled = true,
	TorsoOffset = Vector3.new(0,2,-5),
}

function Config.CurveNamer(player, curveIndex)
	return player.UserId.."#"..curveIndex
end

return Config