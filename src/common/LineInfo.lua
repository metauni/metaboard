local LineInfo = {}
LineInfo.__index = LineInfo

function LineInfo.new(start, stop, thicknessYScale, color)
	return setmetatable({
		Start = start,
		Stop = stop,
		Color = color,
		Centre = (start + stop)/2,
		Length = (stop-start).Magnitude,
		ThicknessYScale = thicknessYScale,
		RotationRadians = math.atan2((stop - start).Y, (stop-start).X),
		RotationDegrees = math.deg(math.atan2((stop - start).Y, (stop-start).X)),
	}, LineInfo)
end

function LineInfo.StoreInfo(object, info)
	object:SetAttribute("Start", info.Start)
	object:SetAttribute("Stop", info.Stop)
	object:SetAttribute("Color", info.Color)
	object:SetAttribute("ThicknessYScale", info.ThicknessYScale)
end

function LineInfo.ReadInfo(object)
	local start = object:GetAttribute("Start")
	local stop = object:GetAttribute("Stop")
	local thicknessYScale = object:GetAttribute("ThicknessYScale")
	local color = object:GetAttribute("Color")
	
	if start == nil or stop == nil or thicknessYScale == nil or color == nil then
		return nil
	else
		return LineInfo.new(start, stop, thicknessYScale, color)
	end
end

function LineInfo.ClearInfo(object)
	object:SetAttribute("Start", nil)
	object:SetAttribute("Stop", nil)
	object:SetAttribute("ThicknessYScale", nil)
	object:SetAttribute("Color", nil)
end

-- True iff the circle centred at <pos> with radius <radius> intersects
-- the line with LineInfo <lineInfo>
function LineInfo.Intersects(pos, radius, lineInfo)
	-- Vector from the start of the line to pos
	local u = pos - lineInfo.Start
	-- Vector from the start of the line to the end of the line
	local v = lineInfo.Stop - lineInfo.Start
	
	-- the magnitude (with sign) of the projection of u onto v
	local m = u:Dot(v.Unit)

	if m <= 0 or lineInfo.Start == lineInfo.Stop then
		-- The closest point on the line to pos is lineInfo.Start
		return u.Magnitude <= radius + lineInfo.ThicknessYScale/2
	elseif m >= v.Magnitude then
		-- The closest point on the line to pos is lineInfo.Stop
		return (pos - lineInfo.Stop).Magnitude <= radius + lineInfo.ThicknessYScale/2
	else
		-- The vector from pos to it's closest point on the line makes a perpendicular with the line
		return math.abs(u:Cross(v.Unit)) <= radius + lineInfo.ThicknessYScale/2
	end
end

return LineInfo