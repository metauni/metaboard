-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Client = script.Parent.Parent.Parent

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local FrameCanvas = require(Client.FrameCanvas)
local BoardViewport = require(script.BoardViewport)

local GuiBoardViewer = Roact.PureComponent:extend("GuiBoardViewer")

function GuiBoardViewer:render()

	local canvas = e(FrameCanvas, {

		Figures = self.props.Figures,

		FigureMaskBundles = self.props.FigureMaskBundles,

		AbsolutePositionBinding = self.props.AbsolutePositionBinding,
		AbsoluteSizeBinding = self.props.AbsoluteSizeBinding,

		ZIndex = 1,
	})


	local boardViewport = e(BoardViewport, {

		TargetAbsolutePositionBinding = self.props.AbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.props.AbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,
		FieldOfView = 30,

	})

	return e("Folder", {}, {

		Canvas = e("ScreenGui", {

			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Enabled = false,

			[Roact.Children] = {
				Canvas = canvas
			}

		}),

		BoardViewport = boardViewport,

	})

end

return GuiBoardViewer