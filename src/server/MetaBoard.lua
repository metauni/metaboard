local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local DrawingTask = require(Common.DrawingTask)
local ServerDrawingTasks

local UndoCurveRemoteEvent = Common.Remotes.UndoCurve

local MetaBoard = {}
MetaBoard.__index = MetaBoard

function MetaBoard.Init()

  ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)

  for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
    MetaBoard.InitBoard(board)
  end

  CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(MetaBoard.InitBoard)

  UndoCurveRemoteEvent.OnServerEvent:Connect(function(player, board, curveName)
    MetaBoard.DeleteWorldCurve(board, curveName)
  end)

  MetaBoard.DrawingTasks = {}

  DrawingTask.InitRemoteEvent.OnServerEvent:Connect(function(player, board, taskKind, ...)
    local drawingTask = ServerDrawingTasks.new(taskKind, player, board)
    MetaBoard.DrawingTasks[player] = drawingTask
    drawingTask.Init(drawingTask.State, ...)
  end)

  DrawingTask.UpdateRemoteEvent.OnServerEvent:Connect(function(player, ...)
    local drawingTask = MetaBoard.DrawingTasks[player]
    if drawingTask then
      drawingTask.Update(drawingTask.State, ...)
    else
      error("No drawing task to update for "..player.Name)
    end
  end)

  DrawingTask.FinishRemoteEvent.OnServerEvent:Connect(function(player, ...)
    local drawingTask = MetaBoard.DrawingTasks[player]
    if drawingTask then
      drawingTask.Finish(drawingTask.State, ...)
      -- TODO: Is this necessary? Think about garbage collection
      MetaBoard.DrawingTasks[player] = nil
    else
      error("No drawing task to finish for "..player.Name)
    end
  end)

  print("MetaBoard Server initialized")
end

function MetaBoard.GetSurfaceCFrame(part, face)
  if face == "Front" then
    return part.CFrame * CFrame.Angles(0,0,0) * CFrame.new(0,0,-part.Size.Z/2)
  elseif face == "Left" then
    return part.CFrame * CFrame.Angles(0,math.pi/2,0) * CFrame.new(0,0,-part.Size.X/2)
  elseif face == "Back" then
    return part.CFrame * CFrame.Angles(0,math.pi,0) * CFrame.new(0,0,-part.Size.Z/2)
  elseif face == "Right" then
    return part.CFrame * CFrame.Angles(0,-math.pi/2,0) * CFrame.new(0,0,-part.Size.X/2)
  elseif face == "Top" then
    return part.CFrame * CFrame.Angles(math.pi/2,0,0) * CFrame.new(0,0,-part.Size.Y/2)
  elseif face == "Bottom" then
    return part.CFrame * CFrame.Angles(-math.pi/2,0,0) * CFrame.new(0,0,-part.Size.Y/2)
  end
end

function MetaBoard.GetSurfaceDimensions(part, face)
  if face == "Front" then
    return Vector2.new(part.Size.X,part.Size.Y)
  elseif face == "Left" then
    return Vector2.new(part.Size.Z,part.Size.Y)
  elseif face == "Back" then
    return Vector2.new(part.Size.X,part.Size.Y)
  elseif face == "Right" then
    return Vector2.new(part.Size.Z,part.Size.Y)
  elseif face == "Top" then
    return Vector2.new(part.Size.X,part.Size.Z) 
  elseif face == "Bottom" then
    return Vector2.new(part.Size.X,part.Size.Z) 
  end
end

function MetaBoard.InitBoard(board)
  
  local face = board:FindFirstChild("Face")
  if face == nil then
    face = Instance.new("StringValue")
    face.Name = "Face"
    face.Value = "Front"
    
    face.Parent = board
  end
  
  local canvasColor = board:FindFirstChild("CanvasColor")
  if canvasColor == nil then
    canvasColor = Instance.new("Color3Value")
    canvasColor.Name = "CanvasColor"
    canvasColor.Value = board.Color or Color3.new(1,1,1)

    canvasColor.Parent = board
  end
  
  local canvas = board:FindFirstChild("Canvas")

  if canvas == nil then
    canvas = Instance.new("Part")
    canvas.Name = "Canvas"
    canvas.Massless = true
    canvas.CanCollide = false
    canvas.CanTouch = false
    local dimensions = MetaBoard.GetSurfaceDimensions(board, face.Value)
    canvas.Size = Vector3.new(dimensions.X, dimensions.Y, Config.CanvasThickness)
    canvas.CFrame = MetaBoard.GetSurfaceCFrame(board, face.Value) * CFrame.new(0,0,-canvas.Size.Z/2)
    canvas.Transparency = 1

    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Part0 = board
    weldConstraint.Part1 = canvas
    weldConstraint.Parent = board

    local curves = Instance.new("Folder")
    curves.Name = "Curves"
    curves.Parent = canvas

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "SurfaceGui"
    surfaceGui.Adornee = canvas
    surfaceGui.Parent = canvas
    
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.Name = "ClickDetector"
    clickDetector.Parent = board
    
    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Text = ""
    button.BackgroundTransparency = 1
    button.Size = UDim2.new(1,0,1,0)
    button.Parent = surfaceGui

    canvas.Parent = board
  end
  
  local currentZIndex = board:FindFirstChild("CurrentZIndex")

  if currentZIndex == nil then
    currentZIndex = Instance.new("NumberValue")
    currentZIndex.Value = 0
    currentZIndex.Name = "CurrentZIndex"
    currentZIndex.Parent = board
  end
