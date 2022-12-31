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

	if not props.CanvasAbsolutePosition or not props.CanvasAbsoluteSize then
		
		return Feather.createElement("Folder", {})
	end

	local deltaChildren = {}

	local changeAll =
		oldProps.Figures == nil
		or
		props.CanvasAbsolutePosition ~= oldProps.CanvasAbsolutePosition
		or
		props.CanvasAbsoluteSize ~= oldProps.CanvasAbsoluteSize
		or
		props.ZIndex ~= oldProps.ZIndex

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
				CanvasAbsoluteSize = props.CanvasAbsoluteSize,
				CanvasAbsolutePosition = props.CanvasAbsolutePosition,

				ZIndexOffset = props.ZIndex,
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

	return Feather.createElement("Folder", {

		[Feather.DeltaChildren] = deltaChildren
	})
end