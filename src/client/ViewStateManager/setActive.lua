-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local DrawingUI = require(script.Parent.Parent.DrawingUI)

local SurfaceCanvas = require(script.Parent.SurfaceCanvas)
local extractHostObject = require(script.Parent.extractHostObject)

return function(self, board, viewData)
	local oldViewData = viewData or {}

	local makeElement = function(whenLoaded)

		return e(SurfaceCanvas, {

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			CanvasSize = board:SurfaceSize(),
			CanvasCFrame = board:SurfaceCFrame(),
			GetLineBudget = function()
				return self.GetLineBudget()
			end,
			LineLoadFinishedCallback = whenLoaded,
			Board = board,

			--[[
				Make the surface clickable only if no other board is open.
			--]]
			OnSurfaceClick = self.OpenedBoard == nil and function()
				DrawingUI(board, "Gui", function()
					-- This function is called when the Drawing UI is closed
					self.OpenedBoard = nil
					self:RefreshViewStates()
				end)
				self.OpenedBoard = board
				self:RefreshViewStates()
			end or nil,
		})
	end

	if oldViewData.Status == "Active" then
		Roact.update(oldViewData.Tree, makeElement(oldViewData.WhenLoaded))
	else

		local newViewData = {}

		newViewData.WhenLoaded = function()
			if oldViewData.Destroy then
				oldViewData.Destroy()
			end
			newViewData.WhenLoaded = nil
		end

		newViewData.Tree = Roact.mount(makeElement(newViewData.WhenLoaded), self.CanvasesFolder, board:FullName())

		local updateConnection = board.DataChangedSignal:Connect(function()
			if not newViewData.Paused then
				Roact.update(newViewData.Tree, makeElement())
			end
		end)

		newViewData.Status = "Active"
		newViewData.Canvas = extractHostObject(newViewData.Tree)
		newViewData.Destroy = function()
			updateConnection:Disconnect()
			Roact.unmount(newViewData.Tree)
			newViewData.Status = nil
			newViewData.Tree = nil
			newViewData.Canvas = nil
			newViewData.Destroy = nil
		end

		return newViewData
	end

	return viewData
end