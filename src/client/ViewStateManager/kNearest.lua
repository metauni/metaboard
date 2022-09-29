-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

return function(position: Vector3, boardSet, k)
	local nearestArray = {}
	local nearestSet = {}

	for _ = 1, k do
		local minSoFar = math.huge
		local nearestBoard = nil
		for board in pairs(boardSet) do
			if nearestSet[board] then
				continue
			end

			local distance = (board.SurfaceCFrame.Position - position).Magnitude
			if distance < minSoFar then
				nearestBoard = board
				minSoFar = distance
			end
		end

		if nearestBoard then
			table.insert(nearestArray, nearestBoard)
			nearestSet[nearestBoard] = true
		else
			break
		end
	end

	return nearestArray, nearestSet
end