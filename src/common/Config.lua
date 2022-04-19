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

	MinStrokeWidth = 1,
	MaxStrokeWidth = 40,

	LineSubdivisionLengthYScale = 20/1000,

	EraserSmallStrokeWidth = 10,
	EraserMediumStrokeWidth = 80,
	EraserLargeStrokeWidth = 250,

	Defaults = {
		SmallStrokeWidth = 2,
		MediumStrokeWidth = 10,
		LargeStrokeWidth = 20,
	}
}

Config.UITheme = {
	Background = Color3.new(0.2, 0.2, 0.2),
	Highlight = Color3.new(.8,.8,.8),
	HighlightTransparency = .5,
	Stroke = Color3.new(.9,.9,.9),
	Selected = Color3.fromHex("007AFF"),
}

local function hslToRgb(h, s, l)
  local r, g, b

  if s == 0 then
    r = l
    g = l
    b = l
  else
    local hue2rgb = function(p, q, t)
      if t < 0 then t += 1 end
      if t > 1 then t -= 1 end
      if t < 1/6 then
        return p + (q - p) * 6 * t
      elseif t < 1/2 then
        return q
      elseif t < 2/3 then
        return p + (q - p) * (2/3 - t) * 6
      else
        return p
      end
    end

    local q = if l < 0.5 then l * (1 + s) else l + s - l * s
    local p = 2 * l - q
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  end

  return r, g, b
end

local function rgbToHsl(r, g, b)
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s, l
  l = (max + min) / 2

  if max == min then
    h = 0
    s = 0
  else
    local d = max - min
    s = if l > 0.5 then d / (2 - max - min) else d / (max + min)
    if max == r then
      h = (g - b) / d + (if g < b then 6 else 0)
    elseif max == g then
      h = (b - r) / d + 2
    elseif max == b then
      h = (r - g) / d + 4
    else
      error("one of these should have been equal to max")
    end
    h /= 6
  end

  return h, s, l
end

Config.ColorPalette = {
	{Name = "White",  BaseColor = Color3.fromHex("FCFCFC"), ShadeAlphas = {-4/10, -3/10, -2/10, 1/10, 0}},
	{Name = "Black",  BaseColor = Color3.fromHex("000000"), ShadeAlphas = {0, 1/10, 2/10, 3/10, 4/10}},
	{Name = "Blue",   BaseColor = Color3.fromHex("007AFF"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
	{Name = "Green",  BaseColor = Color3.fromHex("7EC636"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
	{Name = "Red",    BaseColor = Color3.fromHex("D20000"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
	{Name = "Orange", BaseColor = Color3.fromHex("F59A23"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
	{Name = "Purple", BaseColor = Color3.fromHex("82218B"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
	{Name = "Pink",   BaseColor = Color3.fromHex("FF58C4"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}},
}

Config.BaseColorByName = {}

for _, colorTable in ipairs(Config.ColorPalette) do
	colorTable.Shades = table.create(#colorTable.ShadeAlphas)
	local h, s, l = rgbToHsl(colorTable.BaseColor.R, colorTable.BaseColor.G, colorTable.BaseColor.B)
	for i, shadeAlpha in ipairs(colorTable.ShadeAlphas) do
		if shadeAlpha >= 0 then
			local shadeLum = shadeAlpha * (1-l) + l
			colorTable.Shades[i] = Color3.new(hslToRgb(h,s,shadeLum))
		else
			local shadeLum = l - -shadeAlpha * l
			colorTable.Shades[i] = Color3.new(hslToRgb(h,s,shadeLum))
		end
	end

	Config.BaseColorByName[colorTable.Name] = Config.BaseColor
end




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
	Capacity = 15,
}

Config.MaxLoadedBoards = 2
Config.NearbyBoardsRefreshInterval = 1
Config.Debug = false
Config.DefaultEraseGridPixelSize = 1/100

return Config
