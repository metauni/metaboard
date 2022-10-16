-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local DrawingTools = script.Parent.DrawingTools

-- Globals
local _toolState = nil

return {

	GetToolState = function()

		if _toolState then
			
			return _toolState
		end

		_toolState = {
			EquippedTool = require(DrawingTools.Pen),
			SelectedEraserSizeName = "Small",
			StrokeWidths = {
				Small = Config.DrawingTools.Defaults.SmallStrokeWidth,
				Medium = Config.DrawingTools.Defaults.MediumStrokeWidth,
				Large = Config.DrawingTools.Defaults.LargeStrokeWidth,
			},
			SelectedStrokeWidthName = "Small",
			SelectedColorWellIndex = 1,
			ColorWells = Config.DefaultColorWells,
		}

		return _toolState
	end,

	SetToolState = function(toolState)
		
		_toolState = toolState
	end,
}