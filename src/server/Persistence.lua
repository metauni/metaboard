-- NOTES
-- On server shutdown there is a `30sec` hard limit, within which all boards which have changed
-- after the last autosave must be saved if we are to avoid dataloss. Given that `SetAsync` has a rate
-- limit of `60 + numPlayers * 10` calls per minute, and assuming we can spend at most `20sec` on boards,
-- that means we can support at most `20 + numPlayers * 3` changed boards since the last autosave if we are
-- to avoid dataloss, purely due to rate limits. A full board costs about `1.2sec` to save under adversarial
-- conditions (i.e. many other full boards). So to be safe we can afford at most `16` changed boards per
-- autosave period.

local CollectionService = game:GetService("CollectionService")
local HTTPService = game:GetService("HttpService")
local PlayersService = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)

local Persistence = {}
Persistence.__index = Persistence

local function isPrivateServer()
	return game.PrivateServerId ~= ""
end

-- GetAsync and SetAsync have a rate limit of 60 + numPlayers * 10 calls per minute
-- (see https://developer.roblox.com/en-us/articles/Data-store)
-- 60/waitTime < 60 + numPlayers * 10 => waitTime > 60/( 60 + numPlayers * 10 )

-- In an experiment with 124 full persistent boards, all updated, we averaged
-- 1.13 seconds per board to store (i.e. 124 boards stored in 140sec)
local function asyncWaitTime()
	return 60/( 60 + 10 * #PlayersService:GetPlayers() )
end

function Persistence.Init()

	Persistence.RestoreAllCoroutinesPocket = {}
	Persistence.RestoreAllCoroutinesNormal = {}
	Persistence.FetchedBoardData = {}

	game:BindToClose(Persistence.StoreAll)
	
	Persistence.RestoreAll()

	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveInterval)
			Persistence.StoreAll()
		end
	end)
end

function Persistence.RestoreAll()
	-- We are guaranteed that any requests made at this rate
	-- will not decrease our budget, so our strategy is on startup
	-- to spend down our budget to near zero and then throttle to this speed
	local waitTime = asyncWaitTime()

	local boards = CollectionService:GetTagged(Config.BoardTag)
	for _, board in ipairs(boards) do
		local persistId = board:FindFirstChild("PersistId")
		if persistId == nil then continue end

		local boardKey = Persistence.KeyForBoard(board)
		task.spawn(Persistence.Fetch, board, boardKey)

		local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
		if budget < 100 then
			print("[MetaBoard] GetAsync budget hit, throttling")
			task.wait(waitTime)
		end
	end

	task.spawn(function()
		local restoreAllTask = coroutine.create(Persistence.RestoreAllTask)
	
		while coroutine.status(restoreAllTask) ~= "dead" do
			local success, result = coroutine.resume(restoreAllTask)
			if not success then
				print("[MetaBoard] Main RestoreAll task failed to resume: ".. result)
			end

			task.wait(Config.RestoreAllIntermission)
		end

		print("[MetaBoard] Restore All complete")
	end)
end

function Persistence.RestoreAllTask()
	-- Loading boards can take significant time (sometimes several minutes) and places
	-- significant load on the server. To keep the server responsive (e.g. to teleport
	-- requests) we explicitly manage the loading process using coroutines

	-- Our first step is create all the tasks and populate the list of coroutines
	local boards = CollectionService:GetTagged(Config.BoardTag)
	local pocketPortalBoards = {}
	local normalBoards = {}

	for _, board in ipairs(boards) do
		local persistId = board:FindFirstChild("PersistId")
		if persistId == nil then continue end

		if CollectionService:HasTag(board.Parent, "metapocket") then
			table.insert(pocketPortalBoards, board)
		else
			table.insert(normalBoards, board)
		end
	end
	
	-- We do boards on pocket portals first
	for _, board in ipairs(pocketPortalBoards) do
		local boardTask = coroutine.create(Persistence.Restore)
		table.insert(Persistence.RestoreAllCoroutinesPocket, boardTask)
	
		local boardKey = Persistence.KeyForBoard(board)
		local success, result = coroutine.resume(boardTask, board, boardKey)

		if not success then
			print("[MetaBoard] Problem resuming RestoreAll coroutine")
		end
	end

	-- Normal boards
	for _, board in ipairs(normalBoards) do
		local boardTask = coroutine.create(Persistence.Restore)
		table.insert(Persistence.RestoreAllCoroutinesNormal, boardTask)

		local boardKey = Persistence.KeyForBoard(board)
		local success, result = coroutine.resume(boardTask, board, boardKey)
		
		if not success then
			print("[MetaBoard] Problem resuming RestoreAll coroutine")
		end
	end

	local coroutineLists = { Persistence.RestoreAllCoroutinesPocket, 
							Persistence.RestoreAllCoroutinesNormal }
	
	local numBoardsProcessed = 0

	for _, coroutineList in ipairs(coroutineLists) do
		while #coroutineList > 0 do
			local finishedTasks = {}
	
			for i = 1, #coroutineList do
				local boardTask = coroutineList[i]
				local status = coroutine.status(boardTask)
				if status == "suspended" then
					local success, result = coroutine.resume(boardTask)

					if not success then
						print("[MetaBoard] Failed to resume Persistence.Restore: "..result)
					end

					numBoardsProcessed += 1
				elseif status == "dead" then
					table.insert(finishedTasks, boardTask)
				else
					print("[MetaBoard] Restore coroutine in unexpected status: "..status)
				end

				if numBoardsProcessed >= Config.RestoreAllNumSimultaneousBoards then
					numBoardsProcessed = 0
					coroutine.yield()
				end
			end

			for _, boardTask in ipairs(finishedTasks) do
				for i, t in ipairs(coroutineList) do
					if t == boardTask then
						table.remove(coroutineList, i)
					end
				end
			end
		end
	end
