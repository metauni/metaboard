return function(boards, pos, k)
	local kNearest = table.create(k, nil)
	local exclude = {}

	for i=1, k do
		local minSoFar = math.huge
		local nearestBoard = nil
		for _, board in ipairs(boards) do
			if exclude[board] then continue end

			local distance = (board:SurfaceCFrame().Position - pos).Magnitude
			if distance < minSoFar then
				nearestBoard = board
				minSoFar = distance
			end
		end
		
		if nearestBoard then
			table.insert(kNearest, nearestBoard)
			exclude[nearestBoard] = true
		else
			break
		end
	end

	return kNearest
end