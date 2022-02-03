-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent)
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
  table.insert(self.Lines, Line.new(pos, pos, self.ThicknessYScale, self.Color))
  self.FirstUpdate = true

  if board.Canvas then
    local canvasCurve = board.Canvas:MakeCurve(self.TaskId)
    local canvasLine = board.Canvas:MakeLine("1", self.ZIndex)
    board.Canvas:AttachLine(canvasLine, canvasCurve)
    board.Canvas:AttachCurve(canvasCurve)
  end
end

function FreeHand:Update(board, pos: Vector2)
  local lastLine = self.Lines[#self.Lines]
  local curveStop = lastLine.Stop

  if self.FirstUpdate then
    lastLine = Line:Update(lastLine.Start, pos, self.ThicknessYScale, self.Color)
  else
    local nextLine = Line.new(curveStop, pos, self.ThicknessYScale, self.Color)
    table.insert(self.Lines, nextLine)
    lastLine = nextLine
  end

  if board.Canvas then
    local canvasCurve = board.Canvas:GetCurve(self.TaskId)
    local canvasLine
    if self.FirstUpdate then
      canvasLine = board.Canvas:GetLine(canvasCurve, "1")
      board.Canvas:UpdateLine(canvasLine, lastLine)
    else
      canvasLine = board.Canvas:MakeLine(canvasCurve, tostring(#self.Lines + 1))
      board.Canvas:AttachLine(canvasLine, canvasCurve)
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
