-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement
local Config = require(root.Config)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

--[[
	Shows a visualisation of the erase grid with numbers in each cell that
	indicate the number of subfigures (e.g. lines) in that cell.

	WARNING: This is very slow. Performance will be worsened when this is shown.
--]]
return function(props)

	local eraseGrid = props.Board.EraseGrid
	local gridWidth =  math.ceil(props.Board:AspectRatio() / Config.Canvas.DefaultEraseGridPixelSize)
	local gridHeight =  math.ceil(1 / Config.Canvas.DefaultEraseGridPixelSize)

	local cells = {}
	for x=0, gridWidth-1 do
		for y=0, gridHeight-1 do
			local count = Dictionary.count(eraseGrid.ShapeGrid.PixelsToShapeIds.Get(x,y) or {})
			cells[("%d,%d"):format(x,y)] = e("TextLabel", {

				Text = tostring(count),

				TextColor3 = Color3.new(1,1,1),

				Size = UDim2.fromScale(Config.Canvas.DefaultEraseGridPixelSize, Config.Canvas.DefaultEraseGridPixelSize),
				Position = UDim2.fromScale(x/gridHeight, y/gridHeight),

				BackgroundTransparency = 1,

				[Roact.Children] = {

					UIStroke = e("UIStroke", {
						ApplyStrokeMode =  Enum.ApplyStrokeMode.Border,
						Thickness = 1,
						Color = Color3.new(1,1,1)
					})

				}

			})
		end
	end

	return e("Frame", {

		Size = UDim2.fromOffset(props.CanvasAbsoluteSize.Y, props.CanvasAbsoluteSize.Y),

		Position = UDim2.fromOffset(props.CanvasAbsolutePosition.X, props.CanvasAbsolutePosition.Y + 36),

		BackgroundTransparency = 1,

		[Roact.Children] = cells

	})
end