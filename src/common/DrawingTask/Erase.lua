-- Services
local Common = script.Parent.Parent

-- Imports
local Config = require(Common.Config)
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary
local Figure = require(Common.Figure)

-- Erase Module
local Erase = setmetatable({IsErase = true}, AbstractDrawingTask)
Erase.__index = Erase

function Erase.newUnverified(taskId: string, thicknessYScale: number)
	local self = setmetatable(AbstractDrawingTask.new(script.Name, taskId, false), Erase)

	self.ThicknessYScale = thicknessYScale
	self.FigureIdToMask = {}

	return self
end

function Erase:Render()
	return self.FigureIdToMask
end

function Erase:EraseTouched(board, canvasPos: Vector2)

	local changedMasks = {}

	board.EraseGrid:QueryCircle(canvasPos, self.ThicknessYScale/2, function(figureId: string, figureType: string, maybeTouchedMask: Figure.AnyMask)

		local figure = board.DrawingTasks[figureId] and board.DrawingTasks[figureId]:Render() or board.Figures[figureId]

		local doesActuallyIntersect = Figure.IntersectsCircle(canvasPos, self.ThicknessYScale/2, figureType, figure, maybeTouchedMask)

		if not doesActuallyIntersect then
			return false
		end

		local oldMask = changedMasks[figureId] or self.FigureIdToMask[figureId]
		if oldMask == nil then
			changedMasks[figureId] = maybeTouchedMask
		else
			changedMasks[figureId] = Figure.MergeMask(figureType, oldMask, maybeTouchedMask)
		end

		-- The return value of this function decides whether the touched part of this figure should be removed from the erase grid.
		-- We only want to remove it if this is a verified drawing task.
		return self.Verified

	end)

	if next(changedMasks) then

		self.FigureIdToMask = Dictionary.merge(self.FigureIdToMask, changedMasks)

	end
end

function Erase:Init(board, canvasPos: Vector2)
	self:EraseTouched(board, canvasPos)
end

function Erase:Update(board, canvasPos: Vector2)
	self:EraseTouched(board, canvasPos)
end

function Erase:Finish(board)

end

function Erase:Commit(figures)
	local updatedFigures = {}

	for figureId, figure in pairs(figures) do
		local mask = self.FigureIdToMask[figureId]

		updatedFigures[figureId] = Dictionary.merge(figure, {
			Mask = Figure.MergeMask(figure.Type, figure.Mask, mask)
		})
	end

	return Dictionary.merge(figures, updatedFigures)
end

return Erase
