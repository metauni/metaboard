-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local root = script.Parent.Parent

-- Imports
local Config = require(root.Config)
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement
local Feather = require(root.Parent.Feather)
local FrameCanvas = require(root.FrameCanvas)
local DrawingTask = require(root.DrawingTask)
local ToolState = require(script.Parent.ToolState)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Common Operations
local merge = Dictionary.merge

-- Drawing Tools
local DrawingTools = script.Parent.DrawingTools
local Eraser = require(DrawingTools.Eraser)

-- Components
local Components = script.Parent.Components
local ConstrainedBox = require(Components.ConstrainedBox)
local CanvasIO = require(Components.CanvasIO)
local GuiBoardViewer = require(Components.GuiBoardViewer)
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
local ToolQueue = require(root.ToolQueue)

local App = Roact.PureComponent:extend("App")

function App:init()

	self.ToolPosBinding, self.SetToolPos = Roact.createBinding(UDim2.fromOffset(0,0))
	local canWrite = Players.LocalPlayer:GetAttribute("metaadmin_canwrite") ~= false

	self:setState({

		ToolHeld = false,
		ToolState = ToolState.Get(),
		SubMenu = Roact.None,
		UnverifiedDrawingTasks = {},
		CurrentUnverifiedDrawingTaskId = Roact.None,
		CanWrite = canWrite,

	})
end

local function getCanvasProps(props, state)
	
	local figureMaskBundles = {}
	local allFigures = table.clone(props.Figures)

	for taskId, drawingTask in pairs(props.DrawingTasks) do

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

	for taskId, drawingTask in pairs(state.UnverifiedDrawingTasks) do

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

	return {

		Figures = allFigures,

		FigureMaskBundles = figureMaskBundles,

		CanvasAbsolutePosition = state.CanvasAbsolutePosition,
		CanvasAbsoluteSize = state.CanvasAbsoluteSize,

		Board = props.Board,

		ZIndex = 1,
	}
end

function App:didMount()

	if self.state.CanvasAbsolutePosition and self.state.CanvasAbsoluteSize then
		
		-- This crashes Roblox if not deferred :/
		self.Canvas = Feather.mount(
			Feather.createElement(FrameCanvas, getCanvasProps(self.props, self.state)),
			Players.LocalPlayer.PlayerGui,
			"metaboardGuiCanvas"
		)
	end

	--[[
		Hide all the core gui except the chat button (so badge notifications are
		visible), and minimise the chat window.
	--]]
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	StarterGui:SetCore("ChatActive", false)

	if UserInputService.TouchEnabled then

		-- Disable character controls (annoying to accidentally trigger on mobile when board is open)
		
		local PlayerModuleInstance = Players.LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")

		if PlayerModuleInstance then
			
			local PlayerModule = require(PlayerModuleInstance)

			PlayerModule:GetControls():Disable()
		end

		-- Fix camera (annoying to accidentally move on mobile when board is open)

		if workspace.CurrentCamera.CameraType == Enum.CameraType.Custom then
			
			self._originalCamType = workspace.CurrentCamera.CameraType
			workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
		end
	end

	self.ToolQueue = ToolQueue(self)

	self.permissionConnection = Players.LocalPlayer:GetAttributeChangedSignal("metaadmin_canwrite"):Connect(function()

		self:setState(function(state)

			local canWrite = Players.LocalPlayer:GetAttribute("metaadmin_canwrite") ~= false

			if state.CanWrite ~= canWrite then

				if not canWrite then

					--[[
						Need to finish current drawing task.
						TODO: this be better achieved by "cancelling" the drawing task.
					--]]
					if self.state.CurrentUnverifiedDrawingTaskId then

						self.ToolQueue.Enqueue(function(state2)

							return merge(toolFunctions.ToolUp(self, state2), {

								UnverifiedDrawingTasks = {}
							})
						end)
					end
				end

				return {
					CanWrite = canWrite,
				}
			end
		end)
	end)
end

function App:didUpdate(prevProps, prevState)

	if 
		prevState.UnverifiedDrawingTasks ~= self.state.UnverifiedDrawingTasks
		or prevProps.Figures ~= self.props.Figures
		or prevProps.DrawingTasks ~= self.props.DrawingTasks
		or prevState.CanvasAbsolutePosition ~= self.state.CanvasAbsolutePosition
		or prevState.CanvasAbsoluteSize ~= self.state.CanvasAbsoluteSize then

		if self.state.CanvasAbsolutePosition and self.state.CanvasAbsoluteSize then
	
			if self.Canvas then
				Feather.update(self.Canvas, Feather.createElement(FrameCanvas, getCanvasProps(self.props, self.state)))
			else
				
				-- This crashes Roblox if not deferred :/
				task.defer(function()
					self.Canvas = Feather.mount(
						Feather.createElement(FrameCanvas, getCanvasProps(self.props, self.state)),
						Players.LocalPlayer.PlayerGui,
						"metaboardGuiCanvas"
					)
				end)
			end
		end
	end
end

