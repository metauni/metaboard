-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

return function(props)

	local eraseGrid = props.Board.EraseGrid
	local aspectRatio = props.Board:AspectRatio()
	local gridWidth =  math.ceil(props.Board:AspectRatio() / Config.DefaultEraseGridPixelSize)
	local gridHeight =  math.ceil(1 / Config.DefaultEraseGridPixelSize)

	local squares = {}
	for x=0, gridWidth-1 do
		for y=0, gridHeight-1 do
			local count = Dictionary.count(eraseGrid.ShapeGrid.PixelsToShapeIds.Get(x,y) or {})
			squares[("%d,%d"):format(x,y)] = e("TextLabel", {

				Text = tostring(count),

				TextColor3 = Color3.new(1,1,1),

				Size = UDim2.fromScale(Config.DefaultEraseGridPixelSize, Config.DefaultEraseGridPixelSize),
				Position = UDim2.fromScale(x/gridHeight, y/gridHeight),

				BackgroundTransparency = 1,

			}, { UIStroke = e("UIStroke", { ApplyStrokeMode =  Enum.ApplyStrokeMode.Border, Thickness = 1, Color = Color3.new(1,1,1)})})
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


		[Roact.Children] = squares


	})
end