-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")

-- Imports
local root = script.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement
local App = require(script.App)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

--[[
	Set up and show the drawing UI for the given board
--]]
return function(board, boardViewMode, onClose)

	local handle, dataUpdateConnection

	local function destroy()
		Roact.unmount(handle)
		dataUpdateConnection:Disconnect()
		onClose()
	end

	local makeApp = function()

		local localPlayerHistory = board.State.PlayerHistories[tostring(Players.LocalPlayer.UserId)]

		return e(App, {

			BoardViewMode = boardViewMode,

			Board = board,
			AspectRatio = board.State.AspectRatio,

			OnClose = function()
				destroy()
			end,

			Figures = board.State.Figures,
			DrawingTasks = board.State.DrawingTasks,
			NextFigureZIndex = board.State.NextFigureZIndex,

			CanUndo = localPlayerHistory and localPlayerHistory:CountPast() > 0,
			CanRedo = localPlayerHistory and localPlayerHistory:CountFuture() > 0,

		})
	end

	handle = Roact.mount(makeApp(), Players.LocalPlayer.PlayerGui, "DrawingUI-"..board:GetPart():GetFullName())

	dataUpdateConnection = board.StateChanged:Connect(function()
		Roact.update(handle, makeApp())
	end)

	return destroy
end
