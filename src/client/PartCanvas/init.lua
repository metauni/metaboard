--!strict

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local merge = Sift.Dictionary.merge

local _LineComponent = require(script.Line)

-- FigureComponents
local FigureComponent = {
	Curve = require(script.SectionedCurve),
	Line = (function()

		return function(props)
			return e(_LineComponent, merge(props, {

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


		merge(self.props.Figure, {
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

		-- Check if any old figure masks are now different or gone
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

	assert(self.props.CanvasCFrame)

	local pureFigures = {}

	for figureId, figure in pairs(self.props.Figures) do

		pureFigures[figureId] = e(PureFigure, {

			Figure = figure,
			FigureMasks = self.props.FigureMaskBundles[figureId] or {},
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