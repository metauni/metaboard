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

local Rasterize = require(script.Rasterize)
local GridSet = require(script.GridSet)

local EraseGrid = {}
EraseGrid.__index = EraseGrid

function EraseGrid.new(width: number, height: number, pixelSize: number?)
	pixelSize = pixelSize or 1

	local gridWidth = math.ceil(width / pixelSize :: number)
	local gridHeight = math.ceil(height / pixelSize :: number)
	
	return setmetatable({
		Width = gridWidth,
		Height = gridHeight,
		PixelSize = pixelSize,
		PixelsToLines = GridSet(gridWidth, gridHeight),
		LinesToPixels = {},
	}, EraseGrid)
end

function EraseGrid:_addLineToPixel(line: Line, x: number, y: number)
	self.PixelsToLines.Add(x, y, line)
end

function EraseGrid:_addPixelToLine(x: number, y: number, line: Line)
	local tbl = self.LinesToPixels[line]
	
	if not tbl then
		tbl = {}
		self.LinesToPixels[line] = tbl
	end
	
	tbl[Vector3.new(x, y, 0)] = true -- TODO: Don't do this
end

function EraseGrid:AddLine(line: Line)
	local p0 = line.P0 / self.PixelSize
	local p1 = line.P1 / self.PixelSize
	local width = line.Width / self.PixelSize
	
	local function addPixel(x: number, y: number)
		if x < 0 or x > self.Width - 1 or y < 0 or y > self.Width - 1 then
			return
		end
		
		self:_addLineToPixel(line, x, y)
		self:_addPixelToLine(x, y, line)
	end
	
	Rasterize.Rectangle(p0, p1, width, addPixel)
end

function EraseGrid:RemoveLine(line: Line)
	local pixelsToLines = self.PixelsToLines
	
	if self.LinesToPixels[line] then
		for pixel in pairs(self.LinesToPixels[line]) do
			pixelsToLines.Remove(pixel.X, pixel.Y, line)
		end
		
		self.LinesToPixels[line] = nil
	end
end

function EraseGrid:QueryLines(center: Vector2, radius: number)
	local pixelsToLines = self.PixelsToLines
	local linesSet = {}
	local linesArray = {}
	
	local function addPixel(x, y)
		local set = pixelsToLines.Get(x, y)
		if set then
			for line in pairs(set) do
				if not linesSet[line] then
					linesSet[line] = true
					table.insert(linesArray, line)
				end
			end
		end
	end

	Rasterize.Circle(center / self.PixelSize, radius / self.PixelSize, addPixel)
	
	return linesArray
end

return EraseGrid