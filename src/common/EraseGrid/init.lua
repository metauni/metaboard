-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = script.Parent

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)

--!strict

local ShapeGrid = require(script.ShapeGrid)
local Rasterize = require(script.Rasterize)

local EraseGrid = {}
EraseGrid.__index = EraseGrid

function EraseGrid.new(aspectRatio: number)
	return setmetatable({
		ShapeGrid = ShapeGrid.new(aspectRatio, 1, Config.Canvas.DefaultEraseGridPixelSize),
		Figures = {},
		FigureIdToShapeIds = {},
	}, EraseGrid)
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

function EraseGrid:AddFigure(figureId: string, figure: Figure.AnyFigure)
	EraseGrid["Add"..figure.Type](self, figureId, figure)
end

function EraseGrid:SubtractMask(figureId: string, mask: Figure.AnyMask)

	local figure = self.Figures[figureId]

	if figure.Type == "Curve" then
		for i in pairs(mask) do
			local shapeId = pairer("#")(figureId, tostring(i))
			self.ShapeGrid:RemoveShape(pairTypeAndShape("Curve", shapeId))
			self.FigureIdToShapeIds[figureId][shapeId] = nil
		end

	else
		assert(figure.Type == "Line")

		local shapeId = figureId
		self.ShapeGrid:RemoveShape(pairTypeAndShape("Line", shapeId))
		self.FigureIdToShapeIds[figureId][shapeId] = nil

	end
end

function EraseGrid:AddCurve(figureId: string, curve: Figure.Curve)

	self.Figures[figureId] = curve

	local shapeId = function(p0Index)
		return pairer("#")(figureId, tostring(p0Index))
	end

	self.FigureIdToShapeIds[figureId] = self.FigureIdToShapeIds[figureId] or {}

	for i=1, #curve.Points-1 do
		if curve.Mask and curve.Mask[tostring(i)] then continue end

		local typedShapeId = pairTypeAndShape("Curve", shapeId(i))

		self.ShapeGrid:AddShape(typedShapeId, function(addPixel)
			Rasterize.Rectangle(curve.Points[i] / self.ShapeGrid.PixelSize, curve.Points[i+1] / self.ShapeGrid.PixelSize, curve.Width / self.ShapeGrid.PixelSize, addPixel)
			Rasterize.Circle(curve.Points[i] / self.ShapeGrid.PixelSize, curve.Width / self.ShapeGrid.PixelSize / 2, addPixel)
			Rasterize.Circle(curve.Points[i+1] / self.ShapeGrid.PixelSize, curve.Width / self.ShapeGrid.PixelSize / 2, addPixel)
		end)

		self.FigureIdToShapeIds[figureId][shapeId(i)] = true

	end
end

function EraseGrid:AddLine(figureId: string, line: Figure.Line)

	self.Figures[figureId] = line

	local shapeId = figureId

	self.FigureIdToShapeIds[figureId] = { [shapeId] = true }

	self.ShapeGrid:AddShape(pairTypeAndShape("Line", shapeId), function(addPixel)
		Rasterize.Rectangle(line.P0 / self.ShapeGrid.PixelSize, line.P1 / self.ShapeGrid.PixelSize, line.Width / self.ShapeGrid.PixelSize, addPixel)
		Rasterize.Circle(line.P0 / self.ShapeGrid.PixelSize, line.Width / self.ShapeGrid.PixelSize / 2, addPixel)
		Rasterize.Circle(line.P1 / self.ShapeGrid.PixelSize, line.Width / self.ShapeGrid.PixelSize / 2, addPixel)
	end)
end

function EraseGrid:RemoveFigure(figureId: string, figure: Figure.AnyFigure)
	for shapeId in pairs(self.FigureIdToShapeIds[figureId] or {}) do
		self.ShapeGrid:RemoveShape(pairTypeAndShape(figure.Type, shapeId))
	end

	self.Figures[figureId] = nil
end

function EraseGrid:QueryCircle(centre: Vector2, radius: Vector2, callback: (string, string, Figure.AnyMask) -> boolean)
	local rasterizer = function(addPixel)
		Rasterize.Circle(centre / self.ShapeGrid.PixelSize, radius / self.ShapeGrid.PixelSize, addPixel)
	end

	local intersectedCallback = function(typedShapeId)

		local figureType, shapeId = unpairTypeAndShape(typedShapeId)

		if figureType == "Curve" then
			local figureId, index = unpairer("#")(shapeId)

			-- the return value of this callback decides whether to remove this shape from the grid
			local removeIt = callback(figureId, figureType, { [index] = true })

			if removeIt then
				self.ShapeGrid:RemoveShape(typedShapeId)
				self.FigureIdToShapeIds[figureId][shapeId] = nil
			end

		else
			assert(figureType == "Line")

			local figureId = shapeId

			local removeIt = callback(figureId, figureType, true)

			if removeIt then
				self.ShapeGrid:RemoveShape(typedShapeId)
				self.FigureIdToShapeIds[figureId][shapeId] = nil
			end

		end

	end

	self.ShapeGrid:Query(rasterizer, intersectedCallback)
end

return EraseGrid