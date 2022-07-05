-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local SurfaceCanvas = require(script.Parent.SurfaceCanvas)
local extractHostObject = require(script.Parent.extractHostObject)
local dormantBoardUpdater = require(script.Parent.dormantBoardUpdater)

return function(board, viewData, canvasTarget, getLineBudget)
	viewData = viewData or {}

	if viewData.Status == "Dormant" then
		viewData.DoUpdate()
		return viewData
	else
		if viewData.Destroy then
			viewData.Destroy()
		end
	end

	local canvas = viewData.Canvas

	if not canvas then
		local makeElement = function()
			return e(SurfaceCanvas, {

				Figures = board.Figures,
				DrawingTasks = board.DrawingTasks,
				CanvasSize = board:SurfaceSize(),
				CanvasCFrame = board:SurfaceCFrame(),
				GetLineBudget = getLineBudget,
			})
		end

		local tree = Roact.mount(makeElement(), canvasTarget, board._instance.Name)

		canvas = extractHostObject(tree)
	end

	local figuresNow = board.Figures
	local drawingTasksNow = board.DrawingTasks

	local dormantViewData
	dormantViewData = {
		Status = "Dormant",
		Canvas = canvas,
		Figures = figuresNow,
		DrawingTasks = drawingTasksNow,
		DoUpdate = function()
			if board.Figures ~= dormantViewData.Figures or board.DrawingTasks ~= dormantViewData.DrawingTasks then
				dormantBoardUpdater(board, dormantViewData)
			end
		end,
		Destroy = function()
			canvas:Destroy()
		end,
	}

	return dormantViewData
end
