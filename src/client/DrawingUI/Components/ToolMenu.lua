-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Config = require(Common.Config)
local Assets = require(Common.Assets)

local Components = script.Parent
local LayoutFragment = require(Components.LayoutFragment)
local PenButton = require(Components.ToolButtons.PenButton)
local StraightEdgeButton = require(Components.ToolButtons.StraightEdgeButton)
local EraserButton = require(Components.ToolButtons.EraserButton)

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
	local equippedToolName = self.props.EquippedToolName
	local equipTool = self.props.EquipTool
	local buttonSize = self.props.ButtonSize
	local size = self.props.Size


	local penButton = function(props)
		return e(PenButton, {
			Size = buttonSize,
			LayoutOrder = props.LayoutOrder,
			Selected = equippedToolName == "Pen",
			OnClick = function()
				equipTool("Pen")
			end
		})
	end

	local straightEdgeButton = function(props)
		return e(StraightEdgeButton, {
			Size = buttonSize,
			LayoutOrder = props.LayoutOrder,
			Selected = equippedToolName == "StraightEdge",
			OnClick = function()
				equipTool("StraightEdge")
			end
		})
	end

	local eraserButton = function(props)
		return e(EraserButton,{
			Size = buttonSize,
			LayoutOrder = props.LayoutOrder,
			Selected = equippedToolName == "Eraser",
			OnClick = function()
				equipTool("Eraser")
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
				NamedComponents = {
					{"Pen", penButton},
					{"StraightEdge", straightEdgeButton},
					{"Eraser", eraserButton},
				}
			})
		}
	})


end

return ToolMenu