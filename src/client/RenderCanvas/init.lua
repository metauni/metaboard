-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Render = require(Common.Packages.Render)

-- Components
local Curve = require(script.Curve)

local e = Render.createElement

-- return function(props)
	
-- 	local figureElements = {}

-- 	for figureId, figure in props.Figures do
		
-- 		figureElements[figureId] = e(Curve, {

-- 			Curve = figure,
-- 			Masks = props.BundledFigureMasks[figureId],
-- 			CanvasSize = props.CanvasSize,
-- 			CanvasCFrame = props.CanvasCFrame,
-- 		})
-- 	end

-- 	return e("Model", {

-- 		[Render.Children] = figureElements
-- 	})
-- end

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
			props.BundledFigureMasks[figureId] ~= oldProps.BundledFigureMasks[figureId] then
			
			deltaChildren[figureId] = e(Curve, {
	
				Curve = figure,
				Masks = props.BundledFigureMasks[figureId],
				CanvasSize = props.CanvasSize,
				CanvasCFrame = props.CanvasCFrame,
			})
		end

	end

	return e("Model", {

		[Render.DeltaChildren] = deltaChildren
	})
end