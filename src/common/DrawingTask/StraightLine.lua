-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent)
local Line = require(Common.Line)

-- StraightLine
local StraightLine = setmetatable({}, AbstractDrawingTask)
StraightLine.__index = StraightLine

function StraightLine.new(taskId: string, color: Color3, thicknessYScale: number, zIndex: number)
  local self = setmetatable(AbstractDrawingTask.new(taskId), StraightLine)

  self.Color = color
  self.ThicknessYScale = thicknessYScale
  self.ZIndex = zIndex
  
  return self
end

function StraightLine:Init(board, pos: Vector2)
  self.Line = Line.new(pos, pos, self.ThicknessYScale, self.Color)

  if board.Canvas then
    local canvasCurve = board.Canvas:MakeCurve(self.TaskId)
    local canvasLine = board.Canvas:MakeLine("1", self.ZIndex)
    board.Canvas:AttachLine(canvasLine, canvasCurve)
    board.Canvas:AttachCurve(canvasCurve)
  end
end

function StraightLine:Update(board, pos: Vector2)
  self.Line = Line:Update(self.Line.Start, pos, self.ThicknessYScale, self.Color)
  
  if board.Canvas then
    local canvasCurve = board.Canvas:GetCurve(self.TaskId)
    local canvasLine = board.Canvas:GetLine(canvasCurve, "1")
    board.Canvas:UpdateLine(canvasLine, self.Line)
  end
end

function StraightLine:Finish(board, pos: Vector2)
  -- TODO: divide into line segments
end

function StraightLine:Render(board)
  -- TODO
end

function StraightLine:Undo(board)
  self._cache = board.Canvas:DetachCurve(self.TaskId)
end

function StraightLine:Redo(board)
  if self._cache then
    board.Canvas:AttachCurve(self._cache)
  else
    self:Render(board, board.Canvas)
  end
end

function StraightLine:Commit(board)
  self._cache:Destroy()
end



return StraightLine
