-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

--!strict

--[[
	A 2D grid with a pre-defined width and height. Each point on the grid has an
	associated hash set. The grid is backed by an array that maps a point's 2D
	position to a unique 1D index.
]]

return function(width: number, _height: number)
	local gridSet = {}
	
	local function getIndex(x: number, y: number)
		return x + 1 + y * width
	end
	
	-- Gets the hash set associated with the point (x, y)
	local function get(x: number, y: number)
		return gridSet[getIndex(x, y)]
	end
	
	-- Adds a value to the hash set associated with the point (x, y)
	local function add(x: number, y: number, value)
		local index = getIndex(x, y)
		local set = gridSet[index]

		if not set then
			set = {}
			gridSet[index] = set
		end
		
		set[value] = true
	end
	
	-- Removes a value from the hash set associated with the point (x, y).
	-- If the hash set is empty after the removal, the hash set gets removed
	-- from gridSet.
	local function remove(x: number, y: number, value)
		local index = getIndex(x, y)
		local set = gridSet[index]
		
		if set then
			set[value] = nil
			
			if next(set) == nil then
				gridSet[index] = nil
			end
		end
	end
	
	return {
		Values = gridSet,
		Get = get,
		Add = add,
		Remove = remove
	}
end