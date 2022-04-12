local Line = require(script.Parent.Line)

local Curve = {}
Curve.__index = Curve

function Curve.new(thicknessYScale, color, zIndex)
	return setmetatable({
		Points = {},
		Color = color,
		ThicknessYScale = thicknessYScale,
		ZIndex = zIndex,
		_mask = {}
	}, Curve)
end

function Curve:Extend(point: Vector2)
  table.insert(self.Points, point)
	self._mask[#self.Points] = true
end

function Curve:LineBetween(start: Vector2, stop: Vector2)
  return Line.new(start, stop, self.ThicknessYScale, self.Color, self.ZIndex)
end

function Curve:DisconnectAt(lineStartIndex)
	self._mask[lineStartIndex] = false
end

function Curve:DisconnectAll()
	table.clear(self._mask)
end

function Curve:ConnectAt(lineStartIndex)
	self._mask[lineStartIndex] = true
end

function Curve:IsConnectedAt(lineStartIndex)
	return self._mask[lineStartIndex]
end

function Curve:SetMask(mask)
	self._mask = mask
end

function Curve:GetMask()
	return self._mask
end

function Curve:ShallowClone()
	local clone = Curve.new(
		self.ThicknessYScale,
		self.Color,
		self.ZIndex
	)
	clone.Points = self.Points
	clone._mask = self._mask
end

return Curve