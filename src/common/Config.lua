local HttpService = game:GetService("HttpService")

local Config = {
	Version = "v0.7.6",
	BoardTag = "metaboard",
	BoardTagPersonal = "metaboard_personal",
	DataStoreTag = "metaboardv2.",

	GenerateUUID = function() return HttpService:GenerateGUID(false) end,
  
	-- Interval in seconds between board persistence saves
	-- Note that there is a 6s cooldown on writing to the same DataStore
	-- key, so that AutoSaveInterval is lower bounded by 6
	AutoSaveInterval = 30,

	LinesLoadedBeforeWait = 300, -- Number of lines to load in Restore before task.wait

	-- Number of lines to iterate over while erasing before task.wait
	LinesSeenBeforeWait = 50,

	-- Number of chars of board Json before which we freeze persistent boards
	-- The DataStore limit is 4M chars
	BoardFullThreshold = 3500000,
}

Config.Drawing = {
	DouglasPeuckerEpsilon = 1/1000,
	CatRomLength = 3/1000,
	-- "DouglasPeucker", "CatRom", or nil (no smoothing)
	SmoothingAlgorithm = nil,

	MinLineLengthPixels = 0,
	MaxLineLengthTouchPixels = 100,

	MinThicknessPixels = 1.5,
	MaxThicknessPixels = 40,

	LineSubdivisionLengthYScale = 20/1000,

	EraserSmallThicknessPixels = 10,
	EraserMediumThicknessPixels = 80,
	EraserLargeThicknessPixels = 250,
}

Config.Toolbar = {

}

Config.Drawing.Defaults = {
	PenAColor = Color3.new(0, 122/255, 255/255),
	PenBColor = Color3.new(0, 122/255, 255/255),
	PenAThicknessPixels = 2,
	PenBThicknessPixels  = 10,
	EraserThicknessPixels = Config.Drawing.EraserSmallThicknessPixels,
}

Config.Gui = {
	-- Pixel width of line before adding UICorner
	UICornerThreshold = 4,
	-- Transparency of shadow behind selected button
	HighlightTransparency = 0.75,
	MuteButtonBlockerThickness = 0.01,
	MuteButtonNearPlaneZOffset = 0.5,
}

Config.Canvas = {
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

Config.History = {
	MaximumSize = 15,
}

return Config
