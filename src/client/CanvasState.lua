local VRService = game:GetService("VRService")

local CollectionService = game:GetService("CollectionService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.MetaBoardConfig)
local LineProperties = require(Common.LineProperties)
local BoardGui
local CursorsGui
local Canvas
local Curves
local Buttons

local GuiPositioning = require(Common.GuiPositioning)
local PositionFromAbsolute = GuiPositioning.PositionFromAbsolute
local PositionFromPixel = GuiPositioning.PositionFromPixel

local CanvasState = {

  -- the board that is currently displayed on the canvas
  EquippedBoard = nil,

  EquippedBoardAddLineConnection = nil,
  EquippedBoardRemoveLineConnection = nil,

  SurfaceGuiConnections = {}
}

function CanvasState.Init(boardGui, cursorsGui)
  BoardGui = boardGui
  CursorsGui = cursorsGui
  Canvas = boardGui.CanvasZone.Canvas
  Curves = Canvas.Curves

  Buttons = require(script.Parent.Buttons)

  BoardGui.Enabled = false
  CursorsGui.Enabled = false

  for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
    CanvasState.ConnectOpenBoardButton(board)
  end

  CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(CanvasState.ConnectOpenBoardButton)
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

function CanvasState.ConnectOpenBoardButton(board)
  CanvasState.SurfaceGuiConnections[board] =
    board.SurfaceGui.BoardButton.Activated:Connect(function()
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

  Canvas.UIAspectRatioConstraint.AspectRatio = board.Size.X / board.Size.Y

  Canvas.BackgroundColor3 = board.Color
  BoardGui.Enabled = true
  CursorsGui.Enabled = true

  CanvasState.EquippedBoardAddLineConnection =
    board.Curves.DescendantAdded:Connect(function(descendant)
      -- TODO: hardcoded dependency on details of word line generation
      if descendant:IsA("BoxHandleAdornment") and descendant.Parent:GetAttribute("AuthorUserId") ~= LocalPlayer.UserId then
        CanvasState.DrawLine(board, LineProperties.ReadFromAttributes(descendant))
      end
    end)
  
  CanvasState.EquippedBoardRemoveLineConnection =
    board.Curves.DescendantRemoving:Connect(function(descendant)
      -- TODO: hardcoded dependency on details of word line generation
      if descendant:IsA("BoxHandleAdornment") then
        local curveName = descendant.Parent

        local curve = Curves:FindFirstChild(curveName)

        if curve then
          for _, lineFrame in ipairs(curve:GetChildren()) do
            if 
              LineProperties.ReadFromAttributes(lineFrame):Equals(LineProperties.ReadFromAttributes(descendant))
            then
              CanvasState.DeleteLine(lineFrame)
              return
            end
          end
        end
      end
    end)

  for _, worldCurve in ipairs(board.Curves:GetChildren()) do
    local curve = Instance.new("Folder")
    curve.Name = worldCurve.Name
    for _, worldLine in ipairs(worldCurve:GetChildren()) do
      local lineFrame = CanvasState.CreateLineFrame(LineProperties.ReadFromAttributes(worldLine), worldLine:GetAttribute("ZIndex"))
      lineFrame.Parent = curve
    end
    curve.Parent = Curves
  end

end

function CanvasState.CloseBoard(board)
  
  BoardGui.Enabled = false
  CursorsGui.Enabled = false

  CanvasState.EquippedBoardAddLineConnection:Disconnect()
  CanvasState.EquippedBoardRemoveLineConnection:Disconnect()
  
  game.StarterGui:SetCore("TopbarEnabled", true)

  CanvasState.EquippedBoard = nil

  Buttons.OnBoardClose(board)

  Curves:ClearAllChildren()
end

function CanvasState.GetCanvasPixelPosition()
  return Vector2.new(Canvas.AbsolutePosition.X, Canvas.AbsolutePosition.Y + 36)
end

function CanvasState.GetScalePositionOnCanvas(pixelPos)
  return (pixelPos - (Curves.AbsolutePosition + Vector2.new(0,36)))/Curves.AbsoluteSize.Y
end

function CanvasState.CanvasYScaleToOffset(yScaleValue)
  return yScaleValue * Canvas.AbsoluteSize.Y
end

function CanvasState.CreateLineFrame(lineProperties, zIndex)
  local lineFrame = Instance.new("Frame")

  if lineProperties.Start == lineProperties.Stop then
    lineFrame.Size = UDim2.new(lineProperties.ThicknessYScale, 0, lineProperties.ThicknessYScale, 0)
  else
    lineFrame.Size = UDim2.new(lineProperties.Length + lineProperties.ThicknessYScale, 0, lineProperties.ThicknessYScale, 0)
  end

  lineFrame.Position = UDim2.new(lineProperties.Centre.X, 0, lineProperties.Centre.Y, 0)
  lineFrame.Rotation = lineProperties.RotationDegrees
  lineFrame.AnchorPoint = Vector2.new(0.5,0.5) --this bases the position and rotation at the same point (object centre)
  lineFrame.BackgroundColor3 = lineProperties.Color
  lineFrame.BorderSizePixel = 0
  lineFrame.ZIndex = zIndex
  
  -- Round the corners
  local UICorner = Instance.new("UICorner")
  UICorner.CornerRadius = UDim.new(0.5,0)
  UICorner.Parent = lineFrame

  return lineFrame
end


function CanvasState.DrawLine(board, lineProperties)
  local zIndex = board.CurrentZIndex.Value
  
  local curve = Curves:FindFirstChild(lineProperties.CurveName)

  if curve == nil then
    curve = Instance.new("Folder")
    curve.Name = lineProperties.CurveName
    curve.Parent = Curves

    zIndex += 1
  end

  local lineFrame = CanvasState.CreateLineFrame(lineProperties, zIndex)

  lineFrame.Parent = curve

  lineProperties:StoreAttributes(lineFrame)
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
  cursor.Position = PositionFromPixel(x,y, CursorsGui.IgnoreGuiInset)

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

function CanvasState.intersects(pos, radius, start, stop, thicknessYScale)
  local u = pos - start
  local v = stop - start

  if v.Magnitude <= Config.IntersectionResolution then
    return u.Magnitude <= radius + thicknessYScale
  end

  local vhat = v / v.Magnitude
  
  -- Check if the tip of the projection of u onto v is within the radius of the thick line around v
  if -thicknessYScale <= u:Dot(vhat) + radius and u:Dot(vhat) - radius <= v.Magnitude + thicknessYScale then
    -- Check if the tip of the 'rejection' of u onto v (i.e. u minus the projection)
    -- is within the radius of the thick line around v
    return (u - ((u:Dot(vhat) * v))).Magnitude <= radius + thicknessYScale
  end

  return false
end

function CanvasState.Erase(pos, radiusYScale, lineFrameDestroyer)
  for _, curve in ipairs(Curves:GetChildren()) do
    for _, lineFrame in ipairs(curve:GetChildren()) do
      if CanvasState.intersects(
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
  local curve = lineFrame.Parent
  lineFrame:Destroy()
  
  -- TODO consider erase-undo interaction with curve index
  if #curve:GetChildren() == 0 then
    curve:Destroy()
  end
end

function CanvasState.DeleteCurve(curveName)
  local curve = Curves:FindFirstChild(curveName)
  if curve then
    curve:Destroy()
  else
    error("No curve found with name: "..curveName)
  end
end

return CanvasState