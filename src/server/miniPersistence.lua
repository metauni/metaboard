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
	return 60/( 60 + 10 * #Players:GetPlayers() )
end

local function store(dataStore, figures, nextFigureZIndex, boardKey)

	local startTime = tick()

	local serialisedFigures = {}
	for figureId, figure in pairs(figures) do
		serialisedFigures[figureId] = Figure.Serialise(figure)
	end

	local boardJSON = HttpService:JSONEncode({
		Figures = serialisedFigures,
		NextFigureZIndex = nextFigureZIndex,
	})

	if not boardJSON then
		print("[Persistence] Board JSON encoding failed")
		return
	end

	local success, errormessage = pcall(function()
		return dataStore:SetAsync(boardKey, boardJSON)
	end)
	if not success then
		print("[Persistence] SetAsync fail for " .. boardKey .. " with " .. string.len(boardJSON) .. " bytes ".. errormessage)
		return
	end

	local _elapsedTime = math.floor(100 * (tick() - startTime))/100

	print("[Persistence] Stored " .. boardKey .. " " .. string.len(boardJSON) .. " bytes in ".. _elapsedTime .."s.")
end


local function deserialise(board, serialisedData)

	local figures = {}
	local eraseGrid = EraseGrid.new(board:AspectRatio())

	local linesLoaded = 0

	for figureId, serialisedFigure in pairs(serialisedData.Figures) do
		
		local figure = Figure.Deserialise(serialisedFigure)
		figures[figureId] = Figure.Deserialise(serialisedFigure)
		eraseGrid:AddFigure(figureId, figure)

		if serialisedFigure.Type == "Curve" then
			linesLoaded += #serialisedFigure.Points
		end

		if linesLoaded > Config.LinesLoadedBeforeWait then
			linesLoaded = 0
			coroutine.yield()
		end
	end

	return figures, serialisedData.NextFigureZIndex, eraseGrid
end

local function fetch(dataStore, boardKey)

	-- Get the value stored for the given persistId. Note that this may not
	-- have been set, which is fine
	local success, boardJSON
	success, boardJSON = pcall(function()
		return dataStore:GetAsync(boardKey)
	end)
	if not success then
		print("[Persistence] GetAsync fail for " .. boardKey .. " " .. boardJSON)
		return nil
	end

	if not boardJSON then
		return NothingStored
	end

	local serialisedData = HttpService:JSONDecode(boardJSON)

	if not serialisedData then
		print("[Persistence] Failed to decode JSON")
		return nil
	end

	return serialisedData
end


local function restoreAll(dataStore, boards)

	-- We are guaranteed that any requests made at this rate
	-- will not decrease our budget, so our strategy is on startup
	-- to spend down our budget to near zero and then throttle to this speed

	-- TODO: shouldn't this be called each time we task.wait? Players could leave
	-- or be added while restoring occurs.
	local waitTime = asyncWaitTime()

	local notFetched = Set.fromArray(boards)
	local deserialisers = {}

	-- Spawn coroutines to fetch the serialised data for each board

	debug.profilebegin("spawn fetchers")
	for _, board in ipairs(boards) do
		if not notFetched[board] then continue end

		local persistId = board.PersistId
		if persistId == nil then continue end
		
		local boardKey = tostring(persistId)
		task.spawn(function()
			print("fetching")
			local result = fetch(dataStore, boardKey)
			notFetched[board] = nil
			
			if result == NothingStored or nil then
				
				-- Load the default board
				board:LoadData({}, {}, {}, 0, EraseGrid.new(board:AspectRatio()))
				board:SetStatus("Loaded")

			else

				table.insert(deserialisers, coroutine.create(function()
					local figures, nextFigureZIndex, eraseGrid = deserialise(board, result)
					
					board:LoadData(figures, {}, {}, nextFigureZIndex, eraseGrid)
					board:SetStatus("Loaded")
					print("Loaded: "..persistId)

				end))

			end
		end)

		local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
		if budget < 100 then
			print("[MetaBoard] GetAsync budget hit, throttling for "..waitTime.."s")
			task.wait(waitTime)
		end
	end

	debug.profileend()

	-- Repeatedly resume all of the deserialisers until they are all finished

	task.spawn(function()

		-- debug.profilebegin("deserialising")
		while next(notFetched) or #deserialisers > 0 do

			if next(notFetched) then
				task.wait()
			end

			debug.profilebegin("deserialise")
			for i=1, math.min(#deserialisers, Config.RestoreAllNumSimultaneousBoards) do

				local co = deserialisers[i]
				if co then

					local status = coroutine.status(co)
					if status == "suspended" then

						local success, result = coroutine.resume(co)
						if not success then
							print("[MetaBoard] Failed to resume board deserialiser: "..result)
						end

					elseif status == "dead" then
						continue
					else
						print("[MetaBoard] Deserialiser coroutine in unexpected status: "..status)
 					end
				end

			end

			local notDead = Array.filter(deserialisers, function(co)
				return coroutine.status(co) ~= "dead"
			end)

			deserialisers = notDead
			-- print(string.format("Simultaneous wait for %fs", 0))
			debug.profileend()
			task.wait(0.01)
			
		end
		
		-- debug.profileend()
		print("[MetaBoard] Restore All complete")

	end)
end


return {
	Store = store,
	RestoreAll = restoreAll,
}