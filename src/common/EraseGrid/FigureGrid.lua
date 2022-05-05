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
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)

local Rasterize = require(script.Parent.Rasterize)
local GridSet = require(script.Parent.GridSet)

local FigureGrid = {}
FigureGrid.__index = FigureGrid

function FigureGrid.new(width: number, height: number, pixelSize: number?)
	pixelSize = pixelSize or 1

	local gridWidth = math.ceil(width / pixelSize :: number)
	local gridHeight = math.ceil(height / pixelSize :: number)
	
	return setmetatable({
		Width = gridWidth,
		Height = gridHeight,
		PixelSize = pixelSize,
		PixelsToFigureIds = GridSet(gridWidth, gridHeight),
		FigureIdsToPixels = {},
	}, FigureGrid)
end

function FigureGrid:_pair(x,y)
	return x + 1 + y * self.Width
end

function FigureGrid:_unpair(p)
	return math.fmod(p-1, self.Width), math.floor((p-1) / self.Width)
end

function FigureGrid:_addFigureIdToPixel(figureId: string, x: number, y: number)
	self.PixelsToFigureIds.Add(x, y, figureId)
end

function FigureGrid:_addPixelToFigureId(x: number, y: number, figureId: string)
	local tbl = self.FigureIdsToPixels[figureId]

	if not tbl then
		tbl = {}
		self.FigureIdsToPixels[figureId] = tbl
	end
	
	tbl[self:_pair(x,y)] = true
end

function FigureGrid:AddFigure(figureId: string, rasterizer)
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addFigureIdToPixel(figureId, x, y)
		self:_addPixelToFigureId(x, y, figureId)
	end

	rasterizer(addPixel)
end

function FigureGrid:AddLine(start: Vector2, stop: Vector2, thickness: number, figureId: string)
	local p0 = start / self.PixelSize
	local p1 = stop / self.PixelSize
	local width = thickness / self.PixelSize
	
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addFigureIdToPixel(figureId, x, y)
		self:_addPixelToFigureId(x, y, figureId)
	end
	
	Rasterize.LineStroke(p0, p1, width, addPixel)
end

function FigureGrid:AddCircle(centre: Vector2, radius: number, figureId: string)
	local c = centre / self.PixelSize
	local r = radius / self.PixelSize
	
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addFigureIdToPixel(figureId, x, y)
		self:_addPixelToFigureId(x, y, figureId)
	end
	
	Rasterize.Circle(c, r, addPixel)
end

function FigureGrid:RemoveFigure(figureId: string)
	local pixelsToFigureIds = self.PixelsToFigureIds
	
	if self.FigureIdsToPixels[figureId] then
		for p in pairs(self.FigureIdsToPixels[figureId]) do
			local x, y = self:_unpair(p)
			pixelsToFigureIds.Remove(x, y, figureId)
		end
		
		self.FigureIdsToPixels[figureId] = nil
	end
end

function FigureGrid:Query(rasterizer, intersectedCallback)
	local pixelsToFigureIds = self.PixelsToFigureIds
	local figureIdsSet = {}
	
	local function addPixel(x, y)
		local set = pixelsToFigureIds.Get(x, y)
		if set then
			for figureId in pairs(set) do
				if not figureIdsSet[figureId] then
					figureIdsSet[figureId] = true
					intersectedCallback(figureId)
				end
			end
		end
	end

	rasterizer(addPixel)
end

return FigureGrid