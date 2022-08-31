-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local SurfaceCanvas = require(script.Parent.SurfaceCanvas)
local extractHostObject = require(script.Parent.extractHostObject)
local dormantBoardUpdater = require(script.Parent.dormantBoardUpdater)

return function(self, board, viewData)
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
				GetLineBudget = function()
					return self.GetLineBudget()
				end,
			})
		end

		local tree = Roact.mount(makeElement(), self.CanvasesFolder, board:FullName())

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
