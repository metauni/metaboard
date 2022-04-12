-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local AbstractDrawingTask = require(script.Parent.AbstractDrawingTask)
local Curve = require(Common.Figure.Curve)

-- FreeHand
local FreeHand = setmetatable({}, AbstractDrawingTask)
FreeHand.__index = FreeHand

function FreeHand.new(board, taskId: string, provisional: boolean, color: Color3, thicknessYScale: number)
  local self = setmetatable(AbstractDrawingTask.new(taskId, provisional), FreeHand)

  self.TaskType = "FreeHand"
  self.Color = color
  self.ThicknessYScale = thicknessYScale

  return self
end

function FreeHand:Init(board, pos: Vector2, canvas)
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

function FreeHand:Update(board, pos: Vector2, canvas)
  if canvas then
    canvas:UpdateCurvePoint(self.TaskId, nil, self.Curve, #self.Curve.Points+1, pos)
  end

  self.Curve:Extend(pos)
end

function FreeHand:Finish(board, canvas)
  -- Nothing I guess, unless for smoothing?
end

function FreeHand:Render(board, canvas)
  -- TODO
end

function FreeHand:Undo(board, canvas)
  if canvas then
    canvas:DeleteCurve(self.TaskId, nil)
  end
end

function FreeHand:Redo(board, canvas)
  if canvas then
    canvas:WriteCurve(self.TaskId, nil, self.Curve)
  end
end

function FreeHand:Commit(board, canvas)

end

function FreeHand:RenderGhost(board, ghostGroupId, intersectedIds, canvas)

  local ghostCurve = self.Curve:ShallowClone()
  ghostCurve.Color = Color3.new(0,0,0)

  canvas:AddSubCurve(ghostGroupId, self.TaskId, ghostCurve, intersectedIds)

end

function FreeHand:EraseFigures(board, intersectedIds, canvas)
  canvas:SubtractSubCurve(nil, self.TaskId, self.Curve, intersectedIds)
end

return FreeHand
