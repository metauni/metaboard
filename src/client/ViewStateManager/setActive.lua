-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local SurfaceCanvas = require(script.Parent.SurfaceCanvas)
local extractHostObject = require(script.Parent.extractHostObject)

return function(board, viewData, canvasTarget, getLineBudget)
	local oldViewData = viewData or {}
	local newViewData

	local makeElement = function()

		return e(SurfaceCanvas, {

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			CanvasSize = board:SurfaceSize(),
			CanvasCFrame = board:SurfaceCFrame(),
			GetLineBudget = getLineBudget,
			LineLoadFinishedCallback = function()
				newViewData.OnLoadedCallback()
			end,
			Board = board,
		})
	end

	if oldViewData.Status ~= "Active" then

		local tree = Roact.mount(makeElement(), canvasTarget, board._instance.Name)

		local updateConnection = board.DataChangedSignal:Connect(function()
			if not newViewData.Paused then
				Roact.update(tree, makeElement())
			end
		end)

		newViewData = {
			Status = "Active",
			Tree = tree,
			Canvas = extractHostObject(tree),
			OnLoadedCallback = function()
				if oldViewData and oldViewData.Destroy then
					oldViewData.Destroy()
					oldViewData.Destroy = nil
				end
			end,
			Destroy = function()
				updateConnection:Disconnect()
				Roact.unmount(tree)
			end,
		}

		return newViewData
	end

	return viewData
end