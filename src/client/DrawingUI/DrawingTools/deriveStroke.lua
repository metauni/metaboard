return function(self)
	return {
		Width = math.round(self.state.StrokeWidths[self.state.SelectedStrokeWidthName]),
		ShadedColor = self.state.ColorWells[self.state.SelectedColorWellIndex]
	}
end