-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Config = require(Common.Config)
local Assets = require(Common.Assets)
local Sift = require(Common.Packages.Sift)
local Dictionary = Sift.Dictionary

-- Drawing Tools
local DrawingTools = script.Parent.Parent.DrawingTools
local Pen = require(DrawingTools.Pen)
local StraightEdge = require(DrawingTools.StraightEdge)
local Eraser = require(DrawingTools.Eraser)

-- Components
local Palette = require(script.Palette)
local StrokeButton = require(script.StrokeButton)
local CloseButton = require(script.CloseButton)
local UndoRedoButton = require(script.UndoRedoButton)
local EraserChoices = require(script.EraserChoices)
local ShadedColorSubMenu = require(script.ShadedColorSubMenu)
local StrokeWidthSubMenu = require(script.StrokeWidthSubMenu)
local ToolMenu = require(script.ToolMenu)
local LayoutFragment = require(script.Parent.LayoutFragment)

local Toolbar = Roact.Component:extend("Toolbar")

Toolbar.defaultProps = {

	ToolMenuWidth = 260,
	StrokeMenuWidth= 360,
	HistoryMenuWidth = 180,

	ButtonHeight = 50,
	ToolbarHeight = 70,
	ToolbarPosition = UDim2.new(0.5, 0, 0, 50),
	PaletteSpacing = UDim.new(0,10),
	ToolbarSpacing = UDim.new(0,20),

}

function Toolbar:render()

	local toolMenu = function(layoutOrder)
		return e(ToolMenu, {

			LayoutOrder = layoutOrder,

			Size = UDim2.fromOffset(self.props.ToolMenuWidth, self.props.ButtonHeight),

			EquippedTool = self.props.EquippedTool,
			EquipTool = function(toolName)
				self.props.EquipTool(toolName)
				self.props.SetSubMenu(Roact.None)
			end

		})
	end

	local eraserStrokeMenu = function(layoutOrder)

		return e(EraserChoices,{

			LayoutOrder = layoutOrder,

			Size = UDim2.fromOffset(self.props.StrokeMenuWidth, self.props.ButtonHeight),

			SelectedEraserSizeName = self.props.SelectedEraserSizeName,

			SelectEraserSize = function(name)
				self.props.SelectEraserSize(name)
				self.props.SetSubMenu(Roact.None)
			end,

		})
	end

	local historyButtons = function(layoutOrder)

		local undoButton = e(UndoRedoButton, {

			LayoutOrder = 1,

			Size = UDim2.fromOffset(80,80),

			Icon = Assets.undo,

			OnClick = self.props.CanUndo and function()
				self.props.OnUndo()
				self.props.SetSubMenu(Roact.None)
			end or nil,

			Clickable = self.props.CanUndo

			})

		local redoButton = e(UndoRedoButton, {

			LayoutOrder = 2,

			Size = UDim2.fromOffset(80,80),

			Icon = Assets.redo,

			OnClick = self.props.CanRedo and function()
				self.props.OnRedo()
				self.props.SetSubMenu(Roact.None)
			end or nil,

			Clickable = self.props.CanRedo

		})

		return e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(self.props.HistoryMenuWidth, self.props.ButtonHeight),
			LayoutOrder = layoutOrder,

			[Roact.Children] = {
				UIListLayout = e("UIListLayout", {
					Padding = UDim.new(0,0),
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Undo = undoButton,
				Redo = redoButton,
			}
		})
	end

	local divider = function(layoutOrder)
		return e("Frame", {
		 Size = UDim2.fromOffset(3, 50),
		 BackgroundColor3 = Config.UITheme.Highlight,
		 BackgroundTransparency = 0.5,
		 BorderSizePixel = 0,
		 LayoutOrder = layoutOrder,
	 })
	end

	local toolbarLength = self.props.ToolMenuWidth + self.props.StrokeMenuWidth + self.props.HistoryMenuWidth + 6

	local mainToolbar = e("Frame", {

		Size = UDim2.fromScale(1,1),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),

		BackgroundTransparency = 0,
		BackgroundColor3 = Config.UITheme.Background,
		BorderSizePixel = 0,

		[Roact.Children] = {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0,5) }),

			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0,0),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			LayoutFragment = e(LayoutFragment, {
				OrderedLayoutElements = {
					{"ToolMenu", toolMenu},
					{"StrokeMenuLeftDivider", divider},
					{"StrokeMenu", self.props.EquippedTool == Eraser and eraserStrokeMenu or self:ColoredStrokeMenu()},
					{"StrokeMenuRightDivider", divider},
					{"HistoryButtons", historyButtons},
				}
			}),
		}
	})

	

	return e("Frame", {
		Size = UDim2.fromOffset(toolbarLength, self.props.ToolbarHeight),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = self.props.ToolbarPosition,
		BackgroundTransparency = 1,

		[Roact.Children] = {
			MainToolbar = mainToolbar,
			CloseButton = e(CloseButton, {
				OnClick = self.props.OnCloseButtonClick,
				Size = UDim2.fromOffset(55,55),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(1, 25, 0.5, 0)
			}),
		}
	})

