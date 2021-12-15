local VRService = game:GetService("VRService")

local CollectionService = game:GetService("CollectionService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local GuiPositioning = require(Common.GuiPositioning)
local BoardGui
local CursorsGui
local Canvas
local Curves
local Buttons
local Drawing


local CanvasState = {

  -- the board that is currently displayed on the canvas
  EquippedBoard = nil,

  EquippedBoardAddLineConnection = nil,
  EquippedBoardRemoveLineConnection = nil,
  EquippedBoardRemoveCurveConnection = nil,

  SurfaceGuiConnections = {}
}

function CanvasState.Init(boardGui, cursorsGui)
  BoardGui = boardGui
  CursorsGui = cursorsGui
  Canvas = boardGui.Canvas
  Curves = boardGui.Curves

  Buttons = require(script.Parent.Buttons)
  Drawing = require(script.Parent.Drawing)

  BoardGui.Enabled = false
  CursorsGui.Enabled = false

  for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
    CanvasState.ConnectOpenBoardButton(board, board:WaitForChild("Canvas").SurfaceGui.Button)
  end

  CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(board)
    CanvasState.ConnectOpenBoardButton(board, board:WaitForChild("Canvas").SurfaceGui.Button)
  end)
  CollectionService:GetInstanceRemovedSignal(Config.BoardTag):Connect(function(board)
    if board == CanvasState.EquippedBoard then
      CanvasState.CloseBoard(board)
      if CanvasState.SurfaceGuiConnections[board] ~= nil then
        CanvasState.SurfaceGuiConnections[board]:Disconnect()
      end
    end
  end)

  print("CanvasState initialized")

end

function CanvasState.ConnectOpenBoardButton(board, button)
  CanvasState.SurfaceGuiConnections[board] =
    board.Canvas.SurfaceGui.Button.Activated:Connect(function()
      if CanvasState.EquippedBoard ~= nil then return end
      CanvasState.OpenBoard(board)
    end)
end

function CanvasState.OpenBoard(board)

  -- We do not open the BoardGui if we are in VR
  if VRService.VREnabled then return end
  
  CanvasState.EquippedBoard = board

  game.StarterGui:SetCore("TopbarEnabled", false)

  Buttons.OnBoardOpen(board)
  Drawing.OnBoardOpen(board)

  Canvas.UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y

  Canvas.BackgroundColor3 = board.Color
  BoardGui.Enabled = true
  CursorsGui.Enabled = true

  CanvasState.EquippedBoardAddLineConnection =
    board.Canvas.Curves.DescendantAdded:Connect(function(descendant)
      -- TODO: hardcoded dependency on details of word line generation
      -- if descendant:IsA("BoxHandleAdornment") then
      --   print(descendant.Parent:GetAttribute("AuthorUserId"))
      -- end


      if descendant:IsA("BoxHandleAdornment") and descendant.Parent:GetAttribute("AuthorUserId") ~= LocalPlayer.UserId then
        local curveName = descendant.Parent.Name
        local curve = Curves:FindFirstChild(curveName)

        if curve then
          local lineInfo = LineInfo.ReadInfo(descendant)
          local lineFrame = CanvasState.CreateLineFrame(lineInfo)
          LineInfo.StoreInfo(lineFrame, lineInfo)
          CanvasState.AttachLine(lineFrame, curve)
        end
      end
    end)
  
  CanvasState.EquippedBoardRemoveLineConnection =
    board.Canvas.Curves.DescendantRemoving:Connect(function(descendant)
      -- TODO: hardcoded dependency on details of word line generation
      if descendant:IsA("BoxHandleAdornment") then
        local curveName = descendant.Parent.Name

        local curve = Curves:FindFirstChild(curveName)

        if curve then
          for _, lineFrame in ipairs(CanvasState.GetLinesContainer(curve):GetChildren()) do
            local descendantInfo = LineInfo.ReadInfo(descendant)
            local lineInfo = LineInfo.ReadInfo(lineFrame)
            if 
               descendantInfo.Start == lineInfo.Start and
               descendantInfo.Stop == lineInfo.Stop and
               descendantInfo.ThicknessYScale == lineInfo.ThicknessYScale
            then
              CanvasState.DeleteLine(lineFrame)
              return
            end
          end
        end
      end
    end)

    CanvasState.EquippedBoardRemoveCurveConnection =
    board.Canvas.Curves.ChildRemoved:Connect(function(worldCurve)
      local curve = Curves:FindFirstChild(worldCurve.Name)

      if curve then
        curve:Destroy()
      end
    end)

  

  for _, worldCurve in ipairs(board.Canvas.Curves:GetChildren()) do
    local curve = CanvasState.CreateCurve(board, worldCurve.Name, worldCurve:GetAttribute("ZIndex"))
    for _, worldLine in ipairs(worldCurve:GetChildren()) do
      local lineInfo = LineInfo.ReadInfo(worldLine)
      local lineFrame = CanvasState.CreateLineFrame(lineInfo)
      LineInfo.StoreInfo(lineFrame, lineInfo)
      CanvasState.AttachLine(lineFrame, curve)
    end
    curve.Parent = Curves
  end

