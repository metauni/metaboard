-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local PartCanvas = require(script.Parent.Parent.PartCanvas)
local CanvasViewport = require(script.Parent.CanvasViewport)

local SurfaceCanvas = Roact.PureComponent:extend("SurfaceCanvas")

function SurfaceCanvas:init()
	self.EnforceLimit = true
	self.LoadedAllUnderLimit = false

	self:setState({
		LineLimit = 0,
	})
end

function SurfaceCanvas:didMount()
	task.spawn(function()
		debug.setmemorycategory("BoardController surfacecanvas (heap)")
		while self.EnforceLimit do
			task.wait(0.1)
			self:setState(function(prevState)

				return {
					LineLimit = prevState.LineLimit + 500
				}
			end)
		end

		self.props.LineLoadFinishedCallback()
		print "Finished Loading"
	end)
end

function SurfaceCanvas:render()
	local board = self.props.Board

	local figureMaskBundles = {}
	local lineCount = 0

	local allFigures do
		if self.EnforceLimit then

			allFigures = {}

			for figureId, figure in pairs(board.Figures) do
				if figure.Type == "Curve" then
					lineCount += #figure.Points
				else
					lineCount += 1
				end

				allFigures[figureId] = figure

				if lineCount > self.state.LineLimit then
					break
				end
			end

		else
			allFigures = table.clone(board.Figures)

		end
	end

	for taskId, drawingTask in pairs(board.DrawingTasks) do

		if drawingTask.Type == "Erase" then
			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			for figureId, figureMask in pairs(figureIdToFigureMask) do
				local bundle = figureMaskBundles[figureId] or {}
				bundle[taskId] = figureMask
				figureMaskBundles[figureId] = bundle
			end

		else
			local figure = DrawingTask.Render(drawingTask)

			if self.EnforceLimit then
				if figure.Type == "Curve" then
					lineCount += #figure.Points
				else
					lineCount += 1
				end

				if lineCount > self.state.LineLimit then
					break
				end

			end

			allFigures[taskId] = figure
		end
	end

	if self.EnforceLimit and lineCount <= self.state.LineLimit then
		self.EnforceLimit = false
	end

 local partFigures = e(PartCanvas, {

		Figures = allFigures,
		FigureMaskBundles = figureMaskBundles,

		CanvasSize = board:SurfaceSize(),
		CanvasCFrame = board:SurfaceCFrame(),

		AsFragment = true,

	})

	-- local canvasViewport = e(CanvasViewport, {

	-- 	Board = board,
	-- 	FieldOfView = 70,

	-- 	[Roact.Children] = partFigures

	-- })

	-- return e("SurfaceGui", {
	-- 	Adornee = board._surfacePart,

	-- 	[Roact.Children] = canvasViewport,
	-- })

	return e("Model", {
		-- Adornee = board._surfacePart,

		[Roact.Children] = partFigures,
	})

end

return SurfaceCanvas