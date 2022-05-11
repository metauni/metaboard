-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.Parent.Parent.BoardClient)
local BoardRemotes = require(Common.BoardRemotes)


return function(target)
	local Roact: Roact = require(Common.Packages.Roact)

	Roact.setGlobalConfig({
		elementTracing = true
	})

	local App = require(script.Parent.App)

	local boardInstance = Common.BoardModels.BlackBoardMini:Clone()

	local board = BoardClient.new(boardInstance, BoardRemotes.new(boardInstance))

	local handle
	handle = Roact.mount(Roact.createElement(App, {
		Board = board,
		AspectRatio = board:SurfaceSize().X / board:SurfaceSize().Y,
		
		OnClose = function()
			Roact.unmount(handle)
			boardInstance:Destroy()
		end,

		Figures = board.Figures,
		DrawingTasks = board.DrawingTasks,
		CanUndo = false,
		CanRedo = false,
		SilenceRemoteEventFire = true,
 	}), target)

	return function()
		Roact.unmount(handle)
		boardInstance:Destroy()
	end
end