end

function CanvasState.CloseBoard(board)
  
  BoardGui.Enabled = false
  CursorsGui.Enabled = false

  CanvasState.EquippedBoardAddLineConnection:Disconnect()
  CanvasState.EquippedBoardRemoveLineConnection:Disconnect()
  CanvasState.EquippedBoardRemoveCurveConnection:Disconnect()
  
  game.StarterGui:SetCore("TopbarEnabled", true)

  CanvasState.EquippedBoard = nil

  Curves:ClearAllChildren()
end

function CanvasState.GetCanvasPixelPosition()
  return Vector2.new(Canvas.AbsolutePosition.X, Canvas.AbsolutePosition.Y + 36)
end

function CanvasState.GetScalePositionOnCanvas(pixelPos)
  return (pixelPos - (Canvas.AbsolutePosition + Vector2.new(0,36)))/Canvas.AbsoluteSize.Y
end

function CanvasState.CanvasYScaleToOffset(yScaleValue)
  return yScaleValue * Canvas.AbsoluteSize.Y
end

function CanvasState.CreateCurve(board, curveName, zIndex)
  local curveGui = Instance.new("ScreenGui")
  curveGui.Name = curveName
  curveGui.IgnoreGuiInset = true
  curveGui.Parent = Curves

  curveGui.DisplayOrder = zIndex
  
  local canvasGhost = Instance.new("Frame")
  canvasGhost.Name = "CanvasGhost"
  canvasGhost.AnchorPoint = Vector2.new(0.5,0)
  canvasGhost.Size = UDim2.new(0.85,0,0.85,0)
  canvasGhost.Position = UDim2.new(0.5,0,0.125,0)
  canvasGhost.BackgroundTransparency = 1

  local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
  UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y

  local coordinateFrame = Instance.new("Frame")
  coordinateFrame.Name = "CoordinateFrame"
  coordinateFrame.AnchorPoint = Vector2.new(0,0)
  coordinateFrame.Position = UDim2.new(0,0,0,0)
  coordinateFrame.Size = UDim2.new(1,0,1,0)
  coordinateFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
  coordinateFrame.BackgroundTransparency = 1

  UIAspectRatioConstraint.Parent = canvasGhost
  coordinateFrame.Parent = canvasGhost
  canvasGhost.Parent = curveGui

  return curveGui
end

function CanvasState.GetLinesContainer(curve)
  return curve.CanvasGhost.CoordinateFrame
end

function CanvasState.AttachLine(line, curve)
  line.Parent = curve.CanvasGhost.CoordinateFrame
end

function CanvasState.GetParentCurve(line)
  return line.Parent.Parent.Parent
end

function CanvasState.CreateLineFrame(lineInfo)
  local lineFrame = Instance.new("Frame")

  CanvasState.UpdateLineFrame(lineFrame, lineInfo)
  
  -- Round the corners
  if lineInfo.ThicknessYScale * Canvas.AbsoluteSize.Y >= Config.UICornerThreshold then
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0.5,0)
    UICorner.Parent = lineFrame
  end

  return lineFrame
end

function CanvasState.UpdateLineFrame(lineFrame, lineInfo)
  if lineInfo.Start == lineInfo.Stop then
    lineFrame.Size = UDim2.new(lineInfo.ThicknessYScale, 0, lineInfo.ThicknessYScale, 0)
  else
    lineFrame.Size = UDim2.new(lineInfo.Length + lineInfo.ThicknessYScale, 0, lineInfo.ThicknessYScale, 0)
  end

  lineFrame.Position = UDim2.new(lineInfo.Centre.X, 0, lineInfo.Centre.Y, 0)
  lineFrame.Rotation = lineInfo.RotationDegrees
  lineFrame.AnchorPoint = Vector2.new(0.5,0.5)
  lineFrame.BackgroundColor3 = lineInfo.Color
  lineFrame.BorderSizePixel = 0
end


function CanvasState.DrawLine(board, lineInfo)
  local zIndex = board.CurrentZIndex.Value
  
  local curve = Curves:FindFirstChild(lineInfo.CurveName)

  if curve == nil then
    curve = Instance.new("ScreenGui")
    curve.Name = lineInfo.CurveName
    curve.IgnoreGuiInset = true
    curve.Parent = Curves

    zIndex += 1

    curve.DisplayOrder = zIndex
  end


  local lineFrame = CanvasState.CreateLineFrame(lineInfo, zIndex)

  local wrappedLine = CanvasState.WrapInCoordinateFrame(lineFrame)

  LineInfo.StoreInfo(wrappedLine, lineInfo)

  wrappedLine.Parent = curve
end

