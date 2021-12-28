local CollectionService = game:GetService("CollectionService")
local HTTPService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)

local MetaBoard

local Persistence = {}
Persistence.__index = Persistence

local function isPrivateServer()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

function Persistence.Init()
    MetaBoard = require(script.Parent.MetaBoard)
    
    local function keyForBoard(board)
        local boardKey = "metaboard" .. tostring(board.PersistId.Value)

        -- If we are in a private server the key is prefixed by the 
        -- private server's ID
        if isPrivateServer() then
            boardKey = "ps" .. game.PrivateServerOwnerId .. ":" .. boardKey
        end

        return boardKey
    end

    -- Restore all boards
    local boards = CollectionService:GetTagged(Config.BoardTag)

    for _, board in ipairs(boards) do
		local persistId = board:FindFirstChild("PersistId")
        if persistId and persistId:IsA("IntValue") then
            -- Restore this board and all its subscribers
            local boardKey = keyForBoard(board)

            local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
            for _, subscriber in ipairs(subscriberFamily) do
                Persistence.Restore(subscriber, boardKey)
            end
        end
	end

    -- Store all boards on shutdown
    game:BindToClose(function()
        local boardsClose = CollectionService:GetTagged(Config.BoardTag)

        for _, board in ipairs(boardsClose) do
            local persistId = board:FindFirstChild("PersistId")
            if persistId and persistId:IsA("IntValue") then
                Persistence.Store(board, keyForBoard(board))
            end
        end
    end)
end

local function serialiseVector2(v)
    local vData = {}
    vData.X = v.X
    vData.Y = v.Y
    return vData
end

local function deserialiseVector2(vData)
    return Vector2.new(vData.X, vData.Y)
end

local function serialiseColor3(c)
    local cData = {}
    cData.R = c.R
    cData.G = c.G
    cData.B = c.B
    return cData
end

local function deserialiseColor3(cData)
    return Color3.new(cData.R, cData.G, cData.B)
end

local function deserialiseLine(canvas, lineData, zIndex)
    local start = deserialiseVector2(lineData.Start)
    local stop = deserialiseVector2(lineData.Stop)
    local color = deserialiseColor3(lineData.Color)
    local thicknessYScale = lineData.ThicknessYScale

    local lineInfo = LineInfo.new(start, stop, thicknessYScale, color)
    
    local worldLine = MetaBoard.CreateWorldLine(Config.WorldLineType, canvas, lineInfo, zIndex)
    LineInfo.StoreInfo(worldLine, lineInfo)

    return worldLine
end

local function serialiseLine(line)
    local lineData = {}
    lineData.Start = serialiseVector2(line:GetAttribute("Start"))
	lineData.Stop = serialiseVector2(line:GetAttribute("Stop"))
	lineData.Color = serialiseColor3(line:GetAttribute("Color"))
	lineData.ThicknessYScale = line:GetAttribute("ThicknessYScale")
    return lineData
end

local function deserialiseCurve(canvas, curveData)
    local curve = Instance.new("Folder")
    curve.Name = curveData.Name
    curve:SetAttribute("AuthorUserId", curveData.AuthorUserId)
    curve:SetAttribute("ZIndex", curveData.ZIndex)
    curve:SetAttribute("CurveType", curveData.CurveType)
    
    for _, lineData in ipairs(curveData.Lines) do
        local line = deserialiseLine(canvas, lineData, curveData.ZIndex)
        line.Parent = curve
    end

    return curve
end

local function serialiseCurve(curve)
    local curveData = {}
    curveData.Name = curve.Name
    curveData.AuthorUserId = curve:GetAttribute("AuthorUserId")
    curveData.ZIndex = curve:GetAttribute("ZIndex")
    curveData.CurveType = curve:GetAttribute("CurveType")

    local lines = {}

    for _, line in ipairs(curve:GetChildren()) do
        table.insert(lines, serialiseLine(line))
    end

    curveData.Lines = lines

    return curveData
end

-- Restores an empty board to the contents stored in the DataStore
-- with the given persistence ID string
function Persistence.Restore(board, boardKey)
    local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

    if not DataStore then
        print("Persistence: DataStore not loaded")
        return
    end

    if #board.Canvas.Curves:GetChildren() > 0 then
        print("Persistence: Called Restore on a nonempty board")
        return
    end

    if string.len(boardKey) >= 50 then
        print("Persistence: board key is too long")
        return
    end

    -- Get the value stored for the given persistId. Note that this may not
    -- have been set, which is fine
    local success, boardJSON = pcall(function()
        return DataStore:GetAsync(boardKey)
    end)
    if not success then
        print("Persistence: Failed to read from DataStore for ID " .. boardKey)
        return
    end

    -- Return if this board has not been stored
    if not boardJSON then
        print("No data for this persistId")
        return
    end

	local boardData = HTTPService:JSONDecode(boardJSON)

    if not boardData then
        print("Persistence: failed to decode JSON")
        return
    end

    local curves = boardData.Curves

    if not curves then
        print("Persistance: failed to get curve data")
        return
    end

    if boardData.CurrentZIndex and board.CurrentZIndex then
        board.CurrentZIndex.Value = boardData.CurrentZIndex
    end

    -- The board data is a table, each entry of which is a dictionary
    -- defining a curve
    for _, curveData in ipairs(curves) do
        local curve = deserialiseCurve(board.Canvas, curveData)
        curve.Parent = board.Canvas.Curves
    end

    --print("Persistence: Successfully restored board " .. boardKey)
end

-- Stores a given board to the DataStore with the given ID
function Persistence.Store(board, boardKey)
    local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

    if not DataStore then
        print("Persistence: DataStore not loaded")
        return
    end

    if string.len(boardKey) >= 50 then
        print("Persistence: board key is too long")
        return
    end

    local boardData = {}
    local curves = {}
    for _, curve in ipairs(board.Canvas.Curves:GetChildren()) do
        local curveData = serialiseCurve(curve)
        table.insert(curves, curveData)
    end

    boardData.Curves = curves

    if board:FindFirstChild("CurrentZIndex") then
        boardData.CurrentZIndex = board.CurrentZIndex.Value
    end

    local boardJSON = HTTPService:JSONEncode(boardData)

    if not boardJSON then
        print("Persistence: Board JSON encoding failed")
        return
    end

    -- TODO pre-empt "value too big" error
    -- print("Persistence: Board JSON length is " .. string.len(boardJSON))

    local success, errormessage = pcall(function()
        return DataStore:SetAsync(boardKey, boardJSON)
    end)
    if not success then
        print("Persistence: Failed to store to DataStore for ID " .. boardKey)
        print(errormessage)
        return
    end

    print("Persistence: Successfully stored board " .. boardKey)
end

return Persistence