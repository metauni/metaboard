-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Dictionary = Sift.Dictionary
local Figure = require(Common.Figure)

-- FigureComponents
local FigureComponent = {
	Curve = require(script.SectionedCurve),
	Line = require(script.Line),
	Circle = require(script.Circle),
}

local PureFigure = Roact.PureComponent:extend("PureFigure")

function PureFigure:render()
	local figure = self.props.Figure
	local container = self.props.Container

	local cummulativeMask = Figure.MergeMask(figure.Type, figure.Mask)

	for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
		cummulativeMask = Figure.MergeMask(figure.Type, cummulativeMask, figureMask)
	end

	return e(FigureComponent[figure.Type], Dictionary.merge(figure, {
		
		ZIndexOffset = self.props.ZIndexOffset,
		CanvasAbsolutePosition = self.props.CanvasAbsolutePosition,
		CanvasAbsoluteSize = self.props.CanvasAbsoluteSize,
		Mask = cummulativeMask,

	}))
end

function PureFigure:shouldUpdate(nextProps, nextState)
	local shortcut =
	nextProps.Figure ~= self.props.Figure or
	nextProps.CanvasSize ~= self.props.CanvasSize or
	nextProps.CanvasCFrame ~= self.props.CanvasCFrame or
	nextProps.ZIndexOffset ~= self.props.ZIndexOffset or
	nextProps.CanvasAbsolutePosition ~= self.props.CanvasAbsolutePosition or
  nextProps.CanvasAbsoluteSize ~= self.props.CanvasAbsoluteSize
	
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

local FrameCanvas = Roact.PureComponent:extend("FrameCanvas")

function FrameCanvas:render()

	local pureFigures = {}

	for figureId, figure in pairs(self.props.Figures) do

		pureFigures[figureId] = e(PureFigure, {

			Figure = figure,

			FigureMasks = self.props.FigureMaskBundles[figureId] or {},

			CanvasAbsolutePosition = self.props.CanvasAbsolutePosition,
			CanvasAbsoluteSize = self.props.CanvasAbsoluteSize,

			ZIndexOffset = self.props.ZIndex,

		})

	end

	return e("Folder", {}, pureFigures)
end

return FrameCanvas