function App:willUnmount()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

	if UserInputService.TouchEnabled then

		-- Enable Character Controls
		
		local PlayerModuleInstance = Players.LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")

		if PlayerModuleInstance then
			
			local PlayerModule = require(PlayerModuleInstance)

			PlayerModule:GetControls():Enable()
		end

		-- Un-fix camera

		if self._originalCamType then
			
			workspace.CurrentCamera.CameraType = self._originalCamType
		end

		self._originalCamType = nil
	end

	self.ToolQueue.Destroy()
	self.permissionConnection:Disconnect()

	Feather.unmount(self.Canvas)
end

function App:SetToolState(toolState)
	self:setState(function(state)

		local newToolState = merge(state.ToolState, toolState)
		ToolState.Set(newToolState)

		return {
			ToolState = newToolState
		}
	end)
end

function App:render()

	local toolState = self.state.ToolState

	local toolbar = e(Toolbar, {

		CanWrite = self.state.CanWrite,

		SubMenu = self.state.SubMenu,
		SetSubMenu = function(subMenu)
			self:setState({ SubMenu = subMenu })
		end,

		EquippedTool = toolState.EquippedTool,
		EquipTool = function(tool)
			self:SetToolState({ EquippedTool = tool })
		end,

		StrokeWidths = toolState.StrokeWidths,
		SelectedStrokeWidthName = toolState.SelectedStrokeWidthName,
		SelectStrokeWidth = function(name)
			self:SetToolState({ SelectedStrokeWidthName = name })
		end,
		UpdateStrokeWidth = function(strokeWidth)
			self:SetToolState({

				StrokeWidths = merge(toolState.StrokeWidths,{
					[toolState.SelectedStrokeWidthName] = strokeWidth
				})

			})
		end,

		SelectedEraserSizeName = toolState.SelectedEraserSizeName,
		SelectEraserSize = function(name)
			self:SetToolState({ SelectedEraserSizeName = name })
		end,

		ColorWells = toolState.ColorWells,
		SelectedColorWellIndex = toolState.SelectedColorWellIndex,
		SelectColorWell = function(index)
			self:SetToolState({ SelectedColorWellIndex = index })
		end,
		UpdateColorWell = function(index, shadedColor)
			self:SetToolState({
				ColorWells = merge(toolState.ColorWells, {
					[index] = shadedColor
				})
			})
		end,

		CanUndo = self.props.CanUndo,
		CanRedo = self.props.CanRedo,
		-- TODO: this ignores player histories.
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

		OnAbsolutePositionUpdate = function(absolutePosition)

			self:setState({

				CanvasAbsolutePosition = absolutePosition

			})
		end,
		OnAbsoluteSizeUpdate = function(absoluteSize)

			self:setState({

				CanvasAbsoluteSize = absoluteSize

			})
		end,

	})

	local cursorWidth, cursorColor do
		if toolState.EquippedTool == Eraser then
			cursorWidth = Config.DrawingTools.EraserStrokeWidths[toolState.SelectedEraserSizeName]
			cursorColor = Config.UITheme.Highlight
		else
			cursorWidth = toolState.StrokeWidths[toolState.SelectedStrokeWidthName]
			cursorColor = toolState.ColorWells[toolState.SelectedColorWellIndex].Color
		end
	end

	local cursor = self.state.CanWrite and e(Cursor, {
		Width = cursorWidth,
		Position = self.ToolPosBinding,
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

	local canvasIO = self.state.CanWrite and self.state.CanvasAbsolutePosition and self.state.CanvasAbsoluteSize and e(CanvasIO, {

		CanvasAbsolutePosition = self.state.CanvasAbsolutePosition,
		CanvasAbsoluteSize = self.state.CanvasAbsoluteSize,
		AspectRatio = self.props.Board.State.AspectRatio,
		Margin = toolState.EquippedTool ~= Eraser and cursorWidth or 0,

		CursorPositionBinding = self.ToolPosBinding,
		SetCursorPixelPosition = function(x,y)
			self.SetToolPos(UDim2.fromOffset(x,y))
		end,

		ToolHeld = self.state.ToolHeld,

		QueueToolDown = function(canvasPos)
			self.ToolQueue.Enqueue(function(state)
				return toolFunctions.ToolDown(self, state, canvasPos)
			end)
		end,
		QueueToolMoved = function(canvasPos)
			self.ToolQueue.Enqueue(function(state)
				return toolFunctions.ToolMoved(self, state, canvasPos)
			end)
		end,
		QueueToolUp = function()
			self.ToolQueue.Enqueue(function(state)
				return toolFunctions.ToolUp(self, state)
			end)
		end,
	})

	local boardViewer = self.state.CanvasAbsolutePosition and self.state.CanvasAbsoluteSize and e(GuiBoardViewer, {

		CanvasAbsolutePosition = self.state.CanvasAbsolutePosition,
		CanvasAbsoluteSize = self.state.CanvasAbsoluteSize,

		Board = self.props.Board,

		ZIndex = 1,

	})

	local eraseGridDebug = Config.Debug and self.state.CanvasAbsolutePosition and self.state.CanvasAbsoluteSize and e(EraseGridDebug, {

		Board = self.props.Board,

		CanvasAbsoluteSize = self.state.CanvasAbsoluteSize,
		CanvasAbsolutePosition = self.state.CanvasAbsolutePosition,

	})


	return e("ScreenGui", {

		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,

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

	for taskId in pairs(lastState.UnverifiedDrawingTasks) do
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