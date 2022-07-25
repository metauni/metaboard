local HttpService = game:GetService("HttpService")

local Config = {
	Version = "v1.0.0",
	BoardTag = "metaboard",
	BoardTagPersonal = "metaboard_personal",
	
	GenerateUUID = function() return HttpService:GenerateGUID(false) end,
	
	Debug = false,
}

Config.Persistence = {

	DataStoreName = "metaboardv2.",
	BoardKeyPrefix = "metaboard",
	-- Interval in seconds between board persistence saves
	-- Note that there is a 6s cooldown on writing to the same DataStore
	-- key, so that AutoSaveInterval is lower bounded by 6
	AutoSaveInterval = 30,
	RestoreAllIntermission = 3,
	RestoreAllNumSimultaneousBoards = 3,

	LinesLoadedBeforeWait = 300, -- Number of lines to load in Restore before task.wait

	-- Number of lines to iterate over while erasing before task.wait
	LinesSeenBeforeWait = 50,

	-- How many bytes of data to store per key (limit is 4MB)
	ChunkSizeLimit = 3500000,

	RestoreTimePerFrame = 5 * 0.001,

	UseMockDataStoreService = false,
}

Config.Canvas = {

	--[[
		When straight line drawing tasks "Finish", they subdivide the line into
		line segments of this length.
	--]]
	LineSubdivisionLengthYScale = 20/1000,

	--[[
		The side length of each cell in the eraser grid
	--]]
	DefaultEraseGridPixelSize = 1/10,
}

Config.DrawingTools = {

	-- Bounds on the stroke width of the Pen/StraightEdge tools
	MinStrokeWidth = 1,
	MaxStrokeWidth = 40,

	-- Default stroke widths for Pen/StraightEdge tools
	Defaults = {
		SmallStrokeWidth = 2,
		MediumStrokeWidth = 10,
		LargeStrokeWidth = 20,
	},

	EraserStrokeWidths = {
		Small = 10,
		Medium = 80,
		Large = 250,
	},
}

-- Colors used in the toolbar drawing UI
Config.UITheme = {
	Background = Color3.new(0.2, 0.2, 0.2),
	Highlight = Color3.new(.8,.8,.8),
	HighlightTransparency = .5,
	Stroke = Color3.new(.9,.9,.9),
	Selected = Color3.fromHex("007AFF"),
}

--[[
	Table of shades for each color with base color names like "Blue" as keys.
	Has the following format (Shades should be an array of 5 colors)
	{
		[string]: {
			BaseColor: Color3,
			Shades: {Color3},
			Index: number,
		}
	}
--]]
Config.ColorPalette = require(script.Parent.ConfigColorPalette)

Config.GuiCanvas = {
	-- Pixel width of line before adding UICorner
	-- TODO: Unused?
	UICornerThreshold = 4,

	-- Limits distance between mouse movements for palm rejection
	MaxLineLengthTouchPixels = 100,

	--[[
		The mute button blocker is a part which occludes the spatial audio mute toggle,
		which can otherwise be clicked through the canvas.
	--]]
	MuteButtonBlockerThickness = 0.01,
	MuteButtonNearPlaneZOffset = 0.5,
}

Config.SurfaceCanvas = {
	-- The line z-thickness (in studs) on the axis normal to the board
	ZThicknessStuds = 0.0001,
	-- How far above the previous curve to draw the next one, in studs
	StudsPerZIndex = 0.0002,
	InitialZOffsetStuds = 0,
	-- InitialZOffsetStuds = 0.0492,
	-- When using Type="RoundedParts", lines which are thicker than this in
	-- studs (not z-thickness) will have circles (cylinder parts) at each end
	-- of the line. TODO: unused?
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
	Capacity = 15,
}

Config.VR = {
	PenToolName = "MetaChalk"
}

return Config
