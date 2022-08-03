-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local VRService = game:GetService("VRService")

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
local VRIO = require(script.Parent.VRIO)
local merge = Dictionary.merge

-- Drawing Tools
local Pen = require(script.Parent.VRIO.Pen)

local function inRange(self)
	local boardLookVector = self.props.CanvasCFrame.LookVector
	local boardRightVector = self.props.CanvasCFrame.RightVector

	local character = Players.LocalPlayer.Character
	if character then
		local characterVector = character:GetPivot().Position - self.props.CanvasCFrame.Position
		local normalDistance = boardLookVector:Dot(characterVector)

		local strafeDistance = boardRightVector:Dot(characterVector)
		return (0 <= normalDistance and normalDistance <= 20) and math.abs(strafeDistance) <= self.props.CanvasSize.X/2 + 5
	end
end

local SurfaceCanvas = Roact.Component:extend("SurfaceCanvas")

function SurfaceCanvas:init()
	self.ButtonPartRef = Roact.createRef()

	self.EnforceLimit = true

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

			if isInRange and not self.VRIO then
				self.VRIO = VRIO(self)

			elseif not isInRange and self.VRIO then

				if self.ToolHeld then
					self.props.Board.Remotes.FinishDrawingTask:FireServer()
				end

				self.VRIO.Destroy()
				self.VRIO = nil

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
	if self.VRIO then
		self.VRIO.Destroy()
		self.VRIO = nil
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

	local buttonPart do
		--[[
			The board should only be clickable if the client isn't using VR,
			the board isn't currently loading lines and there's no other board open
			(in which case self.props.OnSurfaceClick is nil).
		--]]
		if not VRService.VREnabled and not self.EnforceLimit and self.props.OnSurfaceClick then
			buttonPart = e("Part", {

				CFrame = self.props.CanvasCFrame,
				Size = Vector3.new(self.props.CanvasSize.X, self.props.CanvasSize.Y, Config.SurfaceCanvas.CanvasThickness),

				Transparency = 1,
				["CanQuery"] = true,
				Anchored = true,
				CanCollide = false,
				CastShadow = false,

				[Roact.Ref] = self.ButtonPartRef,

				[Roact.Children] = {

					ClickDetector = e("ClickDetector", {

						MaxActivationDistance = math.huge,

					}),

					ButtonGui = e("SurfaceGui", {

						Adornee = self.ButtonPartRef,

						[Roact.Children] = e("TextButton", {

							Text = "",
							BackgroundTransparency = 1,

							Position = UDim2.fromScale(0,0),
							Size = UDim2.fromScale(1,1),

							[Roact.Event.Activated] = self.props.OnSurfaceClick,

						})

					})

				}

			})
		end
	end

	--[[
		This commented out stuff is for putting all of the lines within a viewportframe.
		This saves massively on fps but it's unfortunately low resolution.
	--]]
	

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

			SurfaceClickPart = buttonPart,

			BoardStatView = Config.Debug and e(BoardStatView, merge(self.props, {

				LineCount = lineCount,
				UnverifiedDrawingTasks = self.state.UnverifiedDrawingTasks,

			}))
		},
	})
end

return SurfaceCanvas
