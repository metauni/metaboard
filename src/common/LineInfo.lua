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

return LineInfo