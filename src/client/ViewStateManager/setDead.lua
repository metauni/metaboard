-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

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