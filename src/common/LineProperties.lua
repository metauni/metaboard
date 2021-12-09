local LineProperties = {}
LineProperties.__index = LineProperties

function LineProperties.new(start, stop, thicknessYScale, color, curveName)
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
  }, LineProperties)
end

function LineProperties:StoreAttributes(lineObject)
  lineObject:SetAttribute("Start", self.Start)
  lineObject:SetAttribute("Stop", self.Stop)
  lineObject:SetAttribute("Color", self.Color)
  lineObject:SetAttribute("ThicknessYScale", self.ThicknessYScale)
end

function LineProperties.ReadFromAttributes(lineObject)
  return LineProperties.new(
    lineObject:GetAttribute("Start"),
    lineObject:GetAttribute("Stop"),
    lineObject:GetAttribute("ThicknessYScale"),
    lineObject:GetAttribute("Color"),
    lineObject.Parent.Name)
end

function LineProperties:Equals(otherLineProperties)
  -- TODO check more properties?
  return
    self.Start == otherLineProperties.Start and
    self.Stop == otherLineProperties.Stop and
    self.ThicknessYScale == otherLineProperties.ThicknessYScale
end

return LineProperties