-- Draw/update the cursor for a player's tool on the Gui
function CanvasState.DrawToolCursor(player, tool, x, y)
  -- Find existing cursor
  local cursor = CursorsGui:FindFirstChild(player.Name)

  if cursor == nil then
    -- Setup a new cursor
    cursor = Instance.new("Frame")
    cursor.Name = player.Name
    cursor.SizeConstraint = Enum.SizeConstraint.RelativeYY
    cursor.AnchorPoint = Vector2.new(0.5,0.5)
    
    -- Make cursor circular
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0.5,0)
    UICorner.Parent = cursor

    -- Add outline
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Thickness = 1
    UIStroke.Color = Color3.new(0,0,0)
    UIStroke.Parent = cursor

    -- Put the player name at the bottom right of the cursor
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "PlayerName"
    textLabel.Text = player.Name
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Position = UDim2.new(1,5,1,5)
    textLabel.BackgroundTransparency = 1
    textLabel.Parent = cursor

    cursor.Parent = CursorsGui
  end

  -- Reposition cursor to new position (should be given with Scale values)
  cursor.Position = GuiPositioning.PositionFromPixel(x,y, CursorsGui.IgnoreGuiInset)

  -- Configure cursor appearance based on tool type
  if tool.ToolType == "Pen" then
    cursor.Size = UDim2.new(0, tool.ThicknessYScale * Canvas.AbsoluteSize.Y,
                            0, tool.ThicknessYScale * Canvas.AbsoluteSize.Y)
    cursor.BackgroundColor3 = tool.Color
    cursor.BackgroundTransparency = 0.5
  elseif tool.ToolType == "Eraser" then
    cursor.Size = UDim2.new(0, tool.ThicknessYScale * Canvas.AbsoluteSize.Y,
                            0, tool.ThicknessYScale * Canvas.AbsoluteSize.Y)
    cursor.BackgroundColor3 = Color3.new(1, 1, 1)
    cursor.BackgroundTransparency = 0.5
  end

  if player == LocalPlayer then
    cursor.PlayerName.Visible = false
  end

end

function CanvasState.DestroyToolCursor(player)
  local cursor = CursorsGui:FindFirstChild(player.Name)
  if cursor then cursor:Destroy() end
end

function CanvasState.Intersects(pos, radius, lineInfo)
  local u = pos - lineInfo.Start
  local v = lineInfo.Stop - lineInfo.Start

  if v.Magnitude <= Config.IntersectionResolution then
    return u.Magnitude <= radius + lineInfo.ThicknessYScale
  end

  local vhat = v / v.Magnitude
  
  -- Check if the tip of the projection of u onto v is within the radius of the thick line around v
  if -lineInfo.ThicknessYScale <= u:Dot(vhat) + radius and u:Dot(vhat) - radius <= v.Magnitude + lineInfo.ThicknessYScale then
    -- Check if the tip of the 'rejection' of u onto v (i.e. u minus the projection)
    -- is within the radius of the thick line around v
    return (u - ((u:Dot(vhat) * v))).Magnitude <= radius + lineInfo.ThicknessYScale
  end

  return false
end

function CanvasState.Erase(pos, radiusYScale, lineFrameDestroyer)
  for _, curve in ipairs(Curves:GetChildren()) do
    for _, lineFrame in ipairs(CanvasState.GetLinesContainer(curve):GetChildren()) do
      if CanvasState.Intersects(
          pos,
          radiusYScale,
          lineFrame:GetAttribute("Start"),
          lineFrame:GetAttribute("Stop"),
          lineFrame:GetAttribute("ThicknessYScale")) then
        
        lineFrameDestroyer(lineFrame)
      end
    end
  end
end

function CanvasState.DeleteLine(lineFrame)
  local curve = CanvasState.GetParentCurve(lineFrame)
  lineFrame:Destroy()
end

function CanvasState.DeleteCurve(curveName)
  local curve = Curves:FindFirstChild(curveName)
  -- TODO erased curves won't be there
  if curve then
    curve:Destroy()
  end
end

function CanvasState.WrapInCoordinateFrame(lineFrame)
  local canvasFrameDuplicate = Instance.new("Frame")
  canvasFrameDuplicate.AnchorPoint = Vector2.new(0.5,0.5)
  canvasFrameDuplicate.Position = UDim2.new(0.5, 0, 0.55, 0)
  canvasFrameDuplicate.Size = UDim2.new(0.855, 0, 0.855, 0)
  canvasFrameDuplicate.BackgroundTransparency = 1
  
  local UIAspectRatioConstraint = Canvas.UIAspectRatioConstraint:Clone()
  UIAspectRatioConstraint.Parent = canvasFrameDuplicate
  
  local coordinateFrame = Instance.new("Frame")
  coordinateFrame.AnchorPoint = Vector2.new(0,0)
  coordinateFrame.Position = UDim2.new(0, 0, 0, 0)
  coordinateFrame.Size = UDim2.new(1,0,1,0)
  coordinateFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
  coordinateFrame.Parent = canvasFrameDuplicate
  coordinateFrame.BackgroundTransparency = 1

  lineFrame.Parent = coordinateFrame

  return canvasFrameDuplicate
end

return CanvasState