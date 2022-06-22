-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Figure = require(Common.Figure)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Helper Functions
local PartCanvasScript = script.Parent.Parent.PartCanvas

local _LineComponent = require(PartCanvasScript.Line)

-- FigureComponents
local FigureComponent = {
	Curve = require(PartCanvasScript.SectionedCurve),
	Line = (function()

		return function(props)
			return e(_LineComponent, Dictionary.merge(props, {

				RoundedP0 = true,
				RoundedP1 = true,

			}))
		end

	end)(),
	Circle = require(PartCanvasScript.Circle),
}

local function partCanvasFigure(props)
	local figure = props.Figure

	local cummulativeMask = Figure.MergeMask(figure.Type, figure.Mask)

	for eraseTaskId, figureMask in pairs(props.FigureMasks or {}) do
		cummulativeMask = Figure.MergeMask(figure.Type, cummulativeMask, figureMask)
	end

	return e(FigureComponent[props.Figure.Type],

		Dictionary.merge(props.Figure, {
			CanvasSize = props.CanvasSize,
			CanvasCFrame = props.CanvasCFrame,

			Mask = cummulativeMask,
		})

	)
end

return function(canvas, board, oldFigures, oldDrawingTasks)

	local oldFigureMaskBundles = {}
	local oldAllFigures = table.clone(oldFigures)

	for taskId, drawingTask in pairs(oldDrawingTasks) do

		if drawingTask.Type == "Erase" then

			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			for figureId, figureMask in pairs(figureIdToFigureMask) do
				local bundle = oldFigureMaskBundles[figureId] or {}
				bundle[taskId] = figureMask
				oldFigureMaskBundles[figureId] = bundle
			end

		else

			oldAllFigures[taskId] = DrawingTask.Render(drawingTask)

		end

	end

	local figureMaskBundles = {}
	local allFigures = table.clone(board.Figures)

	for taskId, drawingTask in pairs(board.DrawingTasks) do

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

	local removed = {}
	local modified = {}

	-- Check for old table figures that are gone now
	for figureId, figure in pairs(oldAllFigures) do
		if allFigures[figureId] == nil then
			removed[figureId] = figure
		end
	end

	-- Check new table figures that are different or new
	for figureId, figure in pairs(allFigures) do
		local masks = figureMaskBundles[figureId]
		local oldMasks = oldFigureMaskBundles[figureId]

		if figure ~= oldAllFigures[figureId] or not Dictionary.equals(masks, oldMasks) then
			modified[figureId] = {
				Figure = figure,
				FigureMasks = masks,
				CanvasSize = board:SurfaceSize(),
				CanvasCFrame = board:SurfaceCFrame(),
			}
		end
	end

	-- Remove all removed figures
	for figureId in pairs(removed) do
		local figureInstance = canvas:FindFirstChild(figureId)
		if figureInstance == nil then
			print(("Tried removing figureInstance %s that wasn't there"):format(figureId))
		else
			figureInstance:Destroy()
		end
	end

	-- Replace all modifed figures
	for figureId, figureAndMasks in pairs(modified) do
		local oldFigureInstance = canvas:FindFirstChild(figureId)

		if oldFigureInstance ~= nil then
			oldFigureInstance:Destroy()
		end

		Roact.mount(e(partCanvasFigure, figureAndMasks), canvas, figureId)
	end

end