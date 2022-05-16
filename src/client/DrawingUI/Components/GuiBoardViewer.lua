-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Workspace = game:GetService("Workspace")
local Client = script.Parent.Parent.Parent

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local DrawingTask = require(Common.DrawingTask)
local RoactSpring = require(Common.Packages.RoactSpring)


-- Components
local FrameCanvas = require(Client.FrameCanvas)
local BoardViewport = require(script.Parent.BoardViewport)

local GuiBoardViewer = Roact.PureComponent:extend("GuiBoardViewer")

function GuiBoardViewer:init()
	self.spring, self.api = RoactSpring.Controller.new({
		alpha = 0,
	})
end

function GuiBoardViewer:didMount()
	self.api:start({ 
		alpha = 1,
		config = { mass = 0.01, tension = 100, friction = 3, clamp = false },
	}):andThen(function()
		self:setState({
			IntroAnimationDone = true,
		})
	end)
end

function GuiBoardViewer:willUnmount()
	print("unmount")
end

function GuiBoardViewer:render()


	local canvas = self.state.IntroAnimationDone and e(FrameCanvas, {

		Figures = self.props.Figures,

		FigureMaskBundles = self.props.FigureMaskBundles,

		AbsolutePositionBinding = self.props.AbsolutePositionBinding,
		AbsoluteSizeBinding = self.props.AbsoluteSizeBinding,

		ZIndex = 1,
	}) or nil


	local boardViewport = e(BoardViewport, {
		SpringAlphaBinding = self.spring.alpha,

		TargetAbsolutePositionBinding = self.props.AbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.props.AbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,
	})

	return e("Folder", {}, {

		Canvas = canvas,

		BoardViewport = boardViewport,

	})
	
end

return GuiBoardViewer