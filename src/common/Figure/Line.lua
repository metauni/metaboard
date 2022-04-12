local Line = {}
Line.__index = Line

function Line.new(start: Vector2, stop: Vector2, thicknessYScale: number, color: Color3, zIndex: number)
	return setmetatable({ 
		Start = start,
		Stop = stop,
		Color = color,
		ThicknessYScale = thicknessYScale,
		ZIndex = zIndex,
	}, Line)
end

function Line:Centre()
  return (self.Start + self.Stop)/2
end

function Line:Length()
	return (self.Stop - self.Start).Magnitude
end

function Line:RotationRadians()
  return math.atan2((self.Stop - self.Start).Y, (self.Stop-self.Start).X)
end

function Line:RotationDegrees()
  return math.deg(self:RotationRadians())
end

function Line:Update(start: Vector2, stop: Vector2, thicknessYScale: number, color: Color3, zIndex)
  self.Start= start
  self.Stop= stop
  self.ThicknessYScale = thicknessYScale
  self.Color = color
end

-- True iff the circle centred at <pos> with radius <radius> intersects this line
function Line:Intersects(pos: Vector2, radius: number)
	-- See diagram here:
	-- https://cdn.discordapp.com/attachments/916413265733636166/931115440409829376/image.png

	-- Vector from the start of the line to pos
	local u = pos - self.Start
	-- Vector from the start of the line to the end of the line
	local v = self.Stop - self.Start
	
	-- the magnitude (with sign) of the projection of u onto v
	local m = u:Dot(v.Unit)

	if m <= 0 or self.Start == self.Stop then
		-- The closest point on the line to pos is lineInfo.Start
		return u.Magnitude <= radius + self.ThicknessYScale/2
	elseif m >= v.Magnitude then
		-- The closest point on the line to pos is lineInfo.Stop
		return (pos - self.Stop).Magnitude <= radius + self.ThicknessYScale/2
	else
		-- The vector from pos to it's closest point on the line makes a perpendicular with the line
		return math.abs(u:Cross(v.Unit)) <= radius + self.ThicknessYScale/2
	end
end

return Line