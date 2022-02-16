-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Line = require(Common.Line)

-- FreeHand
local FreeHand = setmetatable({}, AbstractDrawingTask)
FreeHand.__index = FreeHand

function FreeHand.new(taskId: string, color: Color3, thicknessYScale: number, zIndex: number)
  local self = setmetatable(AbstractDrawingTask.new(taskId), FreeHand)

  self.Color = color
  self.ThicknessYScale = thicknessYScale
  self.ZIndex = zIndex

  return self
end

function FreeHand:Init(board, pos: Vector2)
  self.Lines = {}
  table.insert(self.Lines, Line.new(pos, pos, self.ThicknessYScale, self.Color, self.ZIndex))
  self.FirstUpdate = true

  if board.Canvas then
    board.Canvas:AddCurve(self.TaskId)
    board.Canvas:AddLine(self.Lines[1], "1", self.TaskId)
  end
end

function FreeHand:Update(board, pos: Vector2)
  local lastLine = self.Lines[#self.Lines]
  local curveStop = lastLine.Stop

  if self.FirstUpdate then
    lastLine = lastLine:Update(lastLine.Start, pos, self.ThicknessYScale, self.Color, self.ZIndex)

    if board.Canvas then
      board.Canvas:UpdateLine(lastLine, "1", self.TaskId)
    end

  else
    local nextLine = Line.new(curveStop, pos, self.ThicknessYScale, self.Color, self.ZIndex)
    table.insert(self.Lines, nextLine)

    if board.Canvas then
      board.Canvas:AddLine(nextLine, #self.Lines, self.TaskId)
    end
  end

  self.FirstUpdate = nil
end

function FreeHand:Finish(board, pos: Vector2)
  -- Nothing I guess, unless for smoothing?
end

function FreeHand:Render(board)
  -- TODO
end

function FreeHand:Undo(board)
  self._cache = board.Canvas:DetachCurve(self.TaskId)
end

function FreeHand:Redo(board)
  if self._cache then
    board.Canvas:AttachCurve(self._cache)
  else
    self:Render(board, board.Canvas)
  end
end

function FreeHand:Commit(board, canvas)
  self._cache:Destroy()
end

return FreeHand
