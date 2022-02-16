-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)

-- Erase Module
local Erase = setmetatable({}, AbstractDrawingTask)
Erase.__index = Erase

function Erase.new(taskId, thicknessYScale)
  return setmetatable({
    TaskId = taskId,
    ThicknessYScale = thicknessYScale,
  }, Erase)
end

function Erase:EraseAt(board, pos: Vector2)
  for player, taskId, lineId in board.Grid:IterIntersects(pos, self.ThicknessYScale/2) do
    local drawingTask = board.History[player]:Lookup(taskId)
    drawingTask:Erase(lineId)
  end
end

function Erase:Init(board, pos: Vector2)
  self:EraseAt(board, pos)
end

function Erase:Update(board, pos: Vector2)
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
