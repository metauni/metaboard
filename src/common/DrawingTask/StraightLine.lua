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

  self.InitialPoint = pos
  self.InitialPointVisible = true

  if canvas and self.Provisional then
    canvas:WriteCircle(self.TaskId, "InitialPoint", pos, self.ThicknessYScale, self.Color, self.ZIndex)
  end
end

function StraightLine:Update(board, pos: Vector2, canvas)
  if not self.Curve then
    self.Curve = Curve.new(self.ThicknessYScale, self.Color, self.ZIndex)
    self.Curve:Extend(self.InitialPoint)
    self.Curve:Extend(pos)

    if canvas and self.Provisional then
      canvas:DeleteFigure(self.TaskId, "InitialPoint")

      canvas:WriteCurve(self.TaskId, "Curve", self.Curve)
    end
  else
    if canvas and self.Provisional then
      canvas:UpdateCurvePoint(self.TaskId, "Curve", self.Curve, 2, pos)
    end

    self.Curve.Points[2] = pos
  end
end

function StraightLine:Finish(board, canvas)
  if canvas and not self.Provisional then
    self:Show(board, canvas)
  end

  if self.Curve then
    for i=1, #self.Curve.Points-1 do
      local start = self.Curve.Points[i]
      local stop = self.Curve.Points[i+1]

      board.EraseGrid:AddLine(start, stop, self.ThicknessYScale, self.TaskId.."#"..tostring(i))
    end
  else
    board.EraseGrid:AddCircle(self.InitialPoint, self.ThicknessYScale/2, self.TaskId.."#".."InitialPoint")
  end
end

function StraightLine:Show(board, canvas)
  if canvas then
    if self.Curve then
      canvas:WriteCurve(self.TaskId, "Curve", self.Curve)
    else
      if self.InitialPointVisible then
        canvas:WriteCircle(self.TaskId, "InitialPoint", self.InitialPoint, self.ThicknessYScale, self.Color, self.ZIndex)
      end
    end
  end
end

function StraightLine:Hide(board, canvas)
  if canvas then
    canvas:DeleteGroup(self.TaskId)
  end
end


function StraightLine:Undo(board, canvas)
  if canvas then
    self:Hide(board, canvas)
  end
  self.Undone = true
end

function StraightLine:Redo(board, canvas)
  if canvas then
    self:Show(board, canvas)
  end
  self.Undone = false
end

function StraightLine:Commit(board, canvas)

end

function StraightLine:ShowFigure(board, figureId, canvas)
  if canvas then

    if figureId == "InitialPoint" then
      canvas:WriteCircle(self.TaskId, "InitialPoint", self.InitialPoint, self.ThicknessYScale, self.Color, self.ZIndex)
    else
      local lineStartIndex = tonumber(figureId)

      canvas:ShowLineInCurve(self.TaskId, "Curve", self.Curve, lineStartIndex)
    end
  end
end

function StraightLine:EraseFigure(board, figureId, canvas)
  if figureId == "InitialPoint" then
    self.InitialPointVisible = false

    if canvas then
      canvas:DeleteFigure(self.TaskId, "InitialPoint")
    end

  else
    local lineStartIndex = tonumber(figureId)

    self.Curve:DisconnectAt(lineStartIndex)

    if canvas then
      canvas:DeleteLineInCurve(self.TaskId, "Curve", self.Curve, lineStartIndex)
    end
  end
end

function StraightLine:CheckIntersection(board, figureId: string, centre: Vector2, radius: number)
  if figureId == "InitialPoint" then
    return (centre - self.InitialPoint).Magnitude <= radius

  else
    local lineStartIndex = tonumber(figureId)
    local line = self.Curve:LineBetween(self.Curve.Points[lineStartIndex], self.Curve.Points[lineStartIndex+1])

    return line:Intersects(centre, radius)
  end
end

return StraightLine
