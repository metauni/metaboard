return function(position: Vector3, boardSet, k)
	local nearestArray = {}
	local nearestSet = {}

	for i = 1, k do
		local minSoFar = math.huge
		local nearestBoard = nil
		for board in pairs(boardSet) do
			if nearestSet[board] then
				continue
			end

			local distance = (board:SurfaceCFrame().Position - position).Magnitude
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