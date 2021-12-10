local LineInfo = {}
LineInfo.__index = LineInfo

function LineInfo.new(start, stop, thicknessYScale, color, curveName)
  return setmetatable({
    Start = start,
    Stop = stop,
    Color = color,
    Centre = (start + stop)/2,
    Length = (stop-start).Magnitude,
    ThicknessYScale = thicknessYScale,
    RotationRadians = math.atan2((stop - start).Y, (stop-start).X),
    RotationDegrees = math.deg(math.atan2((stop - start).Y, (stop-start).X)),
    CurveName = curveName,
  }, LineInfo)
end

function LineInfo.StoreInfo(object, info)
  object:SetAttribute("Start", info.Start)
  object:SetAttribute("Stop", info.Stop)
  object:SetAttribute("Color", info.Color)
  object:SetAttribute("ThicknessYScale", info.ThicknessYScale)
end

function LineInfo.ReadInfo(object)
  return LineInfo.new(
    object:GetAttribute("Start"),
    object:GetAttribute("Stop"),
    object:GetAttribute("ThicknessYScale"),
    object:GetAttribute("Color"),
    object.Parent.Name)
end

return LineInfo