-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

return function(self, board, viewData)
	viewData = viewData or {}

	if viewData.Destroy then
		viewData.Destroy()
	end

	-- Get the surface part (may be nil if the board is a Model and the primary
	-- part has streamed out).

	local surfacePart do

		local instance = board._instance

		if instance:IsA("Model") then
			
			surfacePart = instance.PrimaryPart

		else

			surfacePart = instance

		end
	end

	if not surfacePart then

		-- It's been streamed out. Do nothing.
		
		return {

			Status = "Dead",
		}
	end

	local originalTransparency = surfacePart.Transparency

	surfacePart.Transparency = 3/4 + 1/4 * originalTransparency

	return {
		
		Status = "Dead",
		Destroy = function()
			surfacePart.Transparency = originalTransparency
		end
	}
end