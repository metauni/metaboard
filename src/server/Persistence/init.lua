-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local HttpService = game:GetService("HttpService")

-- Imports
local Config = require(Common.Config)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local DataStoreService do
	if Config.Persistence.UseMockDataStoreService then
		DataStoreService = require(Common.Packages.MockDataStoreService)
		warn("Using MockDataStoreService")
	else
		DataStoreService = game:GetService("DataStoreService")
	end
end

-- Constants
local PERSISTENCE_VERSION = "v3"

-- Helper functions
local getRestorer = require(script.getRestorer)

local function jsonEncode(input, name: string?)
	local json = HttpService:JSONEncode(input)
	if not json then
		name = name or ""
		error("[Persistence] " .. name .. " JSON encoding failed")
	end

	return json
end

local function set(dataStore: DataStore, key: string, data)
	return dataStore:SetAsync(key, data)
	-- local success, errormessage = pcall(function()
	-- end)
	-- if not success then
	-- 	error("[Persistence] SetAsync fail for " .. key .. " with " .. string.len(data) .. " bytes " .. errormessage)
	-- end
end

local function store(dataStoreName, figures, nextFigureZIndex, persistId)
	--[[
		At "metaboard<persistId>", we store this table (not json-encoded)
			{
				_FormatVersion: string,
				NextFigureZIndex: number,
				ChunkCount: number,
				FirstChunk: string
			}
		The version indicates the format of the stored data. The FirstChunk key
		is the same as the rest of the chunks, explained below. It is stored in this
		table, instead of its own key, so that key usage is absolutely minimum
		for startup speed.

		The rest of the data at "metaboard<persistId>/chunks/2", "metaboard<persistId>/chunks/3" etc.
		Each of these chunks is a newline-separated string of
		figureId-serialisedFigure pairs.

			[<FigureId>, <SerialisedFigure>]
			[<FigureId>, <SerialisedFigure>]
			[<FigureId>, <SerialisedFigure>]

		The purpose of a chunk is to not exceed the 4MB per-key datastore limit.
		Each chunk is divided into individual figure entries (instead of one big
		json dictionary), so that decoding can be yielded until the next frame.

		Incidentally, encoding and decoding this way (each entry separately)
		actually benchmarks *faster* than doing it as one 4MB string of json.

	--]]

	local boardKey = Config.Persistence.BoardKeyPrefix..persistId
	local dataStore = DataStoreService:GetDataStore(dataStoreName)

	local startTime = tick()

	-- Serialise and encode every figureId-figure pair as a length 2 json array

	local chunks = {}
	local jsonLines = {}

	for figureId, figure in pairs(figures) do
		local serialisedFigure = Figure.Serialise(figure)

		-- Encode as JSON with newline separator at the end
		local entryJson = jsonEncode({ figureId, serialisedFigure }, "SerialisedFigureEntry") .. "\n"

		-- Max storage at single key is 4MB
		if entryJson:len() > Config.Persistence.ChunkSizeLimit then
			print(("[Persistence] figure %s too large for a single chunk"):format(figureId))
			continue
		end

		table.insert(jsonLines, entryJson)
	end

	-- Divide the entries into concatenated chunks of maximum length
	-- `Config.Persistence.ChunkSizeLimit`

	do
		local i = 1
		while i <= #jsonLines do
			local chunkSize = 0
			local j = i
			while j <= #jsonLines and chunkSize <= Config.Persistence.ChunkSizeLimit do
				chunkSize += jsonLines[j]:len()
				j += 1
			end

			-- entries i through j-1 don't exceed the chunk limit when concatenated

			table.insert(chunks, table.concat(jsonLines, "", i, j - 1))

			i = j
		end
	end

	--[[
		The above chunking code fails to account for the empty board case
	--]]
	if not next(figures) then
		chunks = {""}
	end

	--[[
		At metaboard<persistId> store the board info and the first chunk in a table

		Then store chunk[i] at metaboard<persistId>/i for i >= 2.
	--]]

	set(dataStore, boardKey, {
		_FormatVersion = PERSISTENCE_VERSION,

		NextFigureZIndex = nextFigureZIndex,
		ChunkCount = #chunks,
		FirstChunk = chunks[1],
	})

	-- Note this doesn't account for the overhead of the table stored with the
	-- first chunk.
	local totalBytes = #chunks[1]
	for i=2, #chunks do
		totalBytes += chunks[i]:len()
		set(dataStore, boardKey .. "/"..tostring(i), chunks[i])
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

local function restoreAll(dataStoreName, boards)

	local dataStore = DataStoreService:GetDataStore(dataStoreName)

	do -- Removes duplicate boards and duplicate persistId
		local seenBoard = {}
		local persistIdToBoard = {}
		boards = Array.filter(boards, function(board)
			if seenBoard[board] then
				return false
			end

			if not board.PersistId then
				print(("[Persistence] %s has no PersistId. Ignoring."):format(board:FullName()))
				return false
			end

			if persistIdToBoard[board.PersistId] then
				print(
					("[Persistence] %s has the same PersistId (%s) as %s. Ignoring."):format(
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

	local boardToRestorer = {}
	local notFetched = Set.fromArray(boards)

	for _, board in ipairs(boards) do

		task.spawn(function()

			local boardKey = Config.Persistence.BoardKeyPrefix..board.PersistId

			--[[
				getRestorer retrieves all the data it needs from the relevant keys,
				then returns a coroutine that deserialises and loads the data
			--]]
			local success, result = pcall(getRestorer, dataStore, board, boardKey)

			notFetched[board] = nil

			if not success then
				print(("[Persistence] Fetch failed for key %s, \n	%s"):format(boardKey, result))
				--TODO Lock board somehow so edits aren't possible
				return
			end

			local restorer = result

			if restorer == nil then

				-- Nothing was stored, load the empty board
				board:LoadData({}, {}, {}, 0, nil)
				board.Loaded = true
				board.LoadedSignal:Fire()
				print("Loaded: "..board:FullName())

			else

				boardToRestorer[board] = restorer
			end
		end)
	end

	local numSimultaneous = Config.Persistence.RestoreAllNumSimultaneousBoards

	while next(notFetched) or next(boardToRestorer) do

		--[[
			Resume up to `numSimultaneous` restorers, with a time budget for deserialising.
		--]]

		local resumableBoards = Array.filter(boards, function(board)
			return boardToRestorer[board]
		end)

		for i=1, math.min(#resumableBoards, numSimultaneous) do

			local board = resumableBoards[i]
			local restorer = boardToRestorer[board]

			if coroutine.status(restorer) == "suspended" then
				local success, result = coroutine.resume(restorer, Config.Persistence.RestoreTimePerFrame / numSimultaneous)

				if not success then
					print(("[Persistence] Restore failed for %s, \n	%s"):format(board:FullName(), restorer))
				end

				if result then
					print("Loading", board:Name())
					board:LoadData(result.Figures, {}, {}, result.NextFigureZIndex, result.EraseGrid)
					board.Loaded = true
					board.LoadedSignal:Fire()
					print("Loaded: "..board:FullName())
				end
			end
		end

		--[[
			Filter out dead restorers
		--]]
		boardToRestorer = Dictionary.filter(boardToRestorer, function(restorer)
			return coroutine.status(restorer) ~= "dead"
		end)

		task.wait()
	end

	print("[MetaBoard] Restore All complete")
end

return {
	Store = store,
	RestoreAll = restoreAll,
}