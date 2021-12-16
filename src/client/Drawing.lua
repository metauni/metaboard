local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local DrawingTask = require(Common.DrawingTask)
local ClientDrawingTasks
local DrawingTool = require(Common.DrawingTool)
local CanvasState
local Pen = DrawingTool.Pen
local Eraser = DrawingTool.Eraser

local BoardGui
local Canvas
local Curves

local Drawing = {
  -- mouse state
  ---------------
  MouseHeld = false,
  -- pixel coordinates of mouse
  MousePixelPos = nil,

  -- drawing pen state
  ---------------------
  PenA = nil,
  PenB = nil,

  -- Drawing Mode
  PenMode = nil,

  -- eraser state
  ----------------
  Eraser = nil,
  
  EquippedTool = nil,
  
  ReservedTool = nil,

  -- Every line drawn by this player on a given board will be sequentially
  -- numbered by a curve index for undo-functionality. 
  -- CurveIndexOf[board] will be the current curve being drawn on the board
  -- by this player (or the last drawn curve if mouseHeld is false)
  -- (See Config.CurveNamer)
  CurveIndexOf = {},

  CurrentTask = nil
}
Drawing.__index = Drawing

function Drawing.Init(boardGui)
  BoardGui = boardGui

  Canvas = BoardGui.Canvas
  Curves = BoardGui.Curves

  CanvasState = require(script.Parent.CanvasState)

  Drawing.PenA = Pen.new(Config.Defaults.PenAColor, Config.Defaults.PenAThicknessYScale, BoardGui.Toolbar.Pens.PenAButton)
  Drawing.PenB = Pen.new(Config.Defaults.PenBColor, Config.Defaults.PenBThicknessYScale, BoardGui.Toolbar.Pens.PenBButton)

  Drawing.PenMode = "FreeHand"

  ClientDrawingTasks = require(script.Parent.ClientDrawingTasks)

  Drawing.Eraser = Eraser.new(Config.EraserSmall, BoardGui.Toolbar.Erasers.SmallButton)

  Drawing.EquippedTool = Drawing.PenA
  Drawing.ReservedTool = Drawing.Eraser

  Canvas.MouseButton1Down:Connect(Drawing.ToolDown)

  Canvas.MouseMoved:Connect(function(x,y)
    CanvasState.DrawToolCursor(LocalPlayer, Drawing.EquippedTool, x, y)
    Drawing.ToolMoved(x,y)
  end)

  UserInputService.InputEnded:Connect(function(input, gp)
    if Drawing.MouseHeld then
      Drawing.ToolLift(input.Position.X, input.Position.Y + 36)
    end
  end)
  
  Canvas.MouseLeave:Connect(function(x,y)
    -- TODO: this seems to run before InputEnded on touch screens
    -- Drawing.MouseHeld = false
    CanvasState.DestroyToolCursor(LocalPlayer)
  end)

end

function Drawing.OnBoardOpen(board)
  if Drawing.CurveIndexOf[board] == nil then
    Drawing.CurveIndexOf[board] = 0
  end
end

function Drawing.WithinBounds(x,y, thicknessYScale)
  local leftBuffer = (x - Canvas.AbsolutePosition.X)/Canvas.AbsoluteSize.Y
  local rightBuffer = (Canvas.AbsolutePosition.X + Canvas.AbsoluteSize.X - x)/Canvas.AbsoluteSize.Y
  local upBuffer = (y - (Canvas.AbsolutePosition.Y + 36))/Canvas.AbsoluteSize.Y
  local downBuffer = ((Canvas.AbsolutePosition.Y + Canvas.AbsoluteSize.Y + 36) - y)/Canvas.AbsoluteSize.Y

  return
    leftBuffer >= thicknessYScale/2 and
    rightBuffer >= thicknessYScale/2 and
    upBuffer >= thicknessYScale/2 and
    downBuffer >= thicknessYScale/2
end

function Drawing.ToolDown(x,y)

  Drawing.MouseHeld = true
  Drawing.CurveIndexOf[CanvasState.EquippedBoard] += 1

  local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x,y))

  if Drawing.EquippedTool.ToolType == "Eraser" then
    Drawing.CurrentTask = ClientDrawingTasks.new("Erase")
    Drawing.CurrentTask.Init(Drawing.CurrentTask.State, newCanvasPos)
  else
    if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
      return
    end

    if Drawing.EquippedTool.ToolType == "Pen" then
      Drawing.CurrentTask = ClientDrawingTasks.new(Drawing.PenMode)
      Drawing.CurrentTask.Init(Drawing.CurrentTask.State, newCanvasPos)
    end
  end

  Drawing.MousePixelPos = Vector2.new(x, y)

end

function Drawing.ToolMoved(x,y)
  if Drawing.MouseHeld then

    local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x, y))
    
    if Drawing.EquippedTool.ToolType == "Eraser" then
      Drawing.CurrentTask.Update(Drawing.CurrentTask.State, newCanvasPos)
    else
      assert(Drawing.EquippedTool.ToolType == "Pen")

      if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
        Drawing.MousePixelPos = Vector2.new(x, y)
        return
      end

      Drawing.CurrentTask.Update(Drawing.CurrentTask.State, newCanvasPos)

    end

    Drawing.MousePixelPos = Vector2.new(x, y)

  end
end

function Drawing.ToolLift(x,y)

  local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x, y))
  Drawing.MouseHeld = false
  Drawing.MousePixelPos = Vector2.new(x,y)
  
  Drawing.CurrentTask.Finish(Drawing.CurrentTask.State, newCanvasPos)
end

-- Perform the Douglas-Peucker algorithm on a polyline given as an array
-- of points. Instead of returning a new polyline, this function sets
-- all of the removed points to nil
function Drawing.DouglasPeucker(points, startIndex, stopIndex, epsilon)
  
  if stopIndex - startIndex + 1 <= 2 then return end

  local startPoint = points[startIndex]
  local stopPoint = points[stopIndex]

  local maxPerp = nil
  local maxPerpIndex = nil
  
  for i = startIndex+1, stopIndex-1 do
    -- Get the length of the perpendicular vector between points[i] and the line through startPoint and stopPoint
    local perp = math.abs((points[i] - startPoint).Unit:Cross((startPoint-stopPoint).Unit) * ((points[i] - startPoint).Magnitude))
    if maxPerp == nil or perp > maxPerp then
      maxPerp = perp
      maxPerpIndex = i
    end
  end

  if maxPerp > epsilon then
    Drawing.DouglasPeucker(points, startIndex, maxPerpIndex, epsilon)
    Drawing.DouglasPeucker(points, maxPerpIndex, stopIndex, epsilon)
  else
    for i = startIndex+1, stopIndex-1 do
      points[i] = nil
    end
  end
end


return Drawing