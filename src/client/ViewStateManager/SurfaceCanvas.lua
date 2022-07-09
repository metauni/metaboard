-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Components
local PartCanvas = require(script.Parent.Parent.PartCanvas)
local CanvasViewport = require(script.Parent.CanvasViewport)
local BoardStatView = require(script.Parent.BoardStatView)

-- Helper Functions
local VRDummy = require(script.Parent.VRDummy)
local merge = Dictionary.merge

-- Drawing Tools
local Pen = require(script.Parent.VRDummy.Pen)

local character = Players.LocalPlayer.CharacterAdded:Wait()

local function inRange(self)
	local boardLookVector = self.props.CanvasCFrame.LookVector
	local boardRightVector = self.props.CanvasCFrame.RightVector

	local characterVector = character:GetPivot().Position - self.props.CanvasCFrame.Position
	local normalDistance = boardLookVector:Dot(characterVector)

	local strafeDistance = boardRightVector:Dot(characterVector)
	return (0 <= normalDistance and normalDistance <= 20) and math.abs(strafeDistance) <= self.props.CanvasSize.X/2 + 5
end

local SurfaceCanvas = Roact.Component:extend("SurfaceCanvas")

function SurfaceCanvas:init()
	self.EnforceLimit = true
	self.LoadedAllUnderLimit = false

	self:setState({
		LineLimit = 0,
		UnverifiedDrawingTasks = {},
		CurrentUnverifiedDrawingTaskId = Roact.None,
	})
end

function SurfaceCanvas:didMount()

	task.spawn(function()
		debug.setmemorycategory("SurfaceCanvas (heap)")
		while self.EnforceLimit do
			task.wait(math.random() * 0.01)
			local budget = self.props.GetLineBudget()

			if budget > 0 then
				self:setState(function(prevState)
					return {
						LineLimit = prevState.LineLimit + budget,
					}
				end)
			end
		end

		if self.props.LineLoadFinishedCallback then
			self.props.LineLoadFinishedCallback()
			self:setState({
				DrawingSurfaceActive = true
			})
		end
	end)

	self.InRangeChecker = coroutine.create(function()
		while true do
			task.wait(1)

			local isInRange = inRange(self)

			if isInRange and not self.VRDummy then
				self.VRDummy = VRDummy(self)

			elseif not isInRange and self.VRDummy then

				if self.ToolHeld then
					self.props.Board.Remotes.FinishDrawingTask:FireServer()
				end

				self.VRDummy.Destroy()
				self.VRDummy = nil

				self:setState({
					UnverifiedDrawingTasks = {},
					CurrentUnverifiedDrawingTaskId = Roact.None,
				})


			end
		end
	end)
	task.defer(self.InRangeChecker)
end

function SurfaceCanvas:willUnmount()
	if self.VRDummy then
		self.VRDummy.Destroy()
		self.VRDummy = nil
	end

	coroutine.close(self.InRangeChecker)
end

function SurfaceCanvas.getDerivedStateFromProps(nextProps, lastState)
	--[[
		Unverified drawing tasks should be removed when their verified version
		becomes "Finished"
	--]]

	if lastState.UnverifiedDrawingTasks == nil then
		return
	end

	local removals = {}

	for taskId, unverifiedDrawingTask in pairs(lastState.UnverifiedDrawingTasks) do
		local verifiedDrawingTask = nextProps.DrawingTasks[taskId]

		if verifiedDrawingTask and verifiedDrawingTask.Finished then
			removals[taskId] = Sift.None
		end

	end

	if next(removals) then
		return {
			UnverifiedDrawingTasks = merge(lastState.UnverifiedDrawingTasks, removals)
		}
	end

end

function SurfaceCanvas:render()
	local figureMaskBundles = {}
	local lineCount = 0

	local allFigures
	do
		if self.EnforceLimit then
			allFigures = {}

			for figureId, figure in pairs(self.props.Figures) do
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
			allFigures = table.clone(self.props.Figures)
		end
	end

	for taskId, drawingTask in pairs(self.props.DrawingTasks) do
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
					lineCount += #figure.Points-1
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

	for taskId, drawingTask in pairs(self.state.UnverifiedDrawingTasks) do

		if drawingTask.Type == "Erase" then
			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			for figureId, figureMask in pairs(figureIdToFigureMask) do
				local bundle = figureMaskBundles[figureId] or {}
				bundle[taskId] = figureMask
				figureMaskBundles[figureId] = bundle
			end

		else

			allFigures[taskId] = DrawingTask.Render(drawingTask)
		end
	end

	if self.EnforceLimit and lineCount <= self.state.LineLimit then
		self.EnforceLimit = false
	end

	local partFigures = e(PartCanvas, {

		Figures = allFigures,
		FigureMaskBundles = figureMaskBundles,

		CanvasSize = self.props.CanvasSize,
		CanvasCFrame = self.props.CanvasCFrame,

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

		[Roact.Children] = {
			Figures = partFigures,
			BoardStatView = Config.Debug and e(BoardStatView, merge(self.props, {

				LineCount = lineCount,
				UnverifiedDrawingTasks = self.state.UnverifiedDrawingTasks,

			}))
		},
	})
end

return SurfaceCanvas