end

function MetaBoard.CreateWorldLine(worldLineType, canvas, lineInfo, zIndex)

  local function lerp(a, b, c)
    return a + (b - a) * c
  end

  -- TODO dealing with aspect ratio is gross, figure out square coordinates, similar to GUI

  if worldLineType == "HandleAdornments" then
    local aspectRatio = canvas.Size.X / canvas.Size.Y
    local yStuds = canvas.Size.Y

    local boxHandle = Instance.new("BoxHandleAdornment")
    boxHandle.SizeRelativeOffset =
      Vector3.new(
        lerp(1,-1,lineInfo.Centre.X/aspectRatio),
        lerp(1,-1,lineInfo.Centre.Y),
        1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
    boxHandle.Size =
      Vector3.new(
        lineInfo.Length * yStuds,
        lineInfo.ThicknessYScale * yStuds,
        Config.WorldLine.ZThicknessStuds)
    boxHandle.CFrame = CFrame.Angles(0,0,lineInfo.RotationRadians)
    boxHandle.Color3 = lineInfo.Color
    

    local startHandle = Instance.new("CylinderHandleAdornment")
    startHandle.SizeRelativeOffset =
      Vector3.new(
        lerp(1,-1,lineInfo.Start.X/aspectRatio),
        lerp(1,-1,lineInfo.Start.Y),
        1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
    startHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
    startHandle.Height = Config.WorldLine.ZThicknessStuds
    startHandle.Color3 = lineInfo.Color

    local stopHandle = Instance.new("CylinderHandleAdornment")
    stopHandle.SizeRelativeOffset =
      Vector3.new(
        lerp(1,-1,lineInfo.Stop.X/aspectRatio),
        lerp(1,-1,lineInfo.Stop.Y),
        1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
    stopHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
    stopHandle.Height = Config.WorldLine.ZThicknessStuds
    stopHandle.Color3 = lineInfo.Color

    startHandle.Parent = boxHandle
    stopHandle.Parent = boxHandle

    startHandle.Adornee = canvas
    stopHandle.Adornee = canvas
    boxHandle.Adornee = canvas

    return boxHandle
  end

  error(worldLineType.." world line type not implemented")
end

function MetaBoard.DrawWorldLine(player, board, lineInfo)
  local curve = board.Canvas.Curves:FindFirstChild(lineInfo.CurveName)
  if curve == nil then
    curve = Instance.new("Folder")
    curve.Name = lineInfo.CurveName
    curve:SetAttribute("AuthorUserId", player.UserId)
    board.CurrentZIndex.Value += 1
    curve:SetAttribute("ZIndex", board.CurrentZIndex.Value)
    curve.Parent = board.Canvas.Curves
  end

  local lineHandle = MetaBoard.CreateWorldLine("HandleAdornments", board.Canvas, lineInfo, board.CurrentZIndex.Value)


  LineInfo.StoreInfo(lineHandle, lineInfo)
  lineHandle.Parent = curve
end

function MetaBoard.EraseWorldLine(board, lineInfo, curveName)
  local curve = board.Canvas.Curves:FindFirstChild(curveName)
  if curve == nil then
    error(lineInfo.CurveName.." not found")
  end

  for _, lineHandle in ipairs(curve:GetChildren()) do
    local lineHandleInfo = LineInfo.ReadInfo(lineHandle)
    if 
      lineHandleInfo.Start == lineInfo.Start and
      lineHandleInfo.Stop == lineInfo.Stop and
      lineHandleInfo.ThicknessYScale == lineInfo.ThicknessYScale
    then
      lineHandle:Destroy()

      if #curve:GetChildren() == 0 then
        curve:Destroy()
      end
      return
    end
  end
end

function MetaBoard.DeleteWorldCurve(board, curveName)
  local curve = board.Canvas.Curves:FindFirstChild(curveName)

  if curve then
    curve:Destroy()
  end
end

return MetaBoard