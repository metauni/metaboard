-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Curve = require(Common.Figure.Curve)

-- StraightLine
local StraightLine = setmetatable({}, AbstractDrawingTask)
StraightLine.__index = StraightLine

function StraightLine.new(board, taskId: string, provisional: boolean, color: Color3, thicknessYScale: number)
  local self = setmetatable(AbstractDrawingTask.new(taskId, provisional), StraightLine)

  self.TaskType = "StraightLine"
  self.Color = color
  self.ThicknessYScale = thicknessYScale

  return self
end

function StraightLine.AssignMetatables(drawingTask)
  setmetatable(drawingTask, StraightLine)
  if drawingTask.Curve then
    setmetatable(drawingTask.Curve, Curve)
  end
end

function StraightLine:Init(board, pos: Vector2, canvas)
  if self.Provisional then
    self.ZIndex = board:PeekZIndex()
  else
    self.ZIndex = board:NextZIndex()
  end

  self.Curve = Curve.new(self.ThicknessYScale, self.Color, self.ZIndex)
  
  if canvas then
    canvas:NewCurve(self.TaskId)
    canvas:UpdateCurvePoint(self.TaskId, nil, self.Curve, 1, pos)
  end
  
  self.Curve:Extend(pos)
end

function StraightLine:Update(board, pos: Vector2, canvas)
  
  if canvas then
    canvas:UpdateCurvePoint(self.TaskId, nil, self.Curve, 2, pos)
  end

  self.Curve.Points[2] = pos
end

function StraightLine:Finish(board, canvas)
  -- TODO: divide into line segments
end

function StraightLine:Undo(board, canvas)
  if canvas then
    canvas:DeleteCurve(self.TaskId, nil)
  end
end

function StraightLine:Redo(board, canvas)
  if canvas then
    canvas:WriteCurve(self.TaskId, nil, self.Curve)
  end
end

function StraightLine:Commit(board, canvas)

end

return StraightLine
