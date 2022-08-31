-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Config = require(Common.Config)
local Assets = require(Common.Assets)

-- Drawing Tools
local DrawingTools = script.Parent.Parent.Parent.DrawingTools
local Pen = require(DrawingTools.Pen)
local StraightEdge = require(DrawingTools.StraightEdge)
local Eraser = require(DrawingTools.Eraser)

-- Components
local Components = script.Parent.Parent
local LayoutFragment = require(Components.LayoutFragment)
local PenButton = require(Components.Toolbar.ToolButtons.PenButton)
local StraightEdgeButton = require(Components.Toolbar.ToolButtons.StraightEdgeButton)
local EraserButton = require(Components.Toolbar.ToolButtons.EraserButton)

local ToolMenu = Roact.PureComponent:extend("ToolMenu")
ToolMenu.defaultProps = {
	Height = UDim.new(0,40),
	Position = UDim2.fromScale(0.5,0.5),
	Size = UDim2.fromScale(1,1),
	ButtonSize = UDim2.fromOffset(80,80),
}


function ToolMenu:render()
	local padding = self.props.Padding
	local position = self.props.Position
	local height = self.props.Height
	local layoutOrder = self.props.LayoutOrder
	local equippedTool = self.props.EquippedTool
	local equipTool = self.props.EquipTool
	local buttonSize = self.props.ButtonSize
	local size = self.props.Size


	local penButton = function(innerLayoutOrder)
		return e(PenButton, {
			Size = buttonSize,
			LayoutOrder = innerLayoutOrder,
			Selected = equippedTool == Pen,
			OnClick = function()
				equipTool(Pen)
			end
		})
	end

	local straightEdgeButton = function(innerLayoutOrder)
		return e(StraightEdgeButton, {
			Size = buttonSize,
			LayoutOrder = innerLayoutOrder,
			Selected = equippedTool == StraightEdge,
			OnClick = function()
				equipTool(StraightEdge)
			end
		})
	end

	local eraserButton = function(innerLayoutOrder)
		return e(EraserButton,{
			Size = buttonSize,
			LayoutOrder = innerLayoutOrder,
			Selected = equippedTool == Eraser,
			OnClick = function()
				equipTool(Eraser)
			end
		})
	end

	return e("Frame", {
		Size = size,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = position,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,


		[Roact.Children] = {
			UIListLayout = e("UIListLayout", {
				Padding = padding,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Tools = e(LayoutFragment, {
				OrderedLayoutElements = {
					{"Pen", penButton},
					{"StraightEdge", straightEdgeButton},
					{"Eraser", eraserButton},
				}
			})
		}
	})


end

return ToolMenu