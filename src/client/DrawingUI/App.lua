-- Services
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary

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

	local figures = table.clone(self.props.Board.Figures)
	local bundledFigureMasks = {}
	for taskId, drawingTask in pairs(self.props.Board.DrawingTasks) do
		if drawingTask.TaskType == "Erase" then
			bundledFigureMasks[taskId] = drawingTask:Render(self.props.Board)
		else
			figures[taskId] = drawingTask:Render()
		end
	end

	self:setState({

		Figures = figures,

		BundledFigureMasks = bundledFigureMasks,

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

	local cursorWidth, cursorColor do
		if self.state.EquippedTool == Eraser then
			cursorWidth = Config.Drawing.EraserStrokeWidths[self.state.SelectedEraserSizeName]
			cursorColor = Config.UITheme.Highlight
		else
			cursorWidth = self.state.StrokeWidths[self.state.SelectedStrokeWidthName]
			cursorColor = self.state.ColorWells[self.state.SelectedColorWellIndex].Color
		end
	end

	local cursor = e(Cursor, {
		Size = UDim2.fromOffset(cursorWidth, cursorWidth),
		Position = self.ToolPosBinding:map(function(toolPos)
			return UDim2.fromOffset(toolPos.X, toolPos.Y)
		end),
		Color = cursorColor
	})

	local boardViewport = e(BoardViewport, {
		TargetAbsolutePositionBinding = self.CanvasAbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.CanvasAbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,
	})


	return e("ScreenGui", {

		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Roact.Children] = {

			Toolbar = toolbar,

			CanvasBox = canvasBox,

			CanvasIO = canvasIO,

			Cursor = cursor,

			Canvas = e(Canvas, {

				Figures = self.state.Figures,

				BundledFigureMasks = self.state.BundledFigureMasks,

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

function App:ToolDown(canvasPos)
	local drawingTask = self.state.EquippedTool.newDrawingTask(self)


	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)
	end

	drawingTask:Init(self.props.Board, canvasPos)

	self:setState(function(state)

		return Dictionary.merge(self:stateForUpdatedDrawingTask(state, drawingTask), {

			ToolHeld = true,

			CurrentDrawingTask = drawingTask,

		})
	end)

end

function App:ToolMoved(canvasPos)
	if not self.state.ToolHeld then return end

	local drawingTask = self.state.CurrentDrawingTask

	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.UpdateDrawingTask:FireServer(canvasPos)
	end

	drawingTask:Update(self.props.Board, canvasPos)

	self:setState(function(state)
		return self:stateForUpdatedDrawingTask(state, drawingTask)
	end)
end

function App:ToolUp()
	if not self.state.ToolHeld then return end

	local drawingTask = self.state.CurrentDrawingTask

	drawingTask:Finish()

	if not self.props.SilenceRemoteEventFire then
		self.props.Board.Remotes.FinishDrawingTask:FireServer()
	end

	self:setState(function(state)

		return Dictionary.merge(self:stateForUpdatedDrawingTask(state, drawingTask), {

			ToolHeld = false,

			CurrentDrawingTask = Roact.None,

		})
	end)

end

function App:stateForUpdatedDrawingTask(state, drawingTask)

	local renderTarget, rendering do
		if drawingTask.TaskType == "Erase" then
			renderTarget = "BundledFigureMasks"
			rendering = drawingTask:Render()
			if rendering == state.BundledFigureMasks[drawingTask.TaskId] then
				return nil
			end
		else
			renderTarget = "Figures"
			rendering = drawingTask:Render()
		end
	end 


	return {

		[renderTarget] = Dictionary.merge(state[renderTarget], {
			[drawingTask.TaskId] = rendering
		})
	
	}
end

function App:didMount()

	if self.props.SilenceRemoteEventFire then return end

	self.drawingTaskChangedConnection = self.props.Board.DrawingTaskChangedSignal:Connect(function(drawingTask, player, changeType: "Init" | "Update" | "Finish")
		--[[
			Internally, this drawing app only creates, modifies and renders the "unverified" drawing tasks for the local client to see
			immediately. The verified drawing tasks are handled by BoardClient, and this app relies on DrawingTaskChangedSignal
			to be notified of changes to verified drawing tasks.

			The desired behaviour is that the client sees the rendering of the unverified drawing task while they are drawing it,
			and once the verified version is "finished", they switch to seeing that one.

			However if the drawingTask is an "Erase", then we need to re-render whatever was touched by the eraser, not the
			eraser drawing task itself. This is the behaviour regardless of who is erasing (local client or not), because the
			local client is drawing unverified ghosts over the lines they are erasing, and it's nice to see them disappear
			underneath when the verified erase task comes back from the server.
		--]]

		if player == Players.LocalPlayer then

			if changeType == "Finish" then


				self:setState(function(state)

					return self:stateForUpdatedDrawingTask(state, drawingTask)

				end)

			end
		else

			-- This is from another player, just make their change immediately
			self:setState(function(state)

				return self:stateForUpdatedDrawingTask(state, drawingTask)

			end)
		end

	end)
end

function App:willUnmount()

	if self.props.SilenceRemoteEventFire then return end

	self.drawingTaskChangedConnection:Disconnect()
end

return App