Config = {
  BoardTag = "metaboard",

  MinThicknessYScale = 1.5/1000,
  MaxThicknessYScale = 40/1000,
  MinLineLengthScale = 0,
  MaxLineLengthTouchScale = 200/1000,

  EraserSmallRadiusYScale = 10/1000,
  EraserMediumRadiusYScale = 80/1000,
  EraserLargeRadiusYScale = 250/1000,

  Gui = {
    HighlightTransparency = 0.75,
  },

  IntersectionResolution = 1/1000,
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
}

Config.PersonalBoard = {
  Enabled = true,
  TorsoOffset = Vector3.new(0,2,-5),
}

function Config.CurveNamer(playerName, curveIndex)
  return playerName..curveIndex
end

return Config