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

local function open(board, onClose)

	local handle, dataUpdateConnection

	local function close()
		Roact.unmount(handle)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		dataUpdateConnection:Disconnect()
		onClose()
	end

	local makeApp = function()

		local localPlayerHistory = board.PlayerHistories[Players.LocalPlayer]

		return e(App, {

			Board = board,
			AspectRatio = board:SurfaceSize().X / board:SurfaceSize().Y,
			
			OnClose = function()
				close()
			end,

			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			CanUndo = localPlayerHistory and localPlayerHistory:CountPast() > 0,
			CanRedo = localPlayerHistory and localPlayerHistory:CountFuture() > 0,

		})
	end

	handle = Roact.mount(makeApp(), Players.LocalPlayer.PlayerGui, "DrawingUI-"..board._instance.Name)
	
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

	dataUpdateConnection = board.BoardDataChangedSignal:Connect(function()
		Roact.update(handle, makeApp())
	end)

	return close

end

return {
	Open = open
}
