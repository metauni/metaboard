local CollectionService = game:GetService("CollectionService")
local HTTPService = game:GetService("HttpService")
local PlayersService = game:GetService("Players")
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

-- GetAsync and SetAsync have a rate limit of 60 + numPlayers * 10 calls per minute
-- (see https://developer.roblox.com/en-us/articles/Data-store)
-- 60/waitTime < 60 + numPlayers * 10 => waitTime > 60/( 60 + numPlayers * 10 )

-- In an experiment with 124 full persistent boards, all updated, we averaged
-- 1.13 seconds per board to store (i.e. 124 boards stored in 140sec)
local function asyncWaitTime()
    return 60/( 60 + 10 * #PlayersService:GetPlayers() )
end

local function storeAll()
    local startTime = tick()
	local boards = CollectionService:GetTagged(Config.BoardTag)
	
    -- Find persistent boards which have been changed since the last save
    local changedBoards = {}
	for _, board in ipairs(boards) do
		if board:FindFirstChild("PersistId") and board.ChangeUid.Value ~= "" then
			table.insert(changedBoards, board)
		end
	end

    local waitTime = asyncWaitTime()
    
	for _, board in ipairs(changedBoards) do
		task.spawn(Persistence.Save, board)
        task.wait(waitTime)
	end

    local elapsedTime = math.floor(100 * (tick() - startTime))/100
    
    --if #changedBoards > 0 then
    --    print("[Persistence] stored ".. #changedBoards .. " boards in ".. elapsedTime .. "s.")
    --end
end

function Persistence.Init()
    MetaBoard = require(script.Parent.MetaBoard)

    -- Restore all boards
    local boards = CollectionService:GetTagged(Config.BoardTag)

    local waitTime = asyncWaitTime()

    for _, board in ipairs(boards) do
		local persistId = board:FindFirstChild("PersistId")
        if persistId then
            local boardKey = Persistence.KeyForBoard(board)
            task.spawn(Persistence.Restore, board, boardKey)
            task.wait(waitTime)
        end
	end

    -- Store all boards on shutdown
	game:BindToClose(storeAll)
	
	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveInterval)
			storeAll()
		end
	end)
end

function Persistence.KeyForBoard(board)
	local boardKey = "metaboard" .. tostring(board.PersistId.Value)

	-- If we are in a private server the key is prefixed by the 
	-- private server's ID
	if isPrivateServer() then
		boardKey = "ps" .. game.PrivateServerOwnerId .. ":" .. boardKey
	end

    if string.len(boardKey) > 50 then
        print("[Persistence] ERROR: Board key length exceeds DataStore limit.")
    end

	return boardKey
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
    
    local worldLine = MetaBoard.CreateWorldLine(Config.WorldBoard.LineType, canvas, lineInfo, zIndex)

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
    -- TODO, do in general
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
        if not line:GetAttribute("Hidden") then
            table.insert(lines, serialiseLine(line))
        end
    end

    curveData.Lines = lines

    if #lines > 0 then
        return curveData
    else
        return nil
    end
end

-- Restores an empty board to the contents stored in the DataStore
-- with the given persistence ID string.
function Persistence.Restore(board, boardKey)
    local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)
    local startTime = tick()

    if not DataStore then
        print("[Persistence] DataStore not loaded")
        return
    end

    if #board.Canvas.Curves:GetChildren() > 0 then
        print("[Persistence] Called Restore on a nonempty board ".. boardKey)
        return
    end

    -- Get the value stored for the given persistId. Note that this may not
    -- have been set, which is fine
    local success, boardJSON
    success, boardJSON = pcall(function()
        return DataStore:GetAsync(boardKey)
    end)
    if not success then
        print("[Persistence] GetAsync fail for " .. boardKey .. " " .. boardJSON)
        return
    end

    -- Return if this board has not been stored
    if not boardJSON then
        board.HasLoaded.Value = true
        return
    end

	local boardData = HTTPService:JSONDecode(boardJSON)

    if not boardData then
        print("[Persistence] Failed to decode JSON")
        return
    end

    local curves
    if not boardData.numCurveSegments then
        -- For old versions the curve data is stored under the main key
        -- print("[Persistence] DEBUG: loading from old datastructure")
        curves = boardData.Curves
    else
        -- print("[Persistence] DEBUG: loading from new datastructure")
        local curveJSON = ""
        local boardCurvesJSON

        for curveSegmentId = 1, boardData.numCurveSegments do
            local boardCurvesKey = boardKey .. ":" .. curveSegmentId

            success, boardCurvesJSON = pcall(function()
                return DataStore:GetAsync(boardCurvesKey)
            end)
            if not success then
                print("[Persistence] GetAsync fail for " .. boardCurvesKey)
                return
            end

            if boardCurvesJSON then
                curveJSON = curveJSON .. boardCurvesJSON
            else
                print("[Persistence] Got bad value for " .. boardCurvesKey )
            end
        end

        curves = HTTPService:JSONDecode(curveJSON)
    end

    if not curves then
        print("[Persistence] Failed to get curve data")
        return
    end

    if boardData.ClearCount and board:FindFirstChild("ClearCount") then
        board.ClearCount.Value = boardData.ClearCount
    end

    if boardData.CurrentZIndex then
        if board.CurrentZIndex then
            board.CurrentZIndex.Value = boardData.CurrentZIndex
        end
    end

    -- The board data is a table, each entry of which is a dictionary defining a curve
    local lineCount = 0

    for curIndex, curveData in ipairs(curves) do
        local curve = deserialiseCurve(board.Canvas, curveData)
        curve.Parent = board.Canvas.Curves
        lineCount += #curveData.Lines

        if lineCount > Config.LinesLoadedBeforeWait then
            lineCount = 0
            -- Give control back to the engine until the next frame,
            -- then continue loading, to prevent low frame rates on
            -- server startup with many persistent boards
            task.wait()
        end
    end

    board.HasLoaded.Value = true

    -- Count number of lines
    lineCount = 0
    for curIndex, curveData in ipairs(curves) do
        lineCount += #curveData.Lines
    end

    local elapsedTime = math.floor(100 * (tick() - startTime))/100
    -- print("[Persistence] Restored " .. boardKey .. " " .. #curves .. " curves, " .. lineCount .. " lines, " .. string.len(boardJSON) .. " bytes in ".. elapsedTime .. "s.")
end

function Persistence.Save(board)
    -- Do not store boards that have not changed
    local preSaveUid = board.ChangeUid.Value
	if preSaveUid == "" then return end

    local boardKey = Persistence.KeyForBoard(board)
    Persistence.Store(board, boardKey)

    -- Since SetAsync yields we compare preSaveUid and board.ChangeUid
    -- to assess whether the board was changed during the save process
	-- If the board did not change during the save process,
    -- then it is safe to mark it as saved
    if preSaveUid == board.ChangeUid.Value then
        board.ChangeUid.Value = ""
    end
end

-- Stores a given board to the DataStore with the given ID
-- Note that this may be called to save historical boards in 
-- _before_ Persistence.Init has been run
function Persistence.Store(board, boardKey)
    local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

    if not DataStore then
        print("[Persistence] DataStore not loaded")
        return
    end

    local startTime = tick()

    local boardData = {}
    local curves = {}
    for _, curve in ipairs(board.Canvas.Curves:GetChildren()) do
        local curveData = serialiseCurve(curve)
        if curveData then
            table.insert(curves, curveData)
        end
    end

    if board:FindFirstChild("ClearCount") then
        boardData.ClearCount = board.ClearCount.Value
    end

    if board:FindFirstChild("CurrentZIndex") then
        boardData.CurrentZIndex = board.CurrentZIndex.Value
    end

    local curveJSON = HTTPService:JSONEncode(curves)

    if not curveJSON then
        print("[Persistence] Curve JSON encoding failed")
        return
    end

    local success, errormessage

    -- The curveJSON may be too big to fit in one key, in which
    -- case we split it across several keys, which have the form
    -- "boardKey" .. ":" .. curveSegmentId
    local curveSegmentId = 0
    local currPos = 0
    local segmentSize = 3500000 -- max value in a key is 4Mb

    -- print("[Persistence] Length of curveJSON = " .. string.len(curveJSON))

    while currPos < string.len(curveJSON) do
        curveSegmentId += 1
        local boardCurvesKey = boardKey .. ":" .. curveSegmentId
        local boardCurvesJSON = string.sub(curveJSON, currPos + 1, currPos + segmentSize)

        print("[Persistence] Writing to key " .. boardCurvesKey)
        success, errormessage = pcall(function()
            return DataStore:SetAsync(boardCurvesKey, boardCurvesJSON)
        end)
        if not success then
            print("[Persistence] SetAsync fail for " .. boardCurvesKey .. " with ".. errormessage)
            return
        end

        currPos += segmentSize
    end

    boardData.numCurveSegments = curveSegmentId

    local boardJSON = HTTPService:JSONEncode(boardData)

    if not boardJSON then
        print("[Persistence] Board JSON encoding failed")
        return
    end

    success, errormessage = pcall(function()
        return DataStore:SetAsync(boardKey, boardJSON)
    end)
    if not success then
        print("[Persistence] SetAsync fail for " .. boardKey .. " with " .. string.len(boardJSON) .. " bytes ".. errormessage)
        return
	end

    local elapsedTime = math.floor(100 * (tick() - startTime))/100

    print("[Persistence] Stored " .. boardKey .. " in ".. elapsedTime .."s.")
end

return Persistence
