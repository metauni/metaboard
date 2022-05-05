--!strict

--[[
	Functions for rasterizing shapes. Each function takes a callback as its last
	argument which gets called with the (x, y) coordinates of an added pixel.
	All positional arguments are Vector2s.

	Rasterize.Line(p0, p1, addPixel)

	Rasterize.Triangle(p0, p1, p2, addPixel)

	Rasterize.Circle(center, radius, addPixel)

	Rasterize.AARectangle(corner0, corner1, addPixel)
		Axis-aligned rectangle.

	Rasterize.Rectangle(p0, p1, width, addPixel)
		Defined like a line but with width.
]]

type AddPixelCallback = (x: number, y: number) -> ()

-- Helpers
local function getPointOnLine(p0: Vector2, p1: Vector2, x: number)
	if x < p0.X then
		return p0.Y
	elseif x > p1.X then
		return p1.Y
	else
		local m = (p1.Y - p0.Y) / (p1.X - p0.X)
		local b = -p0.X * m + p0.Y
		return m * x + b
	end
end

local function getRowsIntersectedByLine(p0: Vector2, p1: Vector2, x: number)
	local left = getPointOnLine(p0, p1, x)
	local right = getPointOnLine(p0, p1, x + 1)

	local min = math.floor(math.min(left, right))
	local max = math.ceil(math.max(left, right)) - 1

	return min, max
end

local function getPointOnCircle(x: number, radius: number)
	if x < -radius or x > radius then
		return 0
	else
		return math.sqrt(radius^2 - x^2)
	end
end

local function sortByXCoordinate(p0: Vector2, p1: Vector2, p2: Vector2)
	if p1.X < p0.X then
		if p2.X < p1.X then
			return p2, p1, p0
		elseif p2.X < p0.X then
			return p1, p2, p0
		else
			return p1, p0, p2
		end
	else
		if p2.X < p0.X then
			return p2, p0, p1
		elseif p2.X < p1.X then
			return p0, p2, p1
		else
			return p0, p1, p2
		end
	end
end

-- Rasterize
local Rasterize = {}

function Rasterize.Line(p0: Vector2, p1: Vector2, addPixel: AddPixelCallback)
	if p0.X == p1.X then
		if p0.Y == p1.Y then
			-- Degenerate case: Point
			addPixel(math.floor(p0.X), math.floor(p0.Y))
			return
		end

		-- Special case: Vertical line
		local x = math.floor(p0.X)
		local y0 = math.floor(math.min(p0.Y, p1.Y))
		local y1 = math.ceil(math.max(p0.Y, p1.Y)) - 1

		for y = y0, y1 do
			addPixel(x, y)
		end
		return
	elseif p0.Y == p1.Y then
		-- Special case: Horizontal line
		local y = math.floor(p0.Y)
		local x0 = math.floor(math.min(p0.X, p1.X))
		local x1 = math.ceil(math.max(p0.X, p1.X)) - 1

		for x = x0, x1 do
			addPixel(x, y)
		end
		return
	end

	-- Set p0 to have the lower X coordinate
	if p1.X < p0.X then
		local temp = p0
		p0 = p1
		p1 = temp
	end

	-- Iterate over every column that the line intersects
	local x0 = math.floor(p0.X)
	local x1 = math.ceil(p1.X) - 1

	for x = x0, x1 do
		-- Find the lowest and highest rows that the line intersects in this
		-- column
		local y0, y1 = getRowsIntersectedByLine(p0, p1, x)

		-- Draw the pixels
		for y = y0, y1 do
			addPixel(x, y)
		end
	end
end

function Rasterize.Curve(points, addPixel: AddPixelCallback)
	local prevPoint = points[1]
	for i = 2, #points do
		local point = points[i]
		Rasterize.Line(prevPoint, point, addPixel)
		prevPoint = point
	end
end

