-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Feather = require(Common.Packages.Feather)

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