local HttpService = game:GetService("HttpService")

local Config = {
	Version = "v0.6.1",
	BoardTag = "metaboard",
	DataStoreTag = "metaboardv2.",

	GenerateUUID = function() return HttpService:GenerateGUID(false) end,
  
	-- Interval in seconds between board persistence saves
	-- Note that there is a 6s cooldown on writing to the same DataStore
	-- key, so that AutoSaveInterval is lower bounded by 6
	AutoSaveInterval = 30,

	LinesLoadedBeforeWait = 300, -- Number of lines to load in Restore before task.wait

	-- Number of chars of board Json before which we freeze persistent boards
	-- The DataStore limit is 4M chars
	BoardFullThreshold = 3500000,
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
	-- Distance to put camera while board is open
	CameraHeight = 120,
}

Config.WorldBoard = {
	-- "HandleAdornments" or "Parts" or "RoundedParts"
	LineType = "Parts",
	-- The line z-thickness (in studs) on the axis normal to the board
	ZThicknessStuds = 0.02,
	-- How far above the previous curve to draw the next one, in studs
	StudsPerZIndex = 0.001,
	InitialZOffsetStuds = 0.1,
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
	-- Grab the assetId of a board to use as the personal board from the toolbox
	-- If it's a model, make sure the model is tagged as the metaboard
	-- Examples:
	-- 	WhiteBoardMini: "8545133318"
	-- 	BlackBoardMini: "8545118621"
	AssetId = "8545118621",
	Enabled = true,
	-- Position of where the board will spawn relative to the HumanoidRootPart
	-- Increase y-value for larger boards
	TorsoOffset = Vector3.new(0,2,-5),
}

return Config