function Rasterize.Triangle(p0: Vector2, p1: Vector2, p2: Vector2, addPixel: AddPixelCallback)
	p0, p1, p2 = sortByXCoordinate(p0, p1, p2)

	if p0 == p1 then
		if p1 == p2 then
			-- Degenerate case: Points are the same
			addPixel(math.floor(p0.X), math.floor(p0.Y))
		else
			-- Degenerate case: Line
			Rasterize.Line(p0, p2, addPixel)
		end
		return
	elseif p1 == p2 then
		-- Degenerate case: Line
		Rasterize.Line(p0, p1, addPixel)
		return
	elseif p0.X == p1.X then
		-- Special case: Left line is vertical
		local x0 = math.floor(p0.X)
		local x1 = math.ceil(p2.X) - 1

		for x = x0, x1 do
			local min0, max0 = getRowsIntersectedByLine(p0, p2, x)
			local min1, max1 = getRowsIntersectedByLine(p1, p2, x)
			local y0 = math.min(min0, min1)
			local y1 = math.max(max0, max1)

			for y = y0, y1 do
				addPixel(x, y)
			end
		end
		return
	elseif p1.X == p2.X then
		-- Special case: Right line is vertical
		local x0 = math.floor(p0.X)
		local x1 = math.ceil(p2.X) - 1

		for x = x0, x1 do
			local min0, max0 = getRowsIntersectedByLine(p0, p2, x)
			local min1, max1 = getRowsIntersectedByLine(p0, p1, x)
			local y0 = math.min(min0, min1)
			local y1 = math.max(max0, max1)

			for y = y0, y1 do
				addPixel(x, y)
			end
		end
		return
	elseif (p1 - p0).Unit:Dot((p2 - p0).Unit) > 0.999 then
		-- Degenerate case: Points are colinear
		Rasterize.Line(p0, p2, addPixel)
		return
	end

	local x0 = math.floor(p0.X)
	local x1a = math.floor(p1.X) - 1
	local x1b = x1a + 1
	local x2 = math.ceil(p2.X) - 1

	-- Rasterize from the left point to the middle point
	for x = x0, x1a do
		local min0, max0 = getRowsIntersectedByLine(p0, p1, x)
		local min1, max1 = getRowsIntersectedByLine(p0, p2, x)
		local y0 = math.min(min0, min1)
		local y1 = math.max(max0, max1)

		for y = y0, y1 do
			addPixel(x, y)
		end
	end

	-- Rasterize from the middle point to the right point
	for x = x1b, x2 do
		local min0, max0 = getRowsIntersectedByLine(p1, p2, x)
		local min1, max1 = getRowsIntersectedByLine(p0, p2, x)
		local y0 = math.min(min0, min1)
		local y1 = math.max(max0, max1)

		for y = y0, y1 do
			addPixel(x, y)
		end
	end
end

function Rasterize.Circle(center: Vector2, radius: number, addPixel: AddPixelCallback)
	local centerX = center.X
	local centerY = center.Y

	local x0 = math.floor(centerX - radius)
	local x1 = math.ceil(centerX + radius) - 1

	for x = x0, x1 do
		local left = getPointOnCircle(x - centerX, radius)
		local right = getPointOnCircle(x + 1 - centerX, radius)
		local max = math.max(left, right)
		local y0 = math.floor(-max + centerY)
		local y1 = math.ceil(max + centerY) - 1

		for y = y0, y1 do
			addPixel(x, y)
		end
	end
end

-- Axis-aligned rectangle
function Rasterize.AARectangle(corner0: Vector2, corner1: Vector2, addPixel: AddPixelCallback)
	local x0 = math.floor(math.min(corner0.X, corner1.X))
	local x1 = math.ceil(math.max(corner0.X, corner1.X)) - 1
	local y0 = math.floor(math.min(corner0.Y, corner1.Y))
	local y1 = math.ceil(math.max(corner0.Y, corner1.Y)) - 1

	for x = x0, x1 do
		for y = y0, y1 do
			addPixel(x, y)
		end
	end
end

function Rasterize.Rectangle(p0: Vector2, p1: Vector2, width: number, addPixel: AddPixelCallback)
	if p0.X == p1.X or p0.Y == p1.Y then
		-- Special case: Axis-aligned rectangle
		Rasterize.AARectangle(
			p0 - Vector2.new(width / 2, 0),
			p1 + Vector2.new(width / 2, 0),
			addPixel
		)
		return
	end

	local vec = (p1 - p0).Unit
	local perp = Vector2.new(-vec.Y, vec.X) * width / 2

	local corner0 = p0 + perp
	local corner1 = p0 - perp
	local corner2 = p1 - perp
	local corner3 = p1 + perp

	Rasterize.Triangle(corner0, corner1, corner2, addPixel)
	Rasterize.Triangle(corner0, corner2, corner3, addPixel)
end

function Rasterize.LineStroke(p0: Vector2, p1: Vector2, width: number, addPixel: AddPixelCallback)
	if p0 == p1 then
		Rasterize.Circle(p0, width/2, addPixel)
		return
	end

	Rasterize.Rectangle(p0, p1, width, addPixel)
	Rasterize.Circle(p0, width/2, addPixel)
	Rasterize.Circle(p1, width/2, addPixel)
end

return Rasterize