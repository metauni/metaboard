local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.MetaBoardConfig)
local GuiPositioning = require(Common.GuiPositioning)
local LineProperties = require(Common.LineProperties)
local PositionFromAbsolute = GuiPositioning.PositionFromAbsolute
local PositionFromPixel = GuiPositioning.PositionFromPixel
local CanvasState = require(script.Parent.CanvasState)
local DrawingTool = require(Common.DrawingTool)
local Pen = DrawingTool.Pen
local Eraser = DrawingTool.Eraser

local BoardGui
local Canvas
local Curves

local DrawLineRemoteEvent = Common.DrawLineRemoteEvent
local EraseLineRemoteEvent = Common.EraseLineRemoteEvent

Drawing = {
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

  -- Every line drawn by this player will be sequentially numbered by
  -- a curve index for undo-functionality. This keeps track of the index of the
  -- current curve being drawn (or the previous one if the tool is 'up')
  -- (See Config.CurveNamer)
  CurveIndex = 0,
}
Drawing.__index = Drawing

function Drawing.Init(boardGui)
  BoardGui = boardGui

  Canvas = BoardGui.CanvasZone.Canvas
  Curves = Canvas.Curves

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

  UserInputService.InputEnded:Connect(function(input, gp) Drawing.ToolLift(nil,nil) end)
  
  Canvas.MouseLeave:Connect(function(x,y) 
    Drawing.MouseHeld = false
    CanvasState.DestroyToolCursor(LocalPlayer)
  end)

end

function Drawing.WithinBounds(x,y, thicknessYScale)
  local leftBuffer = (x - Canvas.AbsolutePosition.X)/Curves.AbsoluteSize.Y
  local rightBuffer = (Canvas.AbsolutePosition.X + Canvas.AbsoluteSize.X - x)/Curves.AbsoluteSize.Y
  local upBuffer = (y - (Canvas.AbsolutePosition.Y + 36))/Curves.AbsoluteSize.Y
  local downBuffer = ((Canvas.AbsolutePosition.Y + Canvas.AbsoluteSize.Y + 36) - y)/Curves.AbsoluteSize.Y

  return
    leftBuffer >= thicknessYScale/2 and
    rightBuffer >= thicknessYScale/2 and
    upBuffer >= thicknessYScale/2 and
    downBuffer >= thicknessYScale/2
end

function Drawing.ToolDown(x,y)

  Drawing.MouseHeld = true
  Drawing.CurveIndex += 1

  local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x,y))

  if Drawing.EquippedTool.ToolType == "Eraser" then 
    CanvasState.Erase(
      newCanvasPos,
      Drawing.EquippedTool.ThicknessYScale/2,
      function(lineFrame)
        EraseLineRemoteEvent:FireServer(CanvasState.EquippedBoard, LineProperties.ReadFromAttributes(lineFrame))
        CanvasState.DeleteLine(lineFrame)
      end)

  else
    if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
      return
    end

    CanvasState.DrawLine(
      CanvasState.EquippedBoard,
      LineProperties.new(
        newCanvasPos,
        newCanvasPos,
        Drawing.EquippedTool.ThicknessYScale,
        Drawing.EquippedTool.Color,
        Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndex)
      )
    )
    
    DrawLineRemoteEvent:FireServer(
      CanvasState.EquippedBoard,
      LineProperties.new(
        newCanvasPos,
        newCanvasPos,
        Drawing.EquippedTool.ThicknessYScale,
        Drawing.EquippedTool.Color,
        Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndex)
      )
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
          EraseLineRemoteEvent:FireServer(CanvasState.EquippedBoard, LineProperties.ReadFromAttributes(lineFrame))
          CanvasState.DeleteLine(lineFrame)
        end)
    else
      assert(Drawing.EquippedTool.ToolType == "Pen")

      if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
        Drawing.MousePixelPos = Vector2.new(x, y)
        return
      end

      CanvasState.DrawLine(
        CanvasState.EquippedBoard,
        LineProperties.new(
          CanvasState.GetScalePositionOnCanvas(Drawing.MousePixelPos),
          newCanvasPos,
          Drawing.EquippedTool.ThicknessYScale,
          Drawing.EquippedTool.Color,
          Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndex)
        )
      )

      DrawLineRemoteEvent:FireServer(
        CanvasState.EquippedBoard,
        LineProperties.new(
          CanvasState.GetScalePositionOnCanvas(Drawing.MousePixelPos),
          newCanvasPos,
          Drawing.EquippedTool.ThicknessYScale,
          Drawing.EquippedTool.Color,
          Config.CurveNamer(LocalPlayer.Name, Drawing.CurveIndex)
        )
      )
    end

    Drawing.MousePixelPos = Vector2.new(x, y)

  end
end

function Drawing.ToolLift(x,y)
  Drawing.MouseHeld = false
end

return Drawing