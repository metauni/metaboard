-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local HttpService = game:GetService("HttpService")

-- Imports
local Config = require(Common.Config)
local DataStoreService = Config.Persistence.DataStoreService
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

	local result = dataStore:GetAsync(key)

	return result
end

local typeCheckSerialised = {

	Point = function(point)
		assert(typeof(point) == "table", "Expected point to be a table")
		assert(typeof(point.X) == "number", "Point table should have key X: number")
		assert(typeof(point.Y) == "number", "Point table should have key Y: number")
		return true
	end,
	
	Color = function(color)
		assert(typeof(color) == "table", "Expected color to be a table")
		assert(typeof(color.R) == "number", "Color table should have key R: number")
		assert(typeof(color.G) == "number", "Color table should have key G: number")
		assert(typeof(color.B) == "number", "Color table should have key B: number")
		return true
	end,

}

local hasKeys = function(tabl, tableName, keyTypes)
	for key, keyType in pairs(keyTypes) do
		assert(typeof(tabl[key]) == keyType, "Expected "..key..": "..keyType.." in "..tableName.."\nGot "..tostring(tabl[key]).." of type "..typeof(tabl[key]))
	end 
end


local fetchers = {

	["Legacy"] = function(dataStore, board, boardKey, boardKeyValue)

		local boardData = jsonDecode(boardKeyValue, "Legacy BoardDataJSON")

		local serialisedCurves
		local serialisedCurvesJSON

		--[[
			Either the curves are stored in the
		--]]

		if not boardData.numCurveSegments then

			hasKeys(boardData, "boardData", {
				Curves = "table"
			})

			-- For old versions the curve data is stored under the main key
			serialisedCurves = boardData.Curves

			assert(serialisedCurves, "Legacy: expected board to have Curves stored in main key")

		else

			hasKeys(boardData, "boardData", {
				numCurveSegments = "number"
			})

			local segments = {}

			for curvesSegmentId = 1, boardData.numCurveSegments do

				local curvesSegmentKey = boardKey .. ":c"..curvesSegmentId

				local curveSegment = get(dataStore, curvesSegmentKey)

				assert(typeof(curveSegment) == "string", "Expected CurveSegement to have type string")

				table.insert(segments, curveSegment)

			end

			serialisedCurvesJSON = table.concat(segments)
		end

		return coroutine.create(function(timeBudget)

			hasKeys(boardData, "boardData", {
				CurrentZIndex = "number",
				ClearCount = "number"
			})

			local currentZIndex = boardData.CurrentZIndex
			local clearCount = boardData.ClearCount

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

				hasKeys(curveData, "curveData", {
					Name = "string",
					Lines = "table",
					ZIndex = "number"
				})

				local curveName = curveData.Name
				local lines = curveData.Lines
				local zIndex = curveData.ZIndex

				assert(#lines > 0)
				local points = table.create(#lines+1)
				typeCheckSerialised.Point(lines[1].Start)
				typeCheckSerialised.Point(lines[1].Stop)
				table.insert(points, lines[1].Start)
				table.insert(points, lines[1].Stop)

				local color, width
				local mask = {}

				--[[
					Legacy curves are a list of line segments, whereas v3+ curves are
					lists of points + a mask array.

					These lines likely appear in their creation order but this is purely
					dependent on the behaviour of GetChildren(), so no order can be assumed.
					This ends up not mattering because we allow and account for "gaps"
					between consecutive lines, which are interpreted as erased sections of
					the curve. As a result, assuming that the lines are given in creation
					has no visual affect on the resulting curve.
				--]]
				for i, lineData in ipairs(lines) do
					--[[
						Every line should have the same color and width
					--]]

					hasKeys(lineData, "lineData", {
						Color = "table",
						ThicknessYScale = "number",
						Start = "table",
						Stop = "table"
					})

					local lineColor = lineData.Color
					local lineThicknessYScale = lineData.ThicknessYScale
					local start = lineData.Start
					local stop = lineData.Stop

					typeCheckSerialised.Color(lineColor)
					if color then
						assert(Dictionary.equals(color, lineColor), "Curve "..curveName.." has conflicting line colors")
					else
						color = lineColor
					end

					if width then
						assert(width == lineThicknessYScale, "Curve "..curveName.." has conflicting line widths")
					else
						width = lineThicknessYScale
					end

					if i == 1 then
						-- Already stored these points
						continue
					end

					typeCheckSerialised.Point(start)
					typeCheckSerialised.Point(stop)

					--[[
						Legacy only stores lines, so the gaps between them are implicit.
						When there's a gap we indicate it in the mask.
					--]]

					if not Dictionary.equals(points[#points], start) then
						mask[tostring(#points)] = true
						table.insert(points, start)
					end
					
					table.insert(points, stop)

					if (os.clock() - startTime) > timeBudget then

						repeat
							timeBudget = coroutine.yield()
						until timeBudget ~= nil

						startTime = os.clock()
					end
				end

				assert(color, "Couldn't determine color of curve: "..curveName)
				assert(color, "Couldn't determine width (ThicknessYScale) of curve: "..curveName)

				local serialisedFigure = {
					Type = "Curve",
					ZIndex = zIndex,
					Color = color,
					Width = width,
					Points = points,
					Mask = mask,
				}

				local figureId = curveName
				local figure = Figure.Deserialise(serialisedFigure)

				figures[figureId] = figure
				eraseGrid:AddFigure(figureId, figure)
			end

			return {
				Figures = figures,
				NextFigureZIndex = currentZIndex,
				ClearCount = clearCount,
				EraseGrid = eraseGrid,
			}

		end)


	end,

	["v3"] = function(dataStore, board, boardKey, boardKeyValue)

		hasKeys(boardKeyValue, "boardKeyValue", {
			NextFigureZIndex = "number",
			ChunkCount = "number",
			FirstChunk = "string",
			ClearCount = "number",
		})

		local nextFigureZIndex = boardKeyValue.NextFigureZIndex
		local chunkCount = boardKeyValue.ChunkCount
		local clearCount = boardKeyValue.ClearCount

		local chunks = {boardKeyValue.FirstChunk}

		for i=2, chunkCount do
			local chunkKey = boardKey .. "/" .. tostring(i)
			local chunk = get(dataStore, chunkKey)
			assert(typeof(chunk) == "string", "Expected chunk "..i.." to have type string")
			table.insert(chunks, chunk)
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
				ClearCount = clearCount,
			}
		end)

	end,

}

return function (dataStore, board, boardKey)

	local storedData = get(dataStore, boardKey)

	if not storedData then
		return nil
	end

	if typeof(storedData) == "string" then

		return fetchers["Legacy"](dataStore, board, boardKey, storedData)

	elseif typeof(storedData) == "table" then

		local formatVersion = storedData._FormatVersion

		if not formatVersion then
			error("Format version not stored")
		end

		if not fetchers[formatVersion] then
			error("Format version not recognised: "..formatVersion.."\nThe latest ")
		end

		return fetchers[formatVersion](dataStore, board, boardKey, storedData)

	else

		error(("Stored Data type %s not recognised"):format(typeof(storedData)))
	end
end