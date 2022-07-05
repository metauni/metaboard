-- Services
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local DrawingTask = require(Common.DrawingTask)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local set = Dictionary.set
local merge = Dictionary.merge

-- Array Operations
local Array = Sift.Array
local slice = Array.slice

-- Drawing Tools
local DrawingTools = script.Parent.DrawingTools
local Pen = require(DrawingTools.Pen)
local StraightEdge = require(DrawingTools.StraightEdge)
local Eraser = require(DrawingTools.Eraser)

-- Components
local Components = script.Parent.Components
local ConstrainedBox = require(Components.ConstrainedBox)
local CanvasIO = require(Components.CanvasIO)
local GuiBoardViewer = require(Components.GuiBoardViewer)
local WorkspaceBoardViewer = require(Components.WorkspaceBoardViewer)
local Toolbar = require(Components.Toolbar)
local Cursor = require(Components.Cursor)
local ConfirmClearModal = require(Components.ConfirmClearModal)
local EraseGridDebug = require(Components.EraseGridDebug)

-- Constants
-- local CANVAS_REGION_POSITION = UDim2.fromScale(0, 0)
-- local CANVAS_REGION_SIZE = UDim2.fromScale(1,1)
local CANVAS_REGION_POSITION = UDim2.new(0, 50 , 0, 100)
local CANVAS_REGION_SIZE = UDim2.new(1,-100,1,-125)

-- Helper functions
local toolFunctions = require(script.Parent.toolFunctions)

local App = Roact.PureComponent:extend("App")

function App:init()

	self.CanvasAbsolutePositionBinding, self.SetCanvasAbsolutePosition = Roact.createBinding(Vector2.new(0,0))
	self.CanvasAbsoluteSizeBinding, self.SetCanvasAbsoluteSize = Roact.createBinding(Vector2.new(100,100))

	self.ToolPosBinding, self.SetToolPos = Roact.createBinding(Vector2.new(0,0))

	local toolState do

		if self.props.Board.ToolState then
			toolState = self.props.Board.ToolState
		else

			local colorWells = {
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
			}

			if self.props.Board.DefaultColorWells then
				for i=1, 5 do
					colorWells[i] = self.props.Board.DefaultColorWells[i] or colorWells[i]
				end
			end

			toolState = {
				EquippedTool = Pen,
				SelectedEraserSizeName = "Small",
				StrokeWidths = {
					Small = Config.Drawing.Defaults.SmallStrokeWidth,
					Medium = Config.Drawing.Defaults.MediumStrokeWidth,
					Large = Config.Drawing.Defaults.LargeStrokeWidth,
				},
				SelectedStrokeWidthName = "Small",
				SelectedColorWellIndex = 1,
				ColorWells = colorWells,
			}

		end

	end

	self.ToolQueue = {}

	RunService:BindToRenderStep("ToolQueue", Enum.RenderPriority.First.Value, function()
		if #self.ToolQueue > 0 then
			self:setState(function(state)
				local stateUpdate = {}
				for i, action in ipairs(self.ToolQueue) do
					stateUpdate = merge(stateUpdate, action(merge(state, stateUpdate)))
				end

				return stateUpdate
			end)
			self.ToolQueue = {}
		end
	end)

	self:setState({

		ToolHeld = false,
		ToolState = toolState,
		SubMenu = Roact.None,
		UnverifiedDrawingTasks = {},
		CurrentUnverifiedDrawingTaskId = nil,

	})
end

function App:willUnmount()
	RunService:UnbindFromRenderStep("ToolQueue")
	self.props.Board.ToolState = self.state.ToolState
end

