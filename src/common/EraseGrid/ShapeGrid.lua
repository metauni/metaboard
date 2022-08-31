-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

--[[
	A canvas that allows for adding and removing lines and querying lines near a
	given circle.
	
	EraseGrid.new(width, height, pixelSize)
		Width and height are measured in real pixels of the user's screen.
		PixelSize is the width and height of a EraseGrid pixel measured in screen
		pixels. Ex. PixelSize = 10 gives EraseGrid pixels that are 10x10 screen
		pixels.
	
	EraseGrid:AddLine(line)
	
	EraseGrid:RemoveLine(line)
	
	EraseGrid:QueryLines(center, radius)
]]

--!strict

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)

local Rasterize = require(script.Parent.Rasterize)
local GridSet = require(script.Parent.GridSet)

local ShapeGrid = {}
ShapeGrid.__index = ShapeGrid

function ShapeGrid.new(width: number, height: number, pixelSize: number?)
	pixelSize = pixelSize or 1

	local gridWidth = math.ceil(width / pixelSize :: number)
	local gridHeight = math.ceil(height / pixelSize :: number)
	
	return setmetatable({
		Width = gridWidth,
		Height = gridHeight,
		PixelSize = pixelSize,
		PixelsToShapeIds = GridSet(gridWidth, gridHeight),
		ShapeIdsToPixels = {},
	}, ShapeGrid)
end

function ShapeGrid:_pair(x,y)
	return x + 1 + y * self.Width
end

function ShapeGrid:_unpair(p)
	return math.fmod(p-1, self.Width), math.floor((p-1) / self.Width)
end

function ShapeGrid:_addShapeIdToPixel(shapeId: string, x: number, y: number)
	self.PixelsToShapeIds.Add(x, y, shapeId)
end

function ShapeGrid:_addPixelToShapeId(x: number, y: number, shapeId: string)
	local tbl = self.ShapeIdsToPixels[shapeId]

	if not tbl then
		tbl = {}
		self.ShapeIdsToPixels[shapeId] = tbl
	end
	
	tbl[self:_pair(x,y)] = true
end

function ShapeGrid:AddShape(shapeId: string, rasterizer)
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addShapeIdToPixel(shapeId, x, y)
		self:_addPixelToShapeId(x, y, shapeId)
	end

	rasterizer(addPixel)
end

function ShapeGrid:AddLine(start: Vector2, stop: Vector2, thickness: number, shapeId: string)
	local p0 = start / self.PixelSize
	local p1 = stop / self.PixelSize
	local width = thickness / self.PixelSize
	
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addShapeIdToPixel(shapeId, x, y)
		self:_addPixelToShapeId(x, y, shapeId)
	end
	
	Rasterize.LineStroke(p0, p1, width, addPixel)
end

function ShapeGrid:AddCircle(centre: Vector2, radius: number, shapeId: string)
	local c = centre / self.PixelSize
	local r = radius / self.PixelSize
	
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addShapeIdToPixel(shapeId, x, y)
		self:_addPixelToShapeId(x, y, shapeId)
	end
	
	Rasterize.Circle(c, r, addPixel)
end

function ShapeGrid:RemoveShape(shapeId: string)
	local pixelsToShapeIds = self.PixelsToShapeIds
	
	if self.ShapeIdsToPixels[shapeId] then
		for p in pairs(self.ShapeIdsToPixels[shapeId]) do
			local x, y = self:_unpair(p)
			pixelsToShapeIds.Remove(x, y, shapeId)
		end
		
		self.ShapeIdsToPixels[shapeId] = nil
	end
end

function ShapeGrid:Query(rasterizer, intersectedCallback)
	local pixelsToShapeIds = self.PixelsToShapeIds
	local shapeIdsSet = {}
	
	local function addPixel(x, y)
		local set = pixelsToShapeIds.Get(x, y)
		if set then
			for shapeId in pairs(set) do
				if not shapeIdsSet[shapeId] then
					shapeIdsSet[shapeId] = true
					intersectedCallback(shapeId)
				end
			end
		end
	end

	rasterizer(addPixel)
end

return ShapeGrid