--!strict

-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary
local Figure = require(Common.Figure)

-- FigureComponents
local FigureComponent = {
	Curve = require(script.SectionedCurve),
	Line = (function()
		local LineComponent = require(script.Line)

		return function(props)
			return e(LineComponent, Dictionary.merge(props, {

				RoundedP0 = true,
				RoundedP1 = true,

			}))
		end
		
	end)(),
	Circle = require(script.Circle),
}

local PureFigure = Roact.PureComponent:extend("PureFigure")

function PureFigure:render()
	local figure = self.props.Figure
	
	local cummulativeMask = Figure.MergeMask(figure.Type, figure.Mask)

	for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
		cummulativeMask = Figure.MergeMask(figure.Type, cummulativeMask, figureMask)
	end

	return e(FigureComponent[self.props.Figure.Type],


		Dictionary.merge(self.props.Figure, {
			CanvasSize = self.props.CanvasSize,
			CanvasCFrame = self.props.CanvasCFrame,

			Mask = cummulativeMask,
		})

	)
end

function PureFigure:shouldUpdate(nextProps, nextState)
	local shortcut =
	nextProps.Figure ~= self.props.Figure or
	nextProps.CanvasSize ~= self.props.CanvasSize or
	nextProps.CanvasCFrame ~= self.props.CanvasCFrame or
	nextProps.ZIndexOffset ~= self.props.ZIndexOffset
	
	if shortcut then
		return true
	else
		-- Check if any new figure masks are different or weren't there before
		for eraseTaskId, figureMask in pairs(nextProps.FigureMasks) do
			if figureMask ~= self.props.FigureMasks[eraseTaskId] then
				return true
			end
		end
		
		-- Check if any old figure masks and now different or gone
		for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
			if figureMask ~= nextProps.FigureMasks[eraseTaskId] then
				return true
			end
		end

		return false
	end
end

local PartCanvas = Roact.PureComponent:extend("PartCanvas")

function PartCanvas:render()

	local flippedFigureMasks = {}

	for eraseTaskId, figureMasks in pairs(self.props.BundledFigureMasks) do
		for taskId, figureMask in pairs(figureMasks) do
			flippedFigureMasks[taskId] = flippedFigureMasks[taskId] or {}
			flippedFigureMasks[taskId][eraseTaskId] = figureMask
		end
	end

	local pureFigures = {}

	for taskId, figure in pairs(self.props.Figures) do

		pureFigures[taskId] = e(PureFigure, {

			Figure = figure,
			FigureMasks = flippedFigureMasks[taskId] or {},
			CanvasSize = self.props.CanvasSize,
			CanvasCFrame = self.props.CanvasCFrame,

		})
	end

	if self.props.AsFragment then
		return Roact.createFragment(pureFigures)
	else
		return e("Folder", {}, pureFigures)
	end

end

return PartCanvas