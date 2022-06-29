return function (board, position)
	return board:SurfaceCFrame().LookVector:Dot(position - board:SurfaceCFrame().Position)
end