function App:render()

	local toolState = self.state.ToolState

	local setToolState = function(stateSlice)

		self:setState({
			ToolState = merge(toolState, stateSlice)
		})

	end

	local toolbar = e(Toolbar, {

		SubMenu = self.state.SubMenu,
		SetSubMenu = function(subMenu)
			self:setState({ SubMenu = subMenu })
		end,

		EquippedTool = toolState.EquippedTool,
		EquipTool = function(tool)
			setToolState({ EquippedTool = tool })
		end,

		StrokeWidths = toolState.StrokeWidths,
		SelectedStrokeWidthName = toolState.SelectedStrokeWidthName,
		SelectStrokeWidth = function(name)
			setToolState({ SelectedStrokeWidthName = name })
		end,
		UpdateStrokeWidth = function(strokeWidth)
			setToolState({

				StrokeWidths = merge(toolState.StrokeWidths,{
					[toolState.SelectedStrokeWidthName] = strokeWidth
				})

			})
		end,

		SelectedEraserSizeName = toolState.SelectedEraserSizeName,
		SelectEraserSize = function(name)
			setToolState({ SelectedEraserSizeName = name })
		end,

		ColorWells = toolState.ColorWells,
		SelectedColorWellIndex = toolState.SelectedColorWellIndex,
		SelectColorWell = function(index)
			setToolState({ SelectedColorWellIndex = index })
		end,
		UpdateColorWell = function(index, shadedColor)
			setToolState({
				ColorWells = merge(toolState.ColorWells, {
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

		DisplayOrder = self.props.NextFigureZIndex + 11,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

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

	local cursorWidth, cursorColor do
		if toolState.EquippedTool == Eraser then
			cursorWidth = Config.Drawing.EraserStrokeWidths[toolState.SelectedEraserSizeName]
			cursorColor = Config.UITheme.Highlight
		else
			cursorWidth = toolState.StrokeWidths[toolState.SelectedStrokeWidthName]
			cursorColor = toolState.ColorWells[toolState.SelectedColorWellIndex].Color
		end
	end

	local cursor = e(Cursor, {
		Width = cursorWidth,
		Position = self.ToolPosBinding:map(function(toolPos)
			return UDim2.fromOffset(toolPos.X, toolPos.Y)
		end),
		Color = cursorColor,
	})

	if UserInputService.TouchEnabled and not self.state.ToolHeld then
		cursor = nil
	end

	local toolBarGui = e("ScreenGui", {

		DisplayOrder = self.props.NextFigureZIndex + 10,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Roact.Children] = {
			Toolbar = toolbar,

			Cursor = cursor
		}

	})

	local canvasIO = e(CanvasIO, {

		IgnoreGuiInset = true,

		AbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
		AbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,
		Margin = toolState.EquippedTool ~= Eraser and cursorWidth or 0,

		CursorPositionBinding = self.ToolPosBinding,
		SetCursorPosition = self.SetToolPos,

		ToolHeld = self.state.ToolHeld,

		QueueToolDown = function(canvasPos)
			table.insert(self.ToolQueue, function(state)
				return toolFunctions.ToolDown(self, state, canvasPos)
			end)
		end,
		QueueToolMoved = function(canvasPos)
			table.insert(self.ToolQueue, function(state)
				return toolFunctions.ToolMoved(self, state, canvasPos)
			end)
		end,
		QueueToolUp = function(canvasPos)
			table.insert(self.ToolQueue, function(state)
				return toolFunctions.ToolUp(self, state)
			end)
		end,
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

	local BoardViewerComponent do
		local comp = {
			Workspace = WorkspaceBoardViewer,
			Gui = GuiBoardViewer,
		}

		BoardViewerComponent = comp[self.props.BoardViewMode]
	end

	local boardViewer = e(BoardViewerComponent, {

		Figures = allFigures,

		FigureMaskBundles = figureMaskBundles,

		AbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
		AbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,

		Board = self.props.Board,

		ZIndex = 1,

	})

	local eraseGridDebug = Config.Debug and e(EraseGridDebug, {

		Board = self.props.Board,

		AbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,
		AbsolutePositionBinding = self.CanvasAbsolutePositionBinding,


	}) or nil


	return e("ScreenGui", {

		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Roact.Children] = {

			ToolbarGui = toolBarGui,

			CanvasBox = canvasBox,

			CanvasIO = canvasIO,

			ConfirmClearModalGui = ConfirmClearModalGui,

			BoardViewer = boardViewer,

			EraseGridDebug = eraseGridDebug,

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



return App