-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

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

local PureFigure = Roact.Component:extend("PureFigure")

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

return function (props)
	assert(props.CanvasCFrame)

	local pureFigures = {}

	for figureId, figure in pairs(props.Figures) do

		pureFigures[figureId] = e(PureFigure, {

			Figure = figure,
			FigureMasks = props.FigureMaskBundles[figureId] or {},
			CanvasSize = props.CanvasSize,
			CanvasCFrame = props.CanvasCFrame,

		})
	end

	if props.AsFragment then
		return Roact.createFragment(pureFigures)
	else
		return e("Folder", {}, pureFigures)
	end

end