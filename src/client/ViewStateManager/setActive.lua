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
	local newViewData = {}

	local makeElement = function()

		return e(SurfaceCanvas, {

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			CanvasSize = board:SurfaceSize(),
			CanvasCFrame = board:SurfaceCFrame(),
			GetLineBudget = getLineBudget,
			LineLoadFinishedCallback = function()
				if oldViewData and oldViewData.Destroy then
					oldViewData.Destroy()
					oldViewData = nil
				end
			end,
			Board = board,
		})
	end

	if oldViewData.Status ~= "Active" then

		newViewData.Tree = Roact.mount(makeElement(), canvasTarget, board._instance.Name)

		local updateConnection = board.DataChangedSignal:Connect(function()
			if not newViewData.Paused then
				Roact.update(newViewData.Tree, makeElement())
			end
		end)

		newViewData = {
			Status = "Active",
			Tree = newViewData.Tree,
			Canvas = extractHostObject(newViewData.Tree),
			Destroy = function()
				updateConnection:Disconnect()
				Roact.unmount(newViewData.Tree)
				newViewData.Status = nil
				newViewData.Tree = nil
				newViewData.Canvas = nil
				newViewData.Destroy = nil
			end,
		}

		return newViewData
	end

	return viewData
end