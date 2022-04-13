-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)


local function kNearestBoardsFilter(boards, pos, k)
  local kNearest = table.create(k, nil)
  local filter = {}

  for i=1, k do
    local minSoFar = math.huge
    local nearestBoard = nil
    for _, board in ipairs(boards) do
      if filter[board] then continue end

      local distance = (board:SurfaceCFrame().Position - pos).Magnitude
      if distance < minSoFar then
        nearestBoard = board
        minSoFar = distance
      end
    end
    
    if nearestBoard then
      table.insert(kNearest, nearestBoard)
      filter[nearestBoard] = true
    else
      break
    end
  end

  return filter
end

return function (boards)

  local character do
    character = Players.LocalPlayer.Character
    if character == nil then
      character = Players.LocalPlayer.CharacterAdded:Wait()
    end
  end
  
  while true do
    print('Tick')
    local camera = Workspace.CurrentCamera
    
    local isNearEnough = kNearestBoardsFilter(boards, character:GetPivot().Position, Config.MaxLoadedBoards)
    
    for _, board in ipairs(boards) do

      if isNearEnough[board] then
        board:LoadData()
      else
        board:UnloadData()
      end
    end

    task.wait(Config.NearbyBoardsRefreshInterval)
  end
end
