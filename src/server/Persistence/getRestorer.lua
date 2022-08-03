-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

-- Imports
local Config = require(Common.Config)
local EraseGrid = require(Common.EraseGrid)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local function jsonDecode(json: string, name: string?)
	local data = HttpService:JSONDecode(json)
	if not data then
		name = name or ""
		error("" .. name .. " JSON decoding failed")
	end

	return data
end

local function get(dataStore: DataStore, key: string)
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync) <= 0 do
		-- TODO maybe make this longer?
		task.wait()
	end

	--[[
		No pcall because we catch the error in `restoreAll`

		Note we are not storing the 2nd, 3rd, 4th return values of getAsync
	--]]
	-- print("getting key", key)
	local result = dataStore:GetAsync(key)

	return result
end

local typeCheckSerialised = {

	Point = function(point)
		assert(typeof(point) == "table")
		assert(typeof(point.X) == "number")
		assert(typeof(point.Y) == "number")
		return true
	end,

	Color = function(color)
		assert(typeof(color) == "table")
		assert(typeof(color.R) == "number")
		assert(typeof(color.G) == "number")
		assert(typeof(color.B) == "number")
		return true
	end,

}


local fetchers = {

	["Legacy"] = function(dataStore, board, boardKey, boardKeyValue)

		--[[
			Clear count is not preserved, nor is the AuthorUserId of any curve
		--]]

		local boardData = jsonDecode(boardKeyValue, "Legacy BoardDataJSON")

		local serialisedCurves
		local serialisedCurvesJSON

		--[[
			Either the curves are stored in the
		--]]

		if not boardData.numCurveSegments then

			-- For old versions the curve data is stored under the main key
			serialisedCurves = boardData.Curves

			assert(serialisedCurves, "Legacy: expected board to have Curves stored in main key")

		else

			local segments = {}

			for curvesSegmentId = 1, boardData.numCurveSegments do

				local curvesSegmentKey = boardKey .. ":c"..curvesSegmentId

				table.insert(segments, get(dataStore, curvesSegmentKey))

			end

			serialisedCurvesJSON = table.concat(segments)
		end

		return coroutine.create(function(timeBudget)

			while timeBudget == nil do
				timeBudget = coroutine.yield()
			end
			local startTime = os.clock()

			if serialisedCurvesJSON then
				serialisedCurves = jsonDecode(serialisedCurvesJSON, "Legacy: SerialisedCurves")
			end

			local figures = {}
			local eraseGrid = EraseGrid.new(board:AspectRatio())

			for _, curveData in ipairs(serialisedCurves) do

				--[[
					The only type of figure in Legacy is "Curve", because even StraightLines
					are just curves in terms of what data is actually stored.
				--]]

				assert(#curveData.Lines > 0)
				local points = table.create(#curveData.Lines+1)
				typeCheckSerialised.Point(curveData.Lines[1].Start)
				typeCheckSerialised.Point(curveData.Lines[1].Stop)
				table.insert(points, curveData.Lines[1].Start)
				table.insert(points, curveData.Lines[1].Stop)

				local color, width
				local mask = {}

				for i, lineData in ipairs(curveData.Lines) do
					--[[
						Every line should have the same color and width
					--]]

					typeCheckSerialised.Color(lineData.Color)
					if color then
						assert(Dictionary.equals(color, lineData.Color))
					else
						color = lineData.Color
					end

					assert(typeof(lineData.ThicknessYScale) == "number")
					if width then
						assert(width == lineData.ThicknessYScale)
					else
						width = lineData.ThicknessYScale
					end

					if i == 1 then
						-- Already stored these points
						continue
					end

					typeCheckSerialised.Point(lineData.Start)
					typeCheckSerialised.Point(lineData.Stop)

					--[[
						Legacy only stores lines, so the gaps between them are implicit.
						When there's a gap we indicate it in the mask.
					--]]

					if not Dictionary.equals(points[#points], lineData.Start) then
						mask[tostring(#points)] = true
						table.insert(points, lineData.Start)
					end
					
					table.insert(points, lineData.Stop)
				end

				assert(color)
				assert(width)

				local serialisedFigure = {
					Type = "Curve",
					ZIndex = curveData.ZIndex,
					Color = color,
					Width = width,
					Points = points,
					Mask = mask,
				}

				assert(typeof(curveData.Name) == "string")

				local figureId = curveData.Name
				local figure = Figure.Deserialise(serialisedFigure)

				figures[figureId] = figure
				eraseGrid:AddFigure(figureId, figure)

				if (os.clock() - startTime) > timeBudget then

					repeat
						timeBudget = coroutine.yield()
					until timeBudget ~= nil

					startTime = os.clock()
				end
			end

			return {
				Figures = figures,
				NextFigureZIndex = boardData.CurrentZIndex,
			}

		end)


	end,

	["v3"] = function(dataStore, board, boardKey, boardKeyValue)

		local nextFigureZIndex = boardKeyValue.NextFigureZIndex
		local chunkCount = boardKeyValue.ChunkCount

		local chunks = {boardKeyValue.FirstChunk}

		for i=2, chunkCount do
			local chunkKey = boardKey .. "/" .. tostring(i)
			table.insert(chunks, get(dataStore, chunkKey))
		end

		return coroutine.create(function(timeBudget)

			while timeBudget == nil do
				timeBudget = coroutine.yield()
			end
			local startTime = os.clock()

			local figures = {}
			local eraseGrid = EraseGrid.new(board:AspectRatio())

			for _, chunk in ipairs(chunks) do

				--[[
					For each line
						(1) Decode the figure-entry-json
						(2) Deserialise it into Datatype values (Vector2's, Color3's etc)
						(3) Put it into the erase grid

					After each line, check if the time budget has been exceeded, and then
					yield until more time is alotted.

					Note that this code has the correct behaviour for empty-string chunks
				--]]

				local j = 1

				while j < chunk:len() do

					local k = chunk:find("\n", j + 1)
					local entry = jsonDecode(chunk:sub(j, k - 1), "Chunk Entry")

					local figureId, serialisedFigure = entry[1], entry[2]

					local figure = Figure.Deserialise(serialisedFigure)
					eraseGrid:AddFigure(figureId, figure)

					figures[figureId] = figure

					j = k + 1

					if (os.clock() - startTime) > timeBudget then

						repeat
							timeBudget = coroutine.yield()
						until timeBudget ~= nil

						startTime = os.clock()
					end
				end
			end

			return {
				Figures = figures,
				NextFigureZIndex = nextFigureZIndex,
				EraseGrid = eraseGrid,
			}
		end)

	end,

}

return function (dataStore, board, boardKey, loadData)

	local storedData = get(dataStore, boardKey)

	if not storedData then
		return nil
	end

	if typeof(storedData) == "string" then
		-- print("Fetching legacy for "..boardKey)

		return fetchers["Legacy"](dataStore, board, boardKey, storedData)

	elseif typeof(storedData) == "table" then

		local formatVersion = storedData._FormatVersion

		if not formatVersion then
			error("Format version not stored")
		end

		if not fetchers[formatVersion] then
			error("Format version not recognised: "..formatVersion)
		end

		-- print("Fetching "..formatVersion.." for "..boardKey)

		return fetchers[formatVersion](dataStore, board, boardKey, storedData)

	else

		error(("Stored Data type %s not recognised"):format(typeof(storedData)))
	end
end