end

function Toolbar:ColoredStrokeMenu()

	local shadedColorSubMenu = e(ShadedColorSubMenu, {
		AnchorPoint = Vector2.new(0.5,0),
		Position = UDim2.new(0.5, 0, 0, 80),
		SelectedShadedColor = self.props.ColorWells[self.props.SelectedColorWellIndex],
		OnShadedColorSelect = function(shadedColor)
			self.props.UpdateColorWell(self.props.SelectedColorWellIndex, shadedColor)
		end,
	})

	local palette = function(layoutOrder)
		return e(Palette, {

			LayoutOrder = layoutOrder,

			Height = UDim.new(0, self.props.ButtonHeight),
			ButtonDim = UDim.new(0,self.props.ButtonHeight),

			ColorWells = self.props.ColorWells,
			SelectedColorWellIndex = self.props.SelectedColorWellIndex,

			OnColorWellClick = function(index)

				local subMenu = self.props.SubMenu

				if index == self.props.SelectedColorWellIndex then

					self.props.SetSubMenu(subMenu == "ShadedColor" and Roact.None or "ShadedColor")

				else

					if subMenu ~= nil and subMenu ~= "ShadedColor" then
						self.props.SetSubMenu(Roact.None)
					end

					self.props.SelectColorWell(index)
				end
			end,

			SubMenu = self.props.SubMenu == "ShadedColor" and shadedColorSubMenu or nil,

		})
	end

	local strokeWidthSubMenu = e(StrokeWidthSubMenu, {

		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),

		StrokeWidths = self.props.StrokeWidths,
		Color = self.props.ColorWells[self.props.SelectedColorWellIndex].Color,
		SelectedStrokeWidthName = self.props.SelectedStrokeWidthName,

		SelectStrokeWidth = self.props.SelectStrokeWidth,
		UpdateStrokeWidth = self.props.UpdateStrokeWidth,

		-- SliderState = self.props.StrokeWidthSliderState,
		-- SetSliderState = self.props.SetStrokeWidthSliderState,

	})

	local strokeButton = function(layoutOrder)
		return e(StrokeButton, {
			LayoutOrder = layoutOrder,

			Size = UDim2.fromOffset(self.props.ButtonHeight, self.props.ButtonHeight),
			Width = self.props.StrokeWidths[self.props.SelectedStrokeWidthName],

			Color = self.props.ColorWells[self.props.SelectedColorWellIndex].Color,

			OnClick = function()
				self.props.SetSubMenu(self.props.SubMenu == "StrokeWidth" and Roact.None or "StrokeWidth")
			end,

			SubMenu = self.props.SubMenu == "StrokeWidth" and strokeWidthSubMenu or nil,
		})
	end

	return function(layoutOrder)
		return e("Frame", {
			LayoutOrder = layoutOrder,

			Size = UDim2.fromOffset(self.props.StrokeMenuWidth, self.props.ButtonHeight),
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.fromScale(0.5,0.5),

			BackgroundTransparency = 1,

			[Roact.Children] = {

				UIListLayout = e("UIListLayout", {
					Padding = UDim.new(0,0),
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				LayoutFragment = e(LayoutFragment, {
					OrderedLayoutElements = {
						{"StrokeButton", strokeButton},
						{"Palette", palette}
					}
				}),
			}
		})
	end

end

return Toolbar