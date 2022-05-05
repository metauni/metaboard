-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")


-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local App = require(script.App)

local function open(board, onClose)
	local handle
	handle = Roact.mount(Roact.createElement(App, {
		Board = board,
		AspectRatio = board:SurfaceSize().X / board:SurfaceSize().Y,
		OnClose = function()
			Roact.unmount(handle)
			onClose()
		end
	}), Players.LocalPlayer.PlayerGui, "DrawingUI")
end

return {
	Open = open
}
