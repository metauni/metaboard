-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local ColorButton = require(script.Parent.ColorButton)
local Config = require(Common.Config)

local ShadedColorSubMenu = Roact.PureComponent:extend("ShadedColorSubMenu")
ShadedColorSubMenu.defaultProps = {
	ColorPalette = Config.ColorPalette,
	AnchorPoint = Vector2.new(0.5,0.5),
	Position = UDim2.fromScale(0.5,0.5),
}

function ShadedColorSubMenu:render()
	local colorPalette = self.props.ColorPalette
	local selectedShadedColor = self.props.SelectedShadedColor
	local onShadedColorSelect = self.props.OnShadedColorSelect
	local anchorPoint = self.props.AnchorPoint
	local position = self.props.Position

	local baseColorButtons = {}
	local shadeGrid
	do
		for baseName, colorShadeTable in pairs(colorPalette) do
			local selected = selectedShadedColor.BaseName == baseName

			baseColorButtons[baseName] = e(ColorButton, {
				Color = colorShadeTable.BaseColor,
				LayoutOrder = colorShadeTable.Index,
				Selected = selected,
				OnClick = function()
					onShadedColorSelect({
						BaseName = baseName,
						Color = colorShadeTable.BaseColor,
					})
				end
			})

			local shadeButtons = {}
			if baseName == selectedShadedColor.BaseName then
				for j, shade in ipairs(colorShadeTable.Shades) do
					shadeButtons[tostring(j)] = e(ColorButton, {
						Size = UDim2.fromOffset(50,50),
						Color = shade,
						LayoutOrder = j,
						Selected = selectedShadedColor.Color == shade,
						OnClick = function()
							onShadedColorSelect({
								BaseName = baseName,
								Color = shade,
							})
						end
					})
				end

				shadeGrid = e("Frame", {
					Size = UDim2.fromOffset(270, 70),
					AnchorPoint = Vector2.new(0.5,0.5),
					BackgroundColor3 = Config.UITheme.Background,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.5,0.5)
				},
				{
					UIListLayout = e("UIListLayout", {
						Padding = UDim.new(0,0),
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Buttons = Roact.createFragment(shadeButtons)
				})
			end

		end
	end

	local baseColorsGrid = e("Frame", {
		Size = UDim2.fromOffset(270, 120),
		AnchorPoint = Vector2.new(0.5,0.5),
		BackgroundColor3 = Config.UITheme.Background,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Position = UDim2.fromScale(0.5,0.5)
	},
	{
		UIGridLayout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(50,50),
			CellPadding = UDim2.fromOffset(0,0),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 5,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		buttons = Roact.createFragment(baseColorButtons)
	})

	return e("Frame", {
		Size = UDim2.fromOffset(270, 200),
		AnchorPoint = anchorPoint,
		Position = position,
		BackgroundColor3 = Config.UITheme.Background,
		BorderSizePixel = 0,
	},
	{
		UIListLayout = e("UIListLayout", {
			Padding = UDim.new(0,0),
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UICorner = e("UICorner", {CornerRadius = UDim.new(0, 10)}),
		ShadeGrid = shadeGrid,
		Divider = e("Frame", {
			Size = UDim2.fromOffset(230, 3),
			BackgroundColor3 = Config.UITheme.Stroke,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}),
		BaseColorsGrid = baseColorsGrid
	})



end

return ShadedColorSubMenu