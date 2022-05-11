-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local Viewport = require(script.Parent.Viewport)

-- Canvas Choices
local Client = script.Parent.Parent.Parent
local PartCanvas = require(Client.PartCanvas)
local FrameCanvas = require(Client.FrameCanvas)

-- Pick either PartCanvas or FrameCanvas
-- local CanvasType = PartCanvas
local CanvasType = FrameCanvas

if CanvasType == PartCanvas then

	return function(props)

		local partCanvas = e(PartCanvas, {

			Figures = props.Figures,

			FigureMaskBundles = props.FigureMaskBundles,

			AbsolutePositionBinding = props.AbsolutePositionBinding,
			AbsoluteSizeBinding = props.AbsoluteSizeBinding,

			CanvasSize = props.CanvasSize,
			CanvasCFrame = props.CanvasCFrame,

			AsFragment = true,
		})

		return e(Viewport, {

			TargetAbsoluteSizeBinding = props.AbsoluteSizeBinding,
			TargetAbsolutePositionBinding = props.AbsolutePositionBinding,

			SubjectCFrame = props.CanvasCFrame,
			SubjectHeight = props.CanvasSize.Y,

			FieldOfView = 70,

			ZIndex = props.ZIndex,

			[Roact.Children] = {
				Figures = partCanvas
			},

		})

	end

else

	return function(props)

		return e(FrameCanvas, {

			Figures = props.Figures,

			FigureMaskBundles = props.FigureMaskBundles,

			AbsolutePositionBinding = props.AbsolutePositionBinding,
			AbsoluteSizeBinding = props.AbsoluteSizeBinding,

			ZIndex = props.ZIndex,
		})

	end

end