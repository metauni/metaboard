return function(self, board, viewData)
	viewData = viewData or {}

	if viewData.Status ~= "Dead" then

		if viewData.Destroy then
			viewData.Destroy()
		end

		local surfacePart = board:SurfacePart()
		local originalTransparency = surfacePart.Transparency

		surfacePart.Transparency = 3/4 + 1/4 * originalTransparency

		return {
			Status = "Dead",
			Destroy = function()
				surfacePart.Transparency = originalTransparency
			end
		}

	end

	return viewData
end