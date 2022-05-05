-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary
local Figure = require(Common.Figure)

-- FigureComponents
local FigureComponent = {
	Curve = require(script.SectionedCurve),
	Line = require(script.Line),
	Circle = require(script.Circle),
}

local PureFigure = Roact.PureComponent:extend("PureFigure")

function PureFigure:render()
	local figure = self.props.Figure
	local container = self.props.Container

	local mask

	if figure.Type == "Curve" then
		mask = table.create(#figure.Points-1, false)

		for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
			for i=1, #figure.Points-1 do
				mask[i] = mask[i] or figureMask[i]
			end
		end
	end

	if figure.Type == "Curve" then

		return e(FigureComponent[figure.Type], Dictionary.merge(figure, {
			
			ZIndexOffset = self.props.ZIndexOffset,
			Container = container,
			Mask = mask,

		}))

	else

		return e("ScreenGui", {

			IgnoreGuiInset = true,
			DisplayOrder = figure.ZIndex + self.props.ZIndexOffset,

			[Roact.Children] = {

				Container = e(container, {}, {

					Figure = e(FigureComponent[figure.Type], Dictionary.merge(figure, {
						ZIndexOffset = self.props.ZIndexOffset,
						Mask = mask
					}))

				}),

			}

		})

	end


end

function PureFigure:shouldUpdate(nextProps, nextState)
	local shortcut =
	nextProps.Figure ~= self.props.Figure or
	nextProps.CanvasSize ~= self.props.CanvasSize or
	nextProps.CanvasCFrame ~= self.props.CanvasCFrame or
	nextProps.ZIndexOffset ~= self.props.ZIndexOffset
	
	if shortcut then
		return true
	else
		-- Check if any new figure masks are different or weren't there before
		for eraseTaskId, figureMask in pairs(nextProps.FigureMasks) do
			if figureMask ~= self.props.FigureMasks[eraseTaskId] then
				return true
			end
		end
		
		-- Check if any old figure masks and now different or gone
		for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
			if figureMask ~= nextProps.FigureMasks[eraseTaskId] then
				return true
			end
		end

		return false
	end
end

local FrameCanvas = Roact.PureComponent:extend("FrameCanvas")

function FrameCanvas:render()

	local positionBinding = self.props.AbsolutePositionBinding:map(function(absolutePosition)
		return UDim2.fromOffset(absolutePosition.X, absolutePosition.Y + 36)
	end)

	local sizeBinding = self.props.AbsoluteSizeBinding:map(function(absoluteSize)
		return UDim2.fromOffset(absoluteSize.X, absoluteSize.Y)
	end)

	local container = function(props)
		local canvasSquare = e("Frame", {
			BackgroundTransparency = 1,

			Position = UDim2.fromScale(0,0),
			Size = UDim2.fromScale(1,1),
			SizeConstraint =  Enum.SizeConstraint.RelativeYY,

			[Roact.Children] = props[Roact.Children]
		})

		return e("Frame", {
			BackgroundTransparency = 1,

			Position = positionBinding,
			Size = sizeBinding,

			[Roact.Children] = {
				CanvasSquare = canvasSquare
			}
		})
	end

	local flippedFigureMasks = {}

	for eraseTaskId, figureMasks in pairs(self.props.BundledFigureMasks) do
		for taskId, figureMask in pairs(figureMasks) do
			flippedFigureMasks[taskId] = flippedFigureMasks[taskId] or {}
			flippedFigureMasks[taskId][eraseTaskId] = figureMask
		end
	end

	local pureFigures = {}

	for taskId, figure in pairs(self.props.Figures) do

		pureFigures[taskId] = e(PureFigure, {

			Figure = figure,

			FigureMasks = flippedFigureMasks[taskId] or {},

			Container = container,

			ZIndexOffset = self.props.ZIndex,

		})

	end

	return e("Folder", {}, pureFigures)
end

return FrameCanvas