return function(board, viewData, canvasTarget, getLineBudget)
	viewData = viewData or {}

	if viewData.Status ~= "Dead" then

		if viewData.Destroy then
			viewData.Destroy()
		end

		local originalTransparency = board:GetTransparency()

		board:SetTransparency(3/4 + 1/4 * originalTransparency)

		return {
			Status = "Dead",
			Destroy = function()
				board:SetTransparency(originalTransparency)
			end
		}

	end

	return viewData
end