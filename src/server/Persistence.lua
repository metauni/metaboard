-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)
local EraseGrid = require(Common.EraseGrid)
local Sift = require(Common.Packages.Sift)
local Array, Set = Sift.Array, Sift.Set

-- Unique value to identify when GetAsync yielded no result
local NothingStored = newproxy(true)

-- GetAsync and SetAsync have a rate limit of 60 + numPlayers * 10 calls per minute
-- (see https://developer.roblox.com/en-us/articles/Data-store)
-- 60/waitTime < 60 + numPlayers * 10 => waitTime > 60/( 60 + numPlayers * 10 )

-- In an experiment with 124 full persistent boards, all updated, we averaged
-- 1.13 seconds per board to store (i.e. 124 boards stored in 140sec)
local function asyncWaitTime()
	return 60 / (60 + 10 * #Players:GetPlayers())
end

local function jsonEncode(input, name: string?)
	local json = HttpService:JSONEncode(input)
	if not json then
		name = name or ""
		error("[Persistence] " .. name .. " JSON encoding failed")
	end

	return json
end

local function jsonDecode(json: string, name: string?)
	local data = HttpService:JSONDecode(json)
	if not data then
		name = name or ""
		error("[Persistence] " .. name .. " JSON decoding failed")
	end

	return data
end

local function set(dataStore: DataStore, key: string, data)
	local success, errormessage = pcall(function()
		return dataStore:SetAsync(key, data)
	end)
	if not success then
		error("[Persistence] SetAsync fail for " .. key .. " with " .. string.len(data) .. " bytes " .. errormessage)
	end
end

local function get(dataStore: DataStore, key: string)
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)
	if not success then
		error("[Persistence] GetAsync fail for " .. key .. " " .. result)
	end

	return result
end

local function store(dataStore, figures, nextFigureZIndex, boardKey)
	--[[
		We store the data of a board across a few keys.
		At "<boardKey>/info", we the json of this table:
			{
				NextFigureZIndex: number,
				ChunkCount: number,
			}

		The rest of the data at "<boardkey>/chunks/1", "<boardkey>/chunks/2" etc.
		Each of these chunks is a newline-separated string of
		figureId-serialisedFigure pairs.

			[<FigureId>, <SerialisedFigure>]
			[<FigureId>, <SerialisedFigure>]
			[<FigureId>, <SerialisedFigure>]

		The purpose of a chunk is to not exceed the 4MB per-key datastore limit.
		Each chunk is divided into individual figure entries (instead of one big
		json dictionary), so that decoding can be yielded until the next frame.

		Incidentally, encoding and decoding this way (each entry separately)
		actually benchmarks *faster* than doing as one 4MB string of json.

	--]]

	local startTime = tick()

	-- Serialise and encode every figureId-figure pair as a length 2 json array

	local chunks = {}
	local jsonEntries = {}

	for figureId, figure in pairs(figures) do
		local serialisedFigure = Figure.Serialise(figure)

		-- Encode as JSON with newline separator at the end
		local entryJson = jsonEncode({ figureId, serialisedFigure }, "SerialisedFigureEntry") .. "\n"

		-- Max storage at single key is 4MB
		if entryJson:len() > Config.ChunkSizeLimit then
			print(("[Persistence] figure %s too large for a single chunk"):format(figureId))
			continue
		end

		table.insert(jsonEntries, entryJson)
	end

	-- Divide the entries into concatenated chunks of maximum length
	-- `Config.ChunkSizeLimit`

	do
		local i = 1
		while i <= #jsonEntries do
			local chunkSize = jsonEntries[i]:len()
			local j = i
			while chunkSize <= Config.ChunkSizeLimit do
				j += 1
				chunkSize += jsonEntries[j]:len()
			end

			-- entries i through j-1 don't exceed the chunk limit when concatenated

			table.insert(chunks, table.concat(jsonEntries, "", i, j - 1))

			i = j
		end
	end

	-- Store the auxiliary info about the board (everything but the figures)
	-- at key "<boardKey>/info"

	local boardAuxiliaryJSON = jsonEncode({
		NextFigureZIndex = nextFigureZIndex,
		ChunkCount = #chunks,
	}, "BoardAuxiliaryJSON (" .. boardKey .. ")")

	set(dataStore, boardKey .. "/info", boardAuxiliaryJSON)

	-- Store all the chunks under indexed-keys using the pattern
	-- "<boardKey>/info/<chunkNumber>"

	local totalBytes = 0
	for i, chunk in ipairs(chunks) do
		totalBytes += chunk:len()
		set(dataStore, boardKey .. "/chunks/" .. tostring(i), chunk)
	end

	print(
		string.format(
			"[Persistence] Stored %d bytes across %d chunks at key %s in %.2fs",
			totalBytes,
			#chunks,
			boardKey,
			tick() - startTime
		)
	)
end

local function fetch(dataStore, boardKey)
	-- Get the value stored for the given persistId. Note that this may not
	-- have been set, which is fine
	local boardInfoJSON = get(dataStore, boardKey .. "/info")

	if not boardInfoJSON then
		return NothingStored
	end

	local boardInfo = jsonDecode(boardInfoJSON, "Board Auxiliary Data")

	local nextFigureZIndex = boardInfo.NextFigureZIndex
	local chunkCount = boardInfo.ChunkCount

	local serialisedFigures = {}
	
	for i = 1, chunkCount do
		local chunk = get(dataStore, boardKey .. "/chunks/" .. tostring(i))
		
		local lastWaitTime = os.clock()
		local j = 1
		while j < chunk:len() do
			local k = chunk:find("\n", j + 1)
			local entry = jsonDecode(chunk:sub(j, k - 1), "Chunk Entry")

			serialisedFigures[entry[1]] = entry[2]

			j = k + 1

			if (os.clock() - lastWaitTime) > Config.JSONDecodeTime then
				task.wait()
				lastWaitTime = os.clock()
			end
		end
	end

	return {
		Figures = serialisedFigures,
		NextFigureZIndex = nextFigureZIndex,
	}
end

local function deserialise(board, serialisedData)
	local figures = {}
	local eraseGrid = EraseGrid.new(board:AspectRatio())

	local lastYieldTime = os.clock()

	for figureId, serialisedFigure in pairs(serialisedData.Figures) do
		local figure = Figure.Deserialise(serialisedFigure)
		figures[figureId] = Figure.Deserialise(serialisedFigure)
		eraseGrid:AddFigure(figureId, figure)

		if (os.clock() - lastYieldTime) > Config.DeserialiseTime then
			coroutine.yield()
			lastYieldTime = os.clock()
		end
	end

	return figures, serialisedData.NextFigureZIndex, eraseGrid
end

local function restoreAll(dataStore, boards)
	-- We are guaranteed that any requests made at this rate
	-- will not decrease our budget, so our strategy is on startup
	-- to spend down our budget to near zero and then throttle to this speed

	-- TODO: shouldn't this be called each time we task.wait? Players could leave
	-- or be added while restoring occurs.
	local waitTime = asyncWaitTime()

	do -- Removes duplicate boards and duplicate persistId
		local seenBoard = {}
		local persistIdToBoard = {}
		boards = Array.filter(boards, function(board)
			if seenBoard[board] then
				return false
			end

			if persistIdToBoard[board.PersistId] then
				print(
					("[Persistence] '%s' has the same PersistId (%s) as %s. Ignoring."):format(
						board:FullName(),
						board.PersistId,
						persistIdToBoard[board.PersistId]:FullName()
					)
				)

				return false
			else
				persistIdToBoard[board.PersistId] = board
			end

			seenBoard[board] = true
			return true
		end)
	end

	local notFetched = Set.fromArray(boards)
	local deserialisers = {}

	-- Spawn coroutines to fetch the serialised data for each board

	for _, board in ipairs(boards) do
		local boardKey = board.PersistId
		if boardKey == nil then
			print(string.format("[Persistence] Cannot restore %s: no persist ID", board._instance.Name))
			continue
		end

		task.spawn(function()
			local result = fetch(dataStore, boardKey)
			notFetched[board] = nil

			if result == NothingStored or nil then
				-- Load the default board
				board:LoadData({}, {}, {}, 0, EraseGrid.new(board:AspectRatio()))
				board.Loaded = true
			else
				table.insert(
					deserialisers,
					coroutine.create(function()
						local figures, nextFigureZIndex, eraseGrid = deserialise(board, result)

						board:LoadData(figures, {}, {}, nextFigureZIndex, eraseGrid)
						board.Loaded = true
						board.LoadedSignal:Fire()
						print("Loaded: " .. boardKey)
					end)
				)
			end
		end)

		local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
		if budget < 100 then
			print(("[MetaBoard] GetAsync budget hit, throttling for %ds"):format(waitTime))
			task.wait(waitTime)
		end
	end

	-- Repeatedly resume all of the deserialisers until they are all finished

	while next(notFetched) or #deserialisers > 0 do
		if next(notFetched) then
			task.wait()
		end

		for i = 1, math.min(#deserialisers, Config.RestoreAllNumSimultaneousBoards) do
			local co = deserialisers[i]
			if co then
				local status = coroutine.status(co)
				if status == "suspended" then
					local success, result = coroutine.resume(co)
					if not success then
						print("[MetaBoard] Failed to resume board deserialiser: " .. result)
					end
				elseif status == "dead" then
					continue
				else
					print("[MetaBoard] Deserialiser coroutine in unexpected status: " .. status)
				end
			end
		end

		local notDead = Array.filter(deserialisers, function(co)
			return coroutine.status(co) ~= "dead"
		end)

		deserialisers = notDead
		task.wait(0.01)
	end

	print("[MetaBoard] Restore All complete")
end

return {
	Store = store,
	RestoreAll = restoreAll,
}