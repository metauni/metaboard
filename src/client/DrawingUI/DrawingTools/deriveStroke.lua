return function(state)
	return {
		Width = math.round(state.ToolState.StrokeWidths[state.ToolState.SelectedStrokeWidthName]),
		ShadedColor = state.ToolState.ColorWells[state.ToolState.SelectedColorWellIndex]
	}
end