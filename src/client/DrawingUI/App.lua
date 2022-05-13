-- Services
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local set = Dictionary.set
local merge = Dictionary.merge

-- Drawing Tools
local DrawingTools = script.Parent.DrawingTools
local Pen = require(DrawingTools.Pen)
local StraightEdge = require(DrawingTools.StraightEdge)
local Eraser = require(DrawingTools.Eraser)

-- Components
local Components = script.Parent.Components
local ConstrainedBox = require(Components.ConstrainedBox)
local Canvas = require(Components.Canvas)
local CanvasIO = require(Components.CanvasIO)
local BoardViewport = require(Components.BoardViewport)
local Toolbar = require(Components.Toolbar)
local Cursor = require(Components.Cursor)
local ConfirmClearModal = require(Components.ConfirmClearModal)

-- Constants
-- local CANVAS_REGION_POSITION = UDim2.fromScale(0, 0)
-- local CANVAS_REGION_SIZE = UDim2.fromScale(1,1)
local CANVAS_REGION_POSITION = UDim2.new(0, 50 , 0, 150)
local CANVAS_REGION_SIZE = UDim2.new(1,-100,1,-200)

local App = Roact.PureComponent:extend("App")

function App:init()

	self.CanvasAbsolutePositionBinding, self.SetCanvasAbsolutePosition = Roact.createBinding(Vector2.new(0,0))
	self.CanvasAbsoluteSizeBinding, self.SetCanvasAbsoluteSize = Roact.createBinding(Vector2.new(100,100))

	self.ToolPosBinding, self.SetToolPos = Roact.createBinding(Vector2.new(0,0))

	-- local figures = table.clone(self.props.Board.Figures)
	-- local bundledFigureMasks = {}
	-- for taskId, drawingTask in pairs(self.props.Board.DrawingTasks) do
	-- 	if drawingTask.Type == "Erase" then
	-- 		bundledFigureMasks[taskId] = drawingTask:Render(self.props.Board)
	-- 	else
	-- 		figures[taskId] = drawingTask:Render()
	-- 	end
	-- end

	self:setState({

		-- Figures = figures,

		-- BundledFigureMasks = bundledFigureMasks,

		ToolHeld = false,
		SubMenu = Roact.None,
		EquippedTool = Pen,
		SelectedEraserSizeName = "Small",
		StrokeWidths = {
			Small = Config.Drawing.Defaults.SmallStrokeWidth,
			Medium = Config.Drawing.Defaults.MediumStrokeWidth,
			Large = Config.Drawing.Defaults.LargeStrokeWidth,
		},
		SelectedStrokeWidthName = "Small",
		ColorWells = {
			{
				BaseName = "White",
				Color = Config.ColorPalette.White.BaseColor,
			},
			{
				BaseName = "Black",
				Color = Config.ColorPalette.Black.BaseColor,
			},
			{
				BaseName = "Blue",
				Color = Config.ColorPalette.Blue.BaseColor,
			},
			{
				BaseName = "Green",
				Color = Config.ColorPalette.Green.BaseColor,
			},
			{
				BaseName = "Red",
				Color = Config.ColorPalette.Red.BaseColor,
			},
		},
		SelectedColorWellIndex = 3,

		UnverifiedDrawingTasks = {},
		CurrentUnverifiedDrawingTaskId = nil
	})
end

