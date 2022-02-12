local HttpService = game:GetService("HttpService")

local Config = {
	Version = "v0.10.0",
	BoardTag = "metaboard",
	BoardTagPersonal = "metaboard_personal",
	BoardTagHistory = "metaboard_history",
	DataStoreTag = "metaboardv2.",

	GenerateUUID = function() return HttpService:GenerateGUID(false) end,
  
	-- Interval in seconds between board persistence saves
	-- Note that there is a 6s cooldown on writing to the same DataStore
	-- key, so that AutoSaveInterval is lower bounded by 6
	AutoSaveInterval = 20,

	LinesLoadedBeforeWait = 300, -- Number of lines to load in Restore before task.wait

	-- Number of lines to iterate over while erasing before task.wait
	LinesSeenBeforeWait = 50,
}

Config.Drawing = {
	DouglasPeuckerEpsilon = 1/1000,
	CatRomLength = 3/1000,
	-- "DouglasPeucker", "CatRom", or nil (no smoothing)
	SmoothingAlgorithm = nil,

	MinLineLengthYScale = 0,
	MaxLineLengthTouch = 100,

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
	MuteButtonBlockerThickness = 0.01,
	MuteButtonNearPlaneZOffset = 0.5,
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

Config.History = {
	MaximumSize = 15,
}

Config.HistoryBoard = {
	Material = Enum.Material.LeafyGrass,
}

-- Shades of all the available colors. Currently Hardcoded.
Config.ColorShades = {
	Blue = {Color3.fromRGB(0, 67, 141), Color3.fromRGB(0, 94, 198), Color3.fromRGB(0, 122, 255), Color3.fromRGB(56, 151, 255), Color3.fromRGB(113, 181, 255), Color3.fromRGB(170, 210, 255), Color3.fromRGB(226, 240, 255)},
	Black = {Color3.new(), Color3.fromRGB(32, 32, 32), Color3.fromRGB(56, 56, 56), Color3.fromRGB(113, 113, 113), Color3.fromRGB(170, 170, 170), Color3.fromRGB(220, 220, 220), Color3.new(1, 1, 1)},	
	White = {Color3.new(), Color3.fromRGB(32, 32, 32), Color3.fromRGB(56, 56, 56), Color3.fromRGB(113, 113, 113), Color3.fromRGB(170, 170, 170), Color3.fromRGB(220, 220, 220), Color3.new(1, 1, 1)},	
	Green = {Color3.fromRGB(56, 88, 24), Color3.fromRGB(98, 154, 42), Color3.fromRGB(126, 198, 54), Color3.fromRGB(154, 210, 98), Color3.fromRGB(183, 223, 143), Color3.fromRGB(212, 236, 188), Color3.fromRGB(240, 248, 232)},
	Orange = {Color3.fromRGB(108, 68, 15), Color3.fromRGB(163, 102, 23), Color3.fromRGB(245, 154, 35), Color3.fromRGB(255, 255, 0), Color3.fromRGB(247, 176, 83), Color3.fromRGB(249, 198, 132), Color3.fromRGB(251, 221, 181)},
	Red = {Color3.fromRGB(93, 0, 0), Color3.fromRGB(163, 0, 0), Color3.fromRGB(210, 0, 0), Color3.fromRGB(220, 56, 56), Color3.fromRGB(230, 113, 113), Color3.fromRGB(240, 170, 170), Color3.fromRGB(250, 226, 226)},
	Pink = {Color3.fromRGB(141, 75, 118), Color3.fromRGB(198, 105, 165), Color3.fromRGB(255, 136, 213), Color3.fromRGB(255, 162, 222), Color3.fromRGB(255, 188, 231), Color3.fromRGB(255, 215, 241), Color3.fromRGB(255, 241, 250)},
	Purple = {Color3.fromRGB(72, 18, 77), Color3.fromRGB(101, 25, 108), Color3.fromRGB(130, 33, 139), Color3.fromRGB(157, 82, 164), Color3.fromRGB(185, 142, 190), Color3.fromRGB(213, 181, 216), Color3.fromRGB(241, 230, 242)}
}

return Config
