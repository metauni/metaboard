-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent
local Config = require(root.Config)
local Feather = require(root.Parent.Feather)

-- Components
local Curve = require(script.Curve)

return function(props, oldProps)
	
	local deltaChildren = {}

	local changeAll =
		oldProps.Figures == nil
		or
		props.CanvasCFrame ~= oldProps.CanvasCFrame
		or
		props.CanvasSize ~= oldProps.CanvasSize

	for figureId, figure in props.Figures do
		
		if
			changeAll
			or
			figure ~= oldProps[figureId]
			or
			props.FigureMaskBundles[figureId] ~= oldProps.FigureMaskBundles[figureId] then
			
			deltaChildren[figureId] = Feather.createElement(Curve, {
	
				Curve = figure,
				Masks = props.FigureMaskBundles[figureId],
				CanvasSize = props.CanvasSize,
				CanvasCFrame = props.CanvasCFrame,
			})
		end

	end

	if oldProps.Figures then
		
		for figureId, figure in oldProps.Figures do
			
			if not props.Figures[figureId] then
				
				deltaChildren[figureId] = Feather.SubtractChild
			end
		end
	end

	return Feather.createElement("Model", {

		[Feather.DeltaChildren] = deltaChildren
	})
end