function App:render()

	local toolbar = e(Toolbar, {

		SubMenu = self.state.SubMenu,
		SetSubMenu = function(subMenu)
			self:setState({ SubMenu = subMenu })
		end,

		EquippedTool = self.state.EquippedTool,
		EquipTool = function(tool)
			self:setState({ EquippedTool = tool })
		end,

		StrokeWidths = self.state.StrokeWidths,
		SelectedStrokeWidthName = self.state.SelectedStrokeWidthName,
		SelectStrokeWidth = function(name)
			self:setState({ SelectedStrokeWidthName = name })
		end,
		UpdateStrokeWidth = function(strokeWidth)
			self:setState({

				StrokeWidths = Dictionary.merge(self.state.StrokeWidths,{
					[self.state.SelectedStrokeWidthName] = strokeWidth
				})

			})
		end,

		SelectedEraserSizeName = self.state.SelectedEraserSizeName,
		SelectEraserSize = function(name)
			self:setState({ SelectedEraserSizeName = name })
		end,

		ColorWells = self.state.ColorWells,
		SelectedColorWellIndex = self.state.SelectedColorWellIndex,
		SelectColorWell = function(index)
			self:setState({ SelectedColorWellIndex = index })
		end,
		UpdateColorWell = function(index, shadedColor)
			self:setState({
				ColorWells = Dictionary.merge(self.state.ColorWells, {
					[index] = shadedColor
				})
			})
		end,

		CanUndo = self.props.CanUndo,
		CanRedo = self.props.CanRedo,
		CanClear = next(self.props.Figures) or next(self.props.DrawingTasks),

		OnUndo = function()
			self.props.Board.Remotes.Undo:FireServer()
		end,
		OnRedo = function()
			self.props.Board.Remotes.Redo:FireServer()
		end,

		OnCloseButtonClick = function()
			self.props.OnClose()
		end,

	})

	local ConfirmClearModalGui = self.state.SubMenu == "ClearModal" and e("ScreenGui", {

		DisplayOrder = 10,
		IgnoreGuiInset = true,

		[Roact.Children] = {

			Window = e(ConfirmClearModal, {

				OnCancel = function()
					
					self:setState({
						SubMenu = Roact.None
					})

				end,

				OnConfirm = function()

					if not self.props.SilenceRemoteEventFire then
						self.props.Board.Remotes.Clear:FireServer()
					end

					self:setState({
						SubMenu = Roact.None
					})
				
				end,

			})

		}
	}) or nil

	local canvasBox = e(ConstrainedBox, {

		Position = CANVAS_REGION_POSITION,
		Size = CANVAS_REGION_SIZE,
		AspectRatio = self.props.AspectRatio,

		OnAbsolutePositionUpdate = self.SetCanvasAbsolutePosition,
		OnAbsoluteSizeUpdate = self.SetCanvasAbsoluteSize,

	})

	local canvasIO = e(CanvasIO, {

		IgnoreGuiInset = true,

		AbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
		AbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,

		SetCursorPosition = self.SetToolPos,

		ToolDown = function(canvasPos)
			self:ToolDown(canvasPos)
			self:setState({ SubMenu = Roact.None })
		end,
		ToolMoved = function(canvasPos)
			self:ToolMoved(canvasPos)
		end,
		ToolUp = function()
			self:ToolUp()
		end,

	})

	-- local cursorWidth, cursorColor do
	-- 	if self.state.EquippedTool == Eraser then
	-- 		cursorWidth = Config.Drawing.EraserStrokeWidths[self.state.SelectedEraserSizeName]
	-- 		cursorColor = Config.UITheme.Highlight
	-- 	else
	-- 		cursorWidth = self.state.StrokeWidths[self.state.SelectedStrokeWidthName]
	-- 		cursorColor = self.state.ColorWells[self.state.SelectedColorWellIndex].Color
	-- 	end
	-- end

	-- local cursor = e(Cursor, {
	-- 	Size = UDim2.fromOffset(cursorWidth, cursorWidth),
	-- 	Position = self.ToolPosBinding:map(function(toolPos)
	-- 		return UDim2.fromOffset(toolPos.X, toolPos.Y)
	-- 	end),
	-- 	Color = cursorColor
	-- })

	local boardViewport = e(BoardViewport, {
		TargetAbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,
	})

	local figureMaskBundles = {}
	local allFigures = table.clone(self.props.Figures)

	for taskId, drawingTask in pairs(self.props.DrawingTasks) do

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

	return e("ScreenGui", {

		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Roact.Children] = {

			Toolbar = toolbar,

			CanvasBox = canvasBox,

			CanvasIO = canvasIO,

			-- Cursor = cursor,

			ConfirmClearModalGui = ConfirmClearModalGui,

			Canvas = e(Canvas, {

				Figures = allFigures,

				FigureMaskBundles = figureMaskBundles,

				AbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
				AbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,

				CanvasSize = self.props.Board:SurfaceSize(),
				CanvasCFrame = CFrame.identity,

				ZIndex = 1,

			}),

			BoardViewport = boardViewport,

		}
	})
end

function App.getDerivedStateFromProps(nextProps, lastState)

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

function App:ToolDown(canvasPos)
	local drawingTask = self.state.EquippedTool.newDrawingTask(self)

	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)
	end

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self.props.Board, canvasPos)

	self:setState(function(state)

		return {

			ToolHeld = true,

			CurrentUnverifiedDrawingTaskId = initialisedDrawingTask.Id,

			UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, initialisedDrawingTask.Id, initialisedDrawingTask),

		}
	end)

end

function App:ToolMoved(canvasPos)
	if not self.state.ToolHeld then return end

	local drawingTask = self.state.UnverifiedDrawingTasks[self.state.CurrentUnverifiedDrawingTaskId]

	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.UpdateDrawingTask:FireServer(canvasPos)
	end

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self.props.Board, canvasPos)

	self:setState(function(state)
		return {

			UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, updatedDrawingTask.Id, updatedDrawingTask),

		}
	end)
end

function App:ToolUp()
	if not self.state.ToolHeld then return end

	local drawingTask = self.state.UnverifiedDrawingTasks[self.state.CurrentUnverifiedDrawingTaskId]

	local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, self.props.Board), "Finished", true)

	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.FinishDrawingTask:FireServer()
	end

	self:setState(function(state)

		return {

			ToolHeld = false,

			CurrentUnverifiedDrawingTaskId = Roact.None,

			UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, finishedDrawingTask.Id, finishedDrawingTask),

		}
	end)

end


return App