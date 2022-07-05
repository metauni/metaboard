return function(board, viewData, canvasTarget, getLineBudget)
	viewData = viewData or {}

	if viewData.Status ~= "Dead" then

		if viewData.Destroy then
			viewData.Destroy()
		end

		board:SetTransparency(0.75)

		return {
			Status = "Dead",
			Destroy = function()
				board:SetTransparency(0)
			end
		}

	end

	return viewData
end