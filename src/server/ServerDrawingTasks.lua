local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DrawingTask = require(Common.DrawingTask)
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local MetaBoard

local LocalPlayer = game:GetService("Players").LocalPlayer

local ServerDrawingTasks = {}
ServerDrawingTasks.__index = ServerDrawingTasks

function ServerDrawingTasks.Init()
  MetaBoard = require(script.Parent.MetaBoard)
end

function ServerDrawingTasks.new(taskKind, player, board)
  return ServerDrawingTasks[taskKind].new(player, board)
end

ServerDrawingTasks.FreeHand = {}
ServerDrawingTasks.FreeHand.__index = ServerDrawingTasks.FreeHand

function ServerDrawingTasks.FreeHand.new(player, board)
  local init = function(state, pos, thicknessYScale, color, curveName)
    state.Author = player
    state.Board = board
    state.ThicknessYScale = thicknessYScale
    state.Color = color
    state.CurveName = curveName
    
    board.CurrentZIndex.Value += 1
    state.ZIndex = board.CurrentZIndex.Value
    
    state.Curve = Instance.new("Folder")
    state.Curve.Name = curveName
    state.Curve:SetAttribute("AuthorUserId", player.UserId)
    state.Curve:SetAttribute("ZIndex", state.ZIndex)
    
    state.Points = {pos}
    local lineInfo = LineInfo.new(pos, pos, state.ThicknessYScale, state.Color)
    local worldLine = MetaBoard.CreateWorldLine("HandleAdornments", state.Board.Canvas, lineInfo, state.ZIndex)
    LineInfo.StoreInfo(worldLine, lineInfo)
    state.Curve.Parent = board.Canvas.Curves
    state.Lines = {worldLine}
    
    worldLine.Parent = state.Curve
  end

  local update = function(state, pos)
    local lineInfo = LineInfo.new(state.Points[#state.Points], pos, state.ThicknessYScale, state.Color)
    local worldLine = MetaBoard.CreateWorldLine("HandleAdornments", state.Board.Canvas, lineInfo, state.ZIndex)
    LineInfo.StoreInfo(worldLine, lineInfo)
    worldLine.Parent = state.Curve

    state.Points[#state.Points+1] = pos
    state.Lines[#state.Lines+1] = worldLine
  end

  local finish = function(state, doSmoothing, smoothedCurvePoints)
    if doSmoothing then
      state.Curve:ClearAllChildren()
      state.Points = smoothedCurvePoints
      state.Lines = {}
      
      for i=1, #smoothedCurvePoints-1 do
        local lineInfo = LineInfo.new(smoothedCurvePoints[i], smoothedCurvePoints[i+1], state.ThicknessYScale, state.Color)
        local worldLine = MetaBoard.CreateWorldLine("HandleAdornments", state.Board.Canvas, lineInfo, state.ZIndex)
        LineInfo.StoreInfo(worldLine, lineInfo)
        worldLine.Parent = state.Curve
      end
    end
    return
  end

  return DrawingTask.new(init, update, finish)
end

ServerDrawingTasks.Line = {}
ServerDrawingTasks.Line.__index = ServerDrawingTasks.Line

function ServerDrawingTasks.Line.new(player, board)
  local init = function(state, pos, thicknessYScale, color, curveName)
    state.Author = player
    state.Board = board
    state.ThicknessYScale = thicknessYScale
    state.Color = color
    state.CurveName = curveName
    
    board.CurrentZIndex.Value += 1
    state.ZIndex = board.CurrentZIndex.Value
    
    state.Curve = Instance.new("Folder")
    state.Curve.Name = curveName
    state.Curve:SetAttribute("AuthorUserId", state.Author.UserId)
    state.Curve:SetAttribute("ZIndex", state.ZIndex)
    
    state.Start = pos
    local lineInfo = LineInfo.new(pos, pos, state.ThicknessYScale, state.Color)
    local worldLine = MetaBoard.CreateWorldLine("HandleAdornments", state.Board.Canvas, lineInfo, state.ZIndex)
    LineInfo.StoreInfo(worldLine, lineInfo)
    state.Curve.Parent = board.Canvas.Curves
    state.Line = worldLine
    
    worldLine.Parent = state.Curve
  end

  local update = function(state, pos)
    local lineInfo = LineInfo.new(state.Start, pos, state.ThicknessYScale, state.Color)
    local worldLine = MetaBoard.CreateWorldLine("HandleAdornments", state.Board.Canvas, lineInfo, state.ZIndex)
    LineInfo.StoreInfo(worldLine, lineInfo)
    state.Line:SetAttribute("RemoverUserId", state.Author.UserId)
    state.Line:Destroy()
    worldLine.Parent = state.Curve
    state.Line = worldLine
  end

  local finish = function(state) return end

  return DrawingTask.new(init, update, finish)
end

ServerDrawingTasks.Erase = {}
ServerDrawingTasks.Erase.__index = ServerDrawingTasks.Erase

function ServerDrawingTasks.Erase.RemoveLines(board, curveLineInfoBundles)
  for curveName, lineInfos in pairs(curveLineInfoBundles) do
    local curve = board.Canvas.Curves:FindFirstChild(curveName)

    if curve then
      for _, lineHandle in ipairs(curve:GetChildren()) do
        local lineHandleInfo = LineInfo.ReadInfo(lineHandle)
        for _, lineInfo in ipairs(lineInfos) do
          if 
            lineHandleInfo.Start == lineInfo.Start and
            lineHandleInfo.Stop == lineInfo.Stop and
            lineHandleInfo.ThicknessYScale == lineInfo.ThicknessYScale
          then
            lineHandle:Destroy()
          end
        end
      end

      if #curve:GetChildren() == 0 then
        curve:Destroy()
      end
    end
  end
end


function ServerDrawingTasks.Erase.new(player, board)
  local init = function(state, curveLineInfoBundles)
    state.Author = player
    state.Board = board
    ServerDrawingTasks.Erase.RemoveLines(state.Board, curveLineInfoBundles)
  end

  local update = function(state, curveLineInfoBundles)
    ServerDrawingTasks.Erase.RemoveLines(state.Board, curveLineInfoBundles)
  end

  local finish = update

  return DrawingTask.new(init, update, finish)
end


return ServerDrawingTasks