return function(self)
	return {
		Width = math.round(self.state.ToolState.StrokeWidths[self.state.ToolState.SelectedStrokeWidthName]),
		ShadedColor = self.state.ToolState.ColorWells[self.state.ToolState.SelectedColorWellIndex]
	}
end