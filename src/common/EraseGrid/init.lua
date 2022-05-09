-- Services
local Common = script.Parent

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)

--!strict

local ShapeGrid = require(script.ShapeGrid)
local Rasterize = require(script.Rasterize)

local EraseGrid = setmetatable({}, ShapeGrid)
EraseGrid.__index = EraseGrid

function EraseGrid.new(aspectRatio: number)
	return setmetatable(ShapeGrid.new(aspectRatio, 1, Config.DefaultEraseGridPixelSize), EraseGrid)
end

local function pairer(sep)
	return function (a, b)
		return a..sep..b
	end
end

local function unpairer(sep)
	return function(ab)
		return unpack(ab:split(sep))
	end
end

local pairTypeAndShape = pairer("$")
local unpairTypeAndShape = unpairer("$")

function EraseGrid:AddCurve(figureId: string, curve: Figure.Curve)
	local shapeId = function(p0Index)
		return pairer("#")(figureId, tostring(p0Index))
	end

	for i=1, #curve.Points-1 do
		if curve.Mask and curve.Mask[tostring(i)] then continue end

		self:AddShape(pairTypeAndShape("Curve", shapeId(i)), function(addPixel)
			Rasterize.Rectangle(curve.Points[i] / self.PixelSize, curve.Points[i+1] / self.PixelSize, curve.Width / self.PixelSize, addPixel)
			Rasterize.Circle(curve.Points[i] / self.PixelSize, curve.Width / self.PixelSize / 2, addPixel)
			Rasterize.Circle(curve.Points[i+1] / self.PixelSize, curve.Width / self.PixelSize / 2, addPixel)
		end)

	end
end

function EraseGrid:AddLine(figureId: string, line: Figure.Line)
	local shapeId = figureId

	self:AddShape(pairTypeAndShape("Line", shapeId), function(addPixel)
		Rasterize.Rectangle(line.P0 / self.PixelSize, line.P1 / self.PixelSize, line.Width / self.PixelSize, addPixel)
		Rasterize.Circle(line.P0 / self.PixelSize, line.Width / self.PixelSize / 2, addPixel)
		Rasterize.Circle(line.P1 / self.PixelSize, line.Width / self.PixelSize / 2, addPixel)
	end)
end

function EraseGrid:AddCircle(figureId: string, centre: Vector2, radius: number)
	local shapeId = figureId
	
	self:_insert(pairTypeAndShape("Circle", shapeId), function(addPixel)
		Rasterize.Circle(centre / self.PixelSize, radius / self.PixelSize, addPixel)
	end)
end

function EraseGrid:SubtractMask(figureId: string, figureType: string, mask: Figure.AnyMask)
	if figureType == "Curve" then
		for i in pairs(mask) do
			local shapeId = pairTypeAndShape("Curve", pairer("#")(figureId, tostring(i)))
			self:RemoveShape(shapeId)
		end
	
	else
		error("TODO")
	
	end
end

function EraseGrid:QueryCircle(centre: Vector2, radius: Vector2, callback: (string, string, Figure.AnyMask) -> boolean)
	local rasterizer = function(addPixel)
		Rasterize.Circle(centre / self.PixelSize, radius / self.PixelSize, addPixel)
	end

	local intersectedCallback = function(typedShapeId)
		
		local figureType, shapeId = unpairTypeAndShape(typedShapeId)

		if figureType == "Curve" then
			local figureId, index = unpairer("#")(shapeId)

			-- the return value of this callback decides whether to remove this shape from the grid
			local removeIt = callback(figureId, figureType, { [index] = true })

			if removeIt then
				self:RemoveShape(typedShapeId)
			end

		else
			error("TODO")
		end

	end

	self:Query(rasterizer, intersectedCallback)
end

return EraseGrid