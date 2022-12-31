-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local HttpService = game:GetService("HttpService")

-- Imports
local root = script.Parent
local Config = require(root.Config)
local DataStoreService = Config.Persistence.DataStoreService
local Figure = require(root.Figure)
local EraseGrid = require(root.EraseGrid)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Constants
local FORMAT_VERSION = script.currentFormatVersion.Value

-- Helper functions
local getRestorer = require(script.getRestorer)

-- Globals
local RestoreContext = {}
local ProcessorCoroutine = nil

local function waitForBudget(requestType: Enum.DataStoreRequestType)

	while DataStoreService:GetRequestBudgetForRequestType(requestType) <= 0 do
		task.wait()
	end
end

local function store(dataStore, boardKey, board, ignoreBudget)
	--[[
		At "metaboard<persistId>", we store this table (not json-encoded)
			{
				_FormatVersion: string,
				NextFigureZIndex: number,
				ClearCount: number,
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

	local startTime = tick()

	--[[
		MUST extract all of this information first before yielding, otherwise
		board data could change before store is done.
	--]]
	
	local clearCount = board.ClearCount
	local nextFigureZIndex = board.NextFigureZIndex
	local aspectRatio = board:AspectRatio()
	-- Commit all of the drawing task changes (like masks) to the figures
	local figures = board:CommitAllDrawingTasks()

	local removals = {}

	-- Remove the figures that have been completely erased
	for figureId, figure in pairs(figures) do
		if Figure.FullyMasked(figure) then
			removals[figureId] = Sift.None
		end
	end

	figures = Dictionary.merge(figures, removals)

	-- Serialise and encode every figureId-figure pair as a length 2 json array

	local chunks = {}
	local jsonLines = {}

	for figureId, figure in pairs(figures) do
		local serialisedFigure = Figure.Serialise(figure)

		-- Encode as JSON with newline separator at the end
		local entryJson = HttpService:JSONEncode({ figureId, serialisedFigure })

		if not entryJson then
			
			warn("[metaboard] "..boardKey..", JSON encoding failed for figure: "..figureId)
			continue
		end

		entryJson = entryJson.."\n"

		-- Max storage at single key is 4MB
		if entryJson:len() > Config.Persistence.ChunkSizeLimit then

			warn(("[metaboard] %s, figure %s too large for a single chunk"):format(boardKey, figureId))
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

	local totalBytes = 0

	local success, errormessage = xpcall(function()

		--[[
			At <boardKey> store the board info and the first chunk in a table

			Then store chunk[i] at <boardKey>/i for i >= 2.
		--]]

		if not ignoreBudget then
			
			waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		end

		dataStore:SetAsync(boardKey, {

			_FormatVersion = FORMAT_VERSION,

			NextFigureZIndex = nextFigureZIndex,
			AspectRatio = aspectRatio,
			ClearCount = clearCount,
			ChunkCount = #chunks,
			FirstChunk = chunks[1],
		})

		-- Note this doesn't account for the overhead of the table stored with the
		-- first chunk.
		totalBytes += #chunks[1]
		for i=2, #chunks do

			if not ignoreBudget then
			
				waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
			end

			dataStore:SetAsync(boardKey .. "/"..tostring(i), chunks[i])
			totalBytes += chunks[i]:len()
		end
	
	end, debug.traceback)

	if not success then

		warn("[metaboard] Storing fail for " .. boardKey .. ". " .. errormessage)
		return
	end

	if #chunks > 1 then
		
		print(
			string.format(
				"[metaboard] Stored %d bytes across %d chunks at key %s in %.2fs",
				totalBytes,
				#chunks,
				boardKey,
				tick() - startTime
			)
		)
	
	else

		print(
			string.format(
				"[metaboard] Stored %d bytes at key %s in %.2fs",
				totalBytes,
				boardKey,
				tick() - startTime
			)
		)
	end

	return true
end

local function processRestorers()

	local count = 0
	local startTime = os.clock()

	while next(RestoreContext) do

		local boardKey, context do

			for _boardKey, _context in pairs(RestoreContext) do

				if _context.Status == "Restoring" then
					boardKey = _boardKey
					context = _context
					break
				end
			end


			if not context then
				task.wait()
				continue
			end
		end

		local restorer = context.Restorer
		local board = context.Board
		local receiver = context.Receiver

		while true do

			assert(coroutine.status(restorer) == "suspended")

			local success, result = coroutine.resume(restorer, Config.Persistence.RestoreTimePerFrame)

			if not success then
				local message = ("[metaboard] Restore failed for key %s for board %s, \n	%s"):format(boardKey, board:FullName(), result)
				warn(message)

				coroutine.resume(receiver, false, message)

				task.wait()
				break
			end

			if result then

				coroutine.resume(receiver, true, result)

				count += 1
				task.wait()
				break
			end

			task.wait()
		end
	end

	print(("[metaboard] Restored %d boards in %.2fs"):format(count, os.clock()-startTime))

	ProcessorCoroutine = nil
end

local function restore(dataStore, boardKey, board)

	if RestoreContext[boardKey] then
		local context = RestoreContext[boardKey]
		local message = ("[metaboard] %s has the same PersistId (%s) as %s. Ignoring."):format(board:FullName(), boardKey, context.Board:FullName())
		warn(message)
		return false, message
	end

	RestoreContext[boardKey] = {
		Status = "Fetching",
		BoardKey = boardKey,
		Board = board,
	}

	--[[
		getRestorer retrieves all the data it needs from the relevant keys,
		then returns a coroutine that deserialises and loads the data
	--]]
	local success, result = xpcall(getRestorer, debug.traceback, dataStore, board, boardKey)

	if not success then
		local message = ("[metaboard] Fetch failed for key %s, \n	%s"):format(boardKey, result)
		warn(message)

		RestoreContext[boardKey] = nil

		return false, message
	end

	if result == nil then

		RestoreContext[boardKey] = nil

		-- Nothing was stored, give back empty data
		return true, {

			Figures = {},
			NextFigureZIndex = 0,
			EraseGrid = EraseGrid.new(board:AspectRatio()),
			ClearCount = 0,

		}
	else
		local restorer = result

		RestoreContext[boardKey].Status = "Restoring"
		RestoreContext[boardKey].Restorer = restorer
		RestoreContext[boardKey].Receiver = coroutine.running()

		if ProcessorCoroutine == nil then
			ProcessorCoroutine = coroutine.create(processRestorers)
			task.defer(ProcessorCoroutine)
		end

		local _success, _result = coroutine.yield()

		RestoreContext[boardKey] = nil

		return _success, _result
	end
end

return {
	StoreWhenBudget = function(dataStore, boardKey, board)
		return store(dataStore, boardKey, board, false)
	end,
	StoreNow = function(dataStore, boardKey, board)
		return store(dataStore, boardKey, board, true)
	end,
	Restore = restore,
}