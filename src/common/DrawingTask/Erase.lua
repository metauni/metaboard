-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)

-- Erase Module
local Erase = setmetatable({IsErase = true}, AbstractDrawingTask)
Erase.__index = Erase

function Erase.new(board, taskId: string, provisional: boolean, width: number)
	local self = setmetatable(AbstractDrawingTask.new(taskId, provisional), Erase)

	self.TaskType = "Erase"
	self.Width = width

	return self
end

function Erase.AssignMetatables(drawingTask)
	setmetatable(drawingTask, Erase)
end

function Erase:EraseAt(board, pos: Vector2, canvas)

	local callback = function(taskAndFigureId: string)
		local taskId, figureId = unpack(taskAndFigureId:split("#"))
		local drawingTask = board.DrawingTasks[taskId]
		
		local doesIntersect = drawingTask:CheckIntersection(board, figureId, pos, self.Width/2)
		if not doesIntersect then return end

		if self.Provisional then
			drawingTask:ShowFigure(board, figureId, canvas)
		else
			drawingTask:EraseFigure(board, figureId, canvas)
			board.EraseGrid:RemoveFigure(taskAndFigureId)
		end
	end

	board.EraseGrid:QueryIntersected(pos, self.Width/2, callback)
end

function Erase:Init(board, pos: Vector2, canvas)
	self:EraseAt(board, pos, canvas)
end

function Erase:Update(board, pos: Vector2, canvas)
	self:EraseAt(board, pos, canvas)
end

function Erase:Finish(pos, board, canvas)

end

function Erase:Hide(board, canvas)
	-- if canvas then
	-- 	canvas:DeleteGroup(self.TaskId)
	-- end
end

function Erase:Undo(board, canvas)
	-- TODO
end

function Erase:Redo(board, canvas)
	-- TODO
end

function Erase:Commit(board, canvas)
	-- TODO
end

return Erase