end

function Persistence.StoreAll()
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
	--local fastWaitTime = 0.1
	local budget
	
	for _, board in ipairs(changedBoards) do
		budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
		print("[Persistence] SetAsync budget is ".. budget)
		task.spawn(Persistence.Save, board)

		--if budget < 100 then
		--    print("[Persistence] SetAsync budget hit, throttling")
		task.wait(waitTime)
		--else
		--    task.wait(fastWaitTime)
		--end
	end

	local elapsedTime = math.floor(100 * (tick() - startTime))/100
	
	--if #changedBoards > 0 then
	--    print("[Persistence] stored ".. #changedBoards .. " boards in ".. elapsedTime .. "s.")
	--end
end

function Persistence.KeyForBoard(board)
	local boardKey = "metaboard" .. tostring(board.PersistId.Value)

	-- If we are in a private server the key is prefixed by the 
	-- private server's ID
	if isPrivateServer() then
		if game.PrivateServerOwnerId ~= 0 then
			boardKey = "ps" .. game.PrivateServerOwnerId .. ":" .. boardKey
		else
			-- We are in a private server created using TeleportService:ReserveServer
			-- we assume in this case that someone has created a StringValue in the workspace
			-- called PrivateServerKey
			local idValue = workspace:FindFirstChild("PrivateServerKey")
			if idValue and idValue:IsA("StringValue") then
				boardKey = "ps" .. idValue.Value .. ":" .. boardKey
			else
				boardKey = "ps:" .. boardKey
			end
		end
	end

	if string.len(boardKey) > 50 then
		print("[Persistence] ERROR: Board key length exceeds DataStore limit.")
	end

	return boardKey
end

function Persistence.SuffixForCurveSegment(segmentId)
	return ":c" .. segmentId
end

function Persistence.KeyForHistoricalBoard(board, clearCount)
	local boardKey = Persistence.KeyForBoard(board)
	return boardKey .. ":" .. clearCount
end

-- Populates a dictionary with the DataStore values for this board
function Persistence.Fetch(board, boardKey)
	local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

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
			local boardCurvesKey = boardKey .. Persistence.SuffixForCurveSegment(curveSegmentId)

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
				return
			end
		end

		if string.len(curveJSON) == 0 then
			print("[Persistence] Empty curveJSON")
			return
		end

		curves = HTTPService:JSONDecode(curveJSON)
	end

	if not curves then
		print("[Persistence] Failed to get curve data")
		return
	end

	local data = { BoardData = boardData, Curves = curves }
	Persistence.FetchedBoardData[board] = data
end

-- Restores an empty board to the contents stored in the DataStore
-- with the given persistence ID string. This is meant to be resumed until it
-- finishes, see RestoreAll.
function Persistence.Restore(board, boardKey)
	while Persistence.FetchedBoardData[board] == nil do
		if board.HasLoaded.Value == true then
			return
		end
	
		coroutine.yield("no data")
	end

	local boardData = Persistence.FetchedBoardData[board].BoardData
	local curves = Persistence.FetchedBoardData[board].Curves
	Persistence.FetchedBoardData[board] = nil

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
			coroutine.yield("line count")
		end
	end

	board.HasLoaded.Value = true

	-- Count number of lines
	--lineCount = 0
	--for curIndex, curveData in ipairs(curves) do
	--    lineCount += #curveData.Lines
	--end
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
	-- case we split it across several keys
	local curveSegmentId = 0
	local currPos = 0
	local segmentSize = 3500000 -- max value in a key is 4Mb

	-- print("[Persistence] Length of curveJSON = " .. string.len(curveJSON))

	while currPos < string.len(curveJSON) do
		curveSegmentId += 1
		local boardCurvesKey = boardKey .. Persistence.SuffixForCurveSegment(curveSegmentId)
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