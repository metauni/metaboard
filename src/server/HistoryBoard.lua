local CollectionService = game:GetService("CollectionService")
local PlayersService = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)

local MetaBoard, Persistence

local HistoryBoard = {}
HistoryBoard.__index = HistoryBoard

function HistoryBoard.Init()
    MetaBoard = require(script.Parent.MetaBoard)
    Persistence = require(script.Parent.Persistence)
    HistoryBoard.CreateBoards()
end

local function asyncWaitTime()
    return 60/( 60 + 10 * #PlayersService:GetPlayers() )
end

function HistoryBoard.CreateBoards()
    local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)
    local boards = CollectionService:GetTagged(Config.BoardTagHistory)

    local waitTime = asyncWaitTime()

    for _, board in ipairs(boards) do
        if not board:FindFirstChild("PersistId") then continue end
        if not CollectionService:HasTag(board, Config.BoardTag) then continue end

        board:WaitForChild("HasLoaded")
        while not board.HasLoaded.Value do
            task.wait(2)
        end
        
        local boardKey = Persistence.KeyForBoard(board)
        local clearCount = 1
        
        while true do
            local boardKeyWithCount = boardKey .. ":" .. clearCount
            
            local success, boardJSON = pcall(function()
                return DataStore:GetAsync(boardKeyWithCount)
            end)
            if not success then
                print("GetAsync fail for " .. boardKeyWithCount)
                break
            end
            
            -- We have hit the last historical board
            if boardJSON == nil then break end
            
            clearCount += 1
            task.wait(waitTime)
        end
        
        local clearCountMax = clearCount - 1
        if clearCountMax == 0 then continue end
        
        -- Load the boards in reverse order
        clearCount = clearCountMax
        
        -- Create a blank board to be replicated
        local blankBoard = if board:IsA("BasePart") then board:Clone() else board.PrimaryPart:Clone()
        local light = blankBoard:FindFirstChild("SurfaceLight"):Clone()
        blankBoard:ClearAllChildren()
        light.Parent = blankBoard

        while clearCount >= 1 do
            local boardKeyWithCount = boardKey .. ":" .. clearCount
            
            local boardClone = blankBoard:Clone()
            boardClone.Name = board.Name .. ":" .. clearCount
            
            local boardSize = if boardClone:IsA("BasePart") then boardClone.Size else boardClone.PrimaryPart.Size
            
            local boardCFrame = board:GetPivot()
            local offsetCFrame = CFrame.new(0, 0, 40 * (clearCountMax - clearCount + 1))
            boardCFrame = boardCFrame:ToWorldSpace(offsetCFrame)
            boardClone:PivotTo(boardCFrame)
            boardClone.Parent = game.Workspace
            MetaBoard.InitBoard(boardClone)
            
            Persistence.Restore(boardClone, boardKeyWithCount, false)
            
            local region = Region3.new(boardCFrame.Position - Vector3.new(50,50,50), boardCFrame.Position + Vector3.new(50,50,50))
            workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
            
            local yMargin = 30
            local terrainOffset = CFrame.new(0, -(0.5*boardSize.Y + 0.5*yMargin), 0)
            workspace.Terrain:FillBlock(boardCFrame, boardSize + Vector3.new(40,yMargin,40), Enum.Material.Air)
            workspace.Terrain:FillBlock(boardCFrame:ToWorldSpace(terrainOffset), Vector3.new(boardSize.X + 40, 20, boardSize.Z + 45), Config.HistoryBoard.Material)
            
            clearCount -= 1
            task.wait(waitTime)
        end
        
        local boardPersist = board:FindFirstChild("PersistId")
        boardPersist:Destroy()
    end
end

return HistoryBoard