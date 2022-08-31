-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

return function(state)
	return {
		Width = math.round(state.ToolState.StrokeWidths[state.ToolState.SelectedStrokeWidthName]),
		ShadedColor = state.ToolState.ColorWells[state.ToolState.SelectedColorWellIndex]
	}
end