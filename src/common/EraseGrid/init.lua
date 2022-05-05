-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)


--!strict

local FigureGrid = require(script.FigureGrid)
local Rasterize = require(script.Rasterize)

local EraseGrid = setmetatable({}, FigureGrid)
EraseGrid.__index = EraseGrid

function EraseGrid.new(aspectRatio: number)
	return setmetatable(FigureGrid.new(aspectRatio, 1, Config.DefaultEraseGridPixelSize), EraseGrid)
end

local function pairTaskAndFigureId(groupId: string, figureId: string)
	return groupId.."#"..figureId
end

local function unpairTaskAndFigureId(taskAndFigureId: string)
	return unpack(taskAndFigureId:split("#"))
end

function EraseGrid:_insert(taskId: string, figureId: string, rasterizer)
	self:AddFigure(pairTaskAndFigureId(taskId, figureId), rasterizer)
end

function EraseGrid:AddLine(taskId: string, figureId: string, p0: Vector2, p1: Vector2, thickness: number)
	self:_insert(taskId, figureId, function(addPixel)
		Rasterize.Rectangle(p0 / self.PixelSize, p1 / self.PixelSize, thickness / self.PixelSize, addPixel)
		Rasterize.Circle(p0 / self.PixelSize, thickness / self.PixelSize / 2, addPixel)
		Rasterize.Circle(p1 / self.PixelSize, thickness / self.PixelSize / 2, addPixel)
	end)
end

function EraseGrid:AddCircle(taskId: string, figureId: string, centre: Vector2, radius: number)
	self:_insert(taskId, figureId, function(addPixel)
		Rasterize.Circle(centre / self.PixelSize, radius / self.PixelSize, addPixel)
	end)
end

function EraseGrid:Remove(taskId: string, figureId: string)
	self:RemoveFigure(pairTaskAndFigureId(taskId, figureId))
end

function EraseGrid:QueryCircle(centre: Vector2, radius: Vector2, callback: (string, string) -> ())
	local rasterizer = function(addPixel)
		Rasterize.Circle(centre / self.PixelSize, radius / self.PixelSize, addPixel)
	end

	local intersectedCallback = function(taskAndFigureId)
		callback(unpairTaskAndFigureId(taskAndFigureId))
	end

	self:Query(rasterizer, intersectedCallback)
end

return EraseGrid