local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local GuiPositioning = require(Common.GuiPositioning)
local LineInfo = require(Common.LineInfo)
local DrawingTask = require(Common.DrawingTask)
local DrawingTool = require(Common.DrawingTool)
local CatRom = require(Common.Packages.CatRom)
local CanvasState
local Pen = DrawingTool.Pen
local Eraser = DrawingTool.Eraser

local BoardGui
local Canvas
local Curves

local DrawLineRemoteEvent = Common.Remotes.DrawLine
local EraseLineRemoteEvent = Common.Remotes.EraseLine

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

  CurrentCurvePoints = nil,
}
Drawing.__index = Drawing

function Drawing.Init(boardGui)
  BoardGui = boardGui

  Canvas = BoardGui.Canvas
  Curves = BoardGui.Curves

  CanvasState = require(script.Parent.CanvasState)

  Drawing.PenA = Pen.new(Config.Defaults.PenAColor, Config.Defaults.PenAThicknessYScale, BoardGui.Toolbar.Pens.PenAButton)
  Drawing.PenB = Pen.new(Config.Defaults.PenBColor, Config.Defaults.PenBThicknessYScale, BoardGui.Toolbar.Pens.PenBButton)

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
      Drawing.ToolLift()
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
    CanvasState.Erase(
      newCanvasPos,
      Drawing.EquippedTool.ThicknessYScale/2,
      function(lineFrame)
        EraseLineRemoteEvent:FireServer(CanvasState.EquippedBoard, LineInfo.ReadInfo(lineFrame))
        CanvasState.DeleteLine(lineFrame)
      end)

  else
    if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
      return
    end

    local zIndex = CanvasState.EquippedBoard.CurrentZIndex.Value + 1

    local curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndexOf[CanvasState.EquippedBoard]), zIndex)

    local lineInfo = 
      LineInfo.new(
        newCanvasPos,
        newCanvasPos,
        Drawing.EquippedTool.ThicknessYScale,
        Drawing.EquippedTool.Color
      )
    local lineFrame = CanvasState.CreateLineFrame(lineInfo)

    LineInfo.StoreInfo(lineFrame, lineInfo)

    CanvasState.AttachLine(lineFrame, curve)

    curve.Parent = Curves

    Drawing.CurrentCurvePoints = {newCanvasPos}
    
    DrawingTask.InitRemoteEvent:FireServer(
      "FreeHand",
      CanvasState.EquippedBoard,
      newCanvasPos,
      Drawing.EquippedTool.ThicknessYScale,
      Drawing.EquippedTool.Color,
      Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndexOf[CanvasState.EquippedBoard])
    )
  end

  Drawing.MousePixelPos = Vector2.new(x, y)

end

function Drawing.ToolMoved(x,y)
  if Drawing.MouseHeld then

    local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x, y))
    
    if Drawing.EquippedTool.ToolType == "Eraser" then
      -- TODO consider erasing everything between old mouse position and new position

      CanvasState.Erase(
        newCanvasPos,
        Drawing.EquippedTool.ThicknessYScale/2,
        function(lineFrame)
          EraseLineRemoteEvent:FireServer(CanvasState.EquippedBoard, LineInfo.ReadInfo(lineFrame))
          CanvasState.DeleteLine(lineFrame)
        end)
    else
      assert(Drawing.EquippedTool.ToolType == "Pen")

      if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
        Drawing.MousePixelPos = Vector2.new(x, y)
        return
      end

      local curve = Curves:FindFirstChild(Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndexOf[CanvasState.EquippedBoard]))

      local lineInfo =
        LineInfo.new(
          CanvasState.GetScalePositionOnCanvas(Drawing.MousePixelPos),
          newCanvasPos,
          Drawing.EquippedTool.ThicknessYScale,
          Drawing.EquippedTool.Color
        )
      local lineFrame = CanvasState.CreateLineFrame(lineInfo)

      Drawing.CurrentCurvePoints[#Drawing.CurrentCurvePoints+1] = newCanvasPos

      LineInfo.StoreInfo(lineFrame, lineInfo)

      CanvasState.AttachLine(lineFrame, curve)

      DrawingTask.UpdateRemoteEvent:FireServer(newCanvasPos)
    end

    Drawing.MousePixelPos = Vector2.new(x, y)

  end
end

function Drawing.ToolLift()
  Drawing.MouseHeld = false

  if Drawing.EquippedTool.ToolType == "Pen" then

    if Config.SmoothingAlgorithm == "CatRom" then
      
      local numPoints = #Drawing.CurrentCurvePoints
      
      if numPoints <= 2 then return end
      
      local chain = CatRom.Chain.new(Drawing.CurrentCurvePoints)

      local curve = Curves:FindFirstChild(Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndexOf[CanvasState.EquippedBoard]))
      CanvasState.GetLinesContainer(curve):ClearAllChildren()

      -- obviously a slow way to do this
      local length = 0
      for i=1, (numPoints)-1 do
        length += (Drawing.CurrentCurvePoints[i+1] - Drawing.CurrentCurvePoints[i]).Magnitude
      end
      
      if curve then

        local curvePoints = {chain:SolvePosition(0)}

        for i=1, length/Config.CatRomLength - 1 do
            local lineInfo =
              LineInfo.new(
                chain:SolvePosition((i-1)/(length/Config.CatRomLength - 1)),
                chain:SolvePosition(i/(length/Config.CatRomLength - 1)),
                Drawing.EquippedTool.ThicknessYScale,
                Drawing.EquippedTool.Color
              )
            local lineFrame = CanvasState.CreateLineFrame(lineInfo)

            LineInfo.StoreInfo(lineFrame, lineInfo)
            CanvasState.AttachLine(lineFrame, curve)

            table.insert(curvePoints, chain:SolvePosition(i/(length/Config.CatRomLength - 1)))
        end

        DrawingTask.FinishRemoteEvent:FireServer(true, curvePoints)
      end

    elseif Config.SmoothingAlgorithm == "DouglasPeucker" then
      
      local numPoints = #Drawing.CurrentCurvePoints
  
      if numPoints <= 2 then return end
  
      local curvePoints = Drawing.CurrentCurvePoints

      Drawing.DouglasPeucker(curvePoints, 1, numPoints, Config.DouglasPeuckerEpsilon)

      local curve = Curves:FindFirstChild(Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndexOf[CanvasState.EquippedBoard]))

      if curve then
        CanvasState.GetLinesContainer(curve):ClearAllChildren()

        local i = 1
        while i < #curvePoints do
          while i < #curvePoints and curvePoints[i] == nil do i += 1 end
          local j = i+1
          while j <= #curvePoints and curvePoints[j] == nil do j += 1 end
          if curvePoints[j] then
            local lineInfo =
              LineInfo.new(
                curvePoints[i],
                curvePoints[j],
                Drawing.EquippedTool.ThicknessYScale,
                Drawing.EquippedTool.Color
              )
            local lineFrame = CanvasState.CreateLineFrame(lineInfo)

            LineInfo.StoreInfo(lineFrame, lineInfo)
            CanvasState.AttachLine(lineFrame, curve)
          end
          i += 1
        end
        -- DrawingTask.FinishRemoteEvent:FireServer(true, curvePoints)
      end
      DrawingTask.FinishRemoteEvent:FireServer(false)
    end
  end
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