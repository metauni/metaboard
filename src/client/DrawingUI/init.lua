-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")


-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local App = require(script.App)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local function open(board, boardViewMode, onClose)

	local handle, dataUpdateConnection

	local function close()
		Roact.unmount(handle)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		dataUpdateConnection:Disconnect()
		onClose()
	end

	local makeApp = function()

		local localPlayerHistory = board.PlayerHistories[tostring(Players.LocalPlayer.UserId)]

		return e(App, {

			BoardViewMode = boardViewMode,

			Board = board,
			AspectRatio = board:SurfaceSize().X / board:SurfaceSize().Y,

			OnClose = function(toolState)
				close()
			end,

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			NextFigureZIndex = board.NextFigureZIndex,

			CanUndo = localPlayerHistory and localPlayerHistory:CountPast() > 0,
			CanRedo = localPlayerHistory and localPlayerHistory:CountFuture() > 0,

		})
	end

	handle = Roact.mount(makeApp(), Players.LocalPlayer.PlayerGui, "DrawingUI-"..board._instance.Name)

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

	dataUpdateConnection = board.DataChangedSignal:Connect(function()
		Roact.update(handle, makeApp())
	end)

	return close

end

return {
	Open = open
}
