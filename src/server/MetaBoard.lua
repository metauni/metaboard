local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.MetaBoardConfig)
local LineInfo = require(Common.LineInfo)

local DrawLineRemoteEvent = Common.Remotes.DrawLine
local EraseLineRemoteEvent = Common.Remotes.EraseLine
local UndoCurveRemoteEvent = Common.Remotes.UndoCurve

local MetaBoard = {}
MetaBoard.__index = MetaBoard

function MetaBoard.Init()

  for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
    MetaBoard.InitBoard(board)
  end

  CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(MetaBoard.InitBoard)

  DrawLineRemoteEvent.OnServerEvent:Connect(function(player, board, lineInfo)
    MetaBoard.DrawWorldLine(player, board, lineInfo)
  end)
  
  EraseLineRemoteEvent.OnServerEvent:Connect(function(player, board, lineInfo)
    MetaBoard.EraseWorldLine(board, lineInfo)
  end)

  UndoCurveRemoteEvent.OnServerEvent:Connect(function(player, board, curveName)
    MetaBoard.DeleteWorldCurve(board, curveName)
  end)

  print("MetaBoard Server initialized")
end

function MetaBoard.InitBoard(board)

  if board:FindFirstChild("Curves") == nil then
      local curvesFolder = Instance.new("Folder")
      curvesFolder.Name = "Curves"
      curvesFolder.Parent = board
  end
  
  if board:FindFirstChild("CurrentZIndex") == nil then
    local CurrentZIndex = Instance.new("NumberValue")
    CurrentZIndex.Value = 0
    CurrentZIndex.Name = "CurrentZIndex"
    CurrentZIndex.Parent = board
  end
end

local function lerp(a, b, c)
	return a + (b - a) * c
end

function MetaBoard.CreateWorldLine(worldLineType, board, lineInfo, zIndex)

  -- TODO dealing with aspect ratio is gross, figure out square coordinates, similar to GUI

  if worldLineType == "HandleAdornments" then
    local aspectRatio = board.Size.X / board.Size.Y
    local yStuds = board.Size.Y

    local boxHandle = Instance.new("BoxHandleAdornment")
    boxHandle.SizeRelativeOffset =
      Vector3.new(
        lerp(1,-1,lineInfo.Centre.X/aspectRatio),
        lerp(1,-1,lineInfo.Centre.Y),
        -- TODO figure out why this is negative
        -1 - (Config.WorldLine.ZThicknessStuds / board.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
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
        -1 - (Config.WorldLine.ZThicknessStuds / board.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
    startHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
    startHandle.Height = Config.WorldLine.ZThicknessStuds
    startHandle.Color3 = lineInfo.Color

    local stopHandle = Instance.new("CylinderHandleAdornment")
    stopHandle.SizeRelativeOffset =
      Vector3.new(
        lerp(1,-1,lineInfo.Stop.X/aspectRatio),
        lerp(1,-1,lineInfo.Stop.Y),
        -1 - (Config.WorldLine.ZThicknessStuds / board.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
    stopHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
    stopHandle.Height = Config.WorldLine.ZThicknessStuds
    stopHandle.Color3 = lineInfo.Color

    startHandle.Parent = boxHandle
    stopHandle.Parent = boxHandle
    -- TODO bad, this function should just make the line, not addornee/parent it
    startHandle.Adornee = board
    stopHandle.Adornee = board

    return boxHandle
  end

  error(worldLineType.." world line type not implemented")
end

function MetaBoard.DrawWorldLine(player, board, lineInfo)
  local zIndex
  local curve = board.Curves:FindFirstChild(lineInfo.CurveName)
  if curve == nil then
    curve = Instance.new("Folder")
    curve.Name = lineInfo.CurveName
    curve:SetAttribute("AuthorUserId", player.UserId)
    curve.Parent = board.Curves

    board.CurrentZIndex.Value += 1
  end

  zIndex = board.CurrentZIndex.Value

  local lineHandle = MetaBoard.CreateWorldLine("HandleAdornments", board, lineInfo, zIndex)


  lineHandle.Parent = curve
  LineInfo.StoreInfo(lineHandle, lineInfo)
  lineHandle:SetAttribute("ZIndex", zIndex)
  
  lineHandle.Adornee = board
end

function MetaBoard.EraseWorldLine(board, lineInfo)
  local curve = board.Curves:FindFirstChild(lineInfo.CurveName)
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
  local curve = board.Curves:FindFirstChild(curveName)

  if curve then
    curve:Destroy()
  end
end

return MetaBoard