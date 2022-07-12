-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
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

		Size = props.AbsoluteSizeBinding:map(function(absoluteSize)
			return UDim2.fromOffset(absoluteSize.Y, absoluteSize.Y)
		end),

		Position = props.AbsolutePositionBinding:map(function(absolutePosition)
			return UDim2.fromOffset(absolutePosition.X, absolutePosition.Y + 36)
		end),

		BackgroundTransparency = 1,

		[Roact.Children] = cells

	})
end