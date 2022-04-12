-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)

-- Erase Module
local Erase = setmetatable({}, AbstractDrawingTask)
Erase.__index = Erase

function Erase.new(board, taskId: string, provisional: boolean, thicknessYScale: number)
  local self = setmetatable(AbstractDrawingTask.new(taskId, provisional), Erase)

  self.TaskType = "Erase"
  self.ThicknessYScale = thicknessYScale

  return self
end

function Erase:RenewVerified(board)
  self.Provisional = false
end

function Erase:EraseAt(board, pos: Vector2, canvas)

  for taskId, figureIds in board.Grid:IterIntersects(pos, self.ThicknessYScale/2) do
    local drawingTask = board.DrawingTasks[taskId]
    drawingTask:EraseFigures(figureIds, pos, false)
  end
  
end

function Erase:RenderGhostsAt(board, pos: Vector2, canvas)
  for taskId, intersectedIds in board.Grid:IterIntersects(pos, self.ThicknessYScale/2) do
    local drawingTask = board.DrawingTasks[taskId]
    drawingTask:RenderGhost(board, self.TaskId, intersectedIds, canvas)
  end
end

function Erase:Init(board, pos: Vector2, canvas)
  if self.Provisional then
    self:RenderGhostsAt(board, pos)
  else
    self:EraseAt(board, pos)
  end
end

function Erase:Update(board, pos: Vector2, canvas)
  self:EraseAt(board, pos)
end

function Erase:Finish(pos, board, canvas)

end

function Erase:Render(board, canvas)
  -- TODO
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
