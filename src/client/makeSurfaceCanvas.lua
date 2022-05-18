-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local PartCanvas = require(script.Parent.PartCanvas)

local SurfaceCanvas = Roact.PureComponent:extend("SurfaceCanvas")

function SurfaceCanvas:render()

	local figureMaskBundles = {}
	local allFigures = table.clone(self.props.Figures)

	for taskId, drawingTask in pairs(self.props.DrawingTasks) do

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

	return e("Model", {}, {

		Figures = e(PartCanvas, {

			Figures = allFigures,
			FigureMaskBundles = figureMaskBundles,

			CanvasSize = self.props.CanvasSize,
			CanvasCFrame = self.props.CanvasCFrame,

			AsFragment = true,

		})

	})

end

return function (board, target)

	local handle, dataUpdateConnection

	local makeSurfaceCanvas = function()

		return e(SurfaceCanvas, {

			CanvasSize = board:SurfaceSize(),
			CanvasCFrame = board:SurfaceCFrame(),

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,

		})
	end

	dataUpdateConnection = board.DataChangedSignal:Connect(function()
		Roact.update(handle, makeSurfaceCanvas())
	end)

	handle = Roact.mount(makeSurfaceCanvas(), target, board._instance.Name.."Canvas")

	return function()
		Roact.unmount(handle)
		dataUpdateConnection:Disconnect()
	end

end