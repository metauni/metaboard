-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

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
-- local Pen = require(script.Parent.VRIO.Pen)

local function inRange(self)

	local instance = self.props.Board._instance

	if not instance:IsDescendantOf(workspace) then
		
		return false
	end

	local boardLookVector = self.state.CanvasCFrame.LookVector
	local boardRightVector = self.state.CanvasCFrame.RightVector

	local character = Players.LocalPlayer.Character
	if character then
		local characterVector = character:GetPivot().Position - self.state.CanvasCFrame.Position
		local normalDistance = boardLookVector:Dot(characterVector)

		local strafeDistance = boardRightVector:Dot(characterVector)
		return (0 <= normalDistance and normalDistance <= 20) and math.abs(strafeDistance) <= self.state.CanvasSize.X/2 + 5
	end
end

local SurfaceCanvas = Roact.Component:extend("SurfaceCanvas")

function SurfaceCanvas:init()
	self.ButtonPartRef = Roact.createRef()

	local loading
	if next(self.props.Figures) then
		self.LineLimit = 0
		self.LineCount = 0
		self.ReverseOrderedFigureEntries = Array.sort(Dictionary.entries(self.props.Figures), function(entry1, entry2)
			return entry1[2].ZIndex > entry2[2].ZIndex
		end)
		self.LoadedFigures = {}

		loading = true
	else
		if self.props.LineLoadFinishedCallback then
			self.props.LineLoadFinishedCallback()
		end
		loading = false
	end

	local parent do
		
		local instance = self.props.Board._instance

		if instance:IsDescendantOf(workspace) then
			
			parent = self.props.WorkspaceTarget

		else

			parent = self.props.StorageTarget
		end
	end

	self:setState({
		Loading = loading,
		UnverifiedDrawingTasks = {},
		CurrentUnverifiedDrawingTaskId = Roact.None,
		Parent = parent,
		CanvasCFrame = self.props.Board.SurfaceCFrame,
		CanvasSize = self.props.Board.SurfaceSize,
	})
end

function SurfaceCanvas:didMount()

	self.InRangeChecker = coroutine.create(function()
		while true do
			task.wait(1)

			local isInRange = inRange(self)

			if isInRange and not self.VRIO then
				self.VRIO = VRIO(self)

			elseif not isInRange and self.VRIO then

				if self.state.ToolHeld then
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

	local instance = self.props.Board._instance

	self.ParentConnection =  instance.AncestryChanged:Connect(function()
		
		if instance:IsDescendantOf(workspace) then
			
			self:setState({

				Parent = self.props.WorkspaceTarget
			})
			
		else
			
			self:setState({

				Parent = self.props.StorageTarget
			})
		end
	end)

	self.CFrameConnection = instance:FindFirstChild("SurfaceCFrameValue").Changed:Connect(function(cframe)
		
		self:setState({

			CanvasCFrame = cframe,
		})
	end)

end

function SurfaceCanvas:willUnmount()

	if self.VRIO then
		self.VRIO.Destroy()
		self.VRIO = nil
	end

	coroutine.close(self.InRangeChecker)
	self.ParentConnection:Disconnect()
	self.CFrameConnection:Disconnect()
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

function SurfaceCanvas:shouldUpdate(nextProps, nextState)
	if nextState.Loading and nextProps.BudgetThisFrame then

		self.LineLimit += nextProps.BudgetThisFrame

		local changed = false
		while self.LineCount <= self.LineLimit and #self.ReverseOrderedFigureEntries > 0 do
			local nextFigureEntry = self.ReverseOrderedFigureEntries[#self.ReverseOrderedFigureEntries]
			local figureId, figure = nextFigureEntry[1], nextFigureEntry[2]

			local figureLineCount
			if figure.Type == "Curve" then
				figureLineCount = #figure.Points-1
			else
				figureLineCount = 1
			end

			if self.LineCount + figureLineCount <= self.LineLimit then
				self.LoadedFigures[figureId] = figure
				self.LineCount += figureLineCount

				self.ReverseOrderedFigureEntries[#self.ReverseOrderedFigureEntries] = nil
				changed = true
			else
				break
			end
		end

		return changed
	else
		return not (Dictionary.equals(self.props, nextProps) and Dictionary.equals(self.state, nextState))
	end
end

function SurfaceCanvas:didUpdate(previousProps, previousState)
	if self.state.Loading and #self.ReverseOrderedFigureEntries == 0 then
		if self.props.LineLoadFinishedCallback then
			self.props.LineLoadFinishedCallback()
		end
		self:setState({
			Loading = false
		})
	end
end

function SurfaceCanvas:render()

	local allFigures
	local figureMaskBundles

	if self.state.Loading then

		allFigures = self.LoadedFigures
		figureMaskBundles = {}

	else

		allFigures = table.clone(self.props.Figures)
		figureMaskBundles = {}

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
	end

	local partFigures = e(PartCanvas, {

		Figures = allFigures,
		FigureMaskBundles = figureMaskBundles,

		CanvasSize = self.state.CanvasSize,
		CanvasCFrame = self.state.CanvasCFrame,

		AsFragment = true,
	})

	local buttonPart do
		--[[
			The board should only be clickable if the client isn't using VR,
			the board isn't currently loading lines and there's no other board open
			(in which case self.props.OnSurfaceClick is nil).
		--]]
		if not VRService.VREnabled and not self.Loading then
			buttonPart = e("Part", {

				CFrame = self.state.CanvasCFrame,
				Size = Vector3.new(self.state.CanvasSize.X, self.state.CanvasSize.Y, Config.SurfaceCanvas.CanvasThickness),

				Transparency = 1,
				["CanQuery"] = true,
				Anchored = true,
				CanCollide = false,
				CastShadow = false,

				[Roact.Ref] = self.ButtonPartRef,

				[Roact.Children] = {

					ClickDetector = e("ClickDetector", {

						MaxActivationDistance = self.props.OnSurfaceClick and math.huge or 0,

					}),

					ButtonGui = e("SurfaceGui", {

						Adornee = self.ButtonPartRef,

						[Roact.Children] = e("TextButton", {

							Text = "",
							BackgroundTransparency = 1,

							Position = UDim2.fromScale(0,0),
							Size = UDim2.fromScale(1,1),

							[Roact.Event.Activated] = self.props.OnSurfaceClick or nil,

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

	return e(Roact.Portal, {

		target = self.state.Parent,
		
	}, {
		
			[self.props.Board:FullName()] = e("Model", {
			-- Adornee = board._surfacePart,

			[Roact.Children] = {
				Figures = partFigures,

				SurfaceClickPart = buttonPart,

				BoardStatView = Config.Debug and e(BoardStatView, merge(self.props, {

					UnverifiedDrawingTasks = self.state.UnverifiedDrawingTasks,

				}))
			},
		})
	})
end

return SurfaceCanvas
