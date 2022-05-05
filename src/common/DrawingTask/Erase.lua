-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

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
	self.TaskIdToFigureIds = {}
	self.TaskIdToFigureMask = {}

	return self
end

function Erase:Render()
	return self.TaskIdToFigureMask
end

function Erase:EraseTouched(board, canvasPos: Vector2)

	local taskIdNewlyTouched = {}

	board.EraseGrid:QueryCircle(canvasPos, self.ThicknessYScale/2, function(taskId: string, figureId: string)

		local drawingTask = board.DrawingTasks[taskId]

		if not drawingTask:CheckCollision(canvasPos, self.ThicknessYScale, figureId) then return end

		local figureIds = self.TaskIdToFigureIds[taskId] or {}

		-- Make sure we haven't yet erased this figure
		if figureIds[figureId] == nil then
			taskIdNewlyTouched[taskId] = true
			figureIds[figureId] = true
			self.TaskIdToFigureIds[taskId] = figureIds
		end

	end)

	for taskId in pairs(taskIdNewlyTouched) do

		local drawingTask = board.DrawingTasks[taskId]
		
		self.TaskIdToFigureMask = Dictionary.merge(self.TaskIdToFigureMask, {

			[taskId] = drawingTask:RenderFigureMask(self.TaskIdToFigureIds[taskId])

		})

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
	for figureId, figure in pairs(figures) do
		local mask = self.TaskIdToFigureMask[figureId]

		figures[figureId] = Dictionary.merge(figure, {
			Mask = Figure.MergeMask(figure.Type, figure.Mask, mask)
		})
	end
end

return Erase
