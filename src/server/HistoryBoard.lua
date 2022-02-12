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

        if not board:FindFirstChild("ClearCount") then continue end
        local clearCount = board.ClearCount.Value
        if clearCount == 0 then continue end

        -- Create a blank board to be replicated
        local blankBoard = if board:IsA("BasePart") then board:Clone() else board.PrimaryPart:Clone()
        local light = blankBoard:FindFirstChild("SurfaceLight"):Clone()
        blankBoard:ClearAllChildren()
        light.Parent = blankBoard

        local clearCountMax = clearCount

        while clearCount >= 1 do
            local boardKeyWithCount = Persistence.KeyForHistoricalBoard(board, clearCount)
            
            local boardClone = blankBoard:Clone()
            boardClone.Name = board.Name .. ":" .. clearCount
            
            local boardSize = if boardClone:IsA("BasePart") then boardClone.Size else boardClone.PrimaryPart.Size
            
            local boardCFrame = board:GetPivot()
            local offsetCFrame = CFrame.new(0, 0, 40 * (clearCountMax - clearCount + 1))
            boardCFrame = boardCFrame:ToWorldSpace(offsetCFrame)
            boardClone:PivotTo(boardCFrame)
            boardClone.Parent = game.Workspace
            MetaBoard.InitBoard(boardClone)
            
            Persistence.Restore(boardClone, boardKeyWithCount)
            
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