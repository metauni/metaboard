-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")

-- Import
local Config = require(Common.Config)
local Board = require(Common.Board)
local Signal = require(Common.Packages.GoodSignal)

--[[
	The server-side version of a board
--]]
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part, boardRemotes, persistId: number?, loaded: boolean)
	local self = setmetatable(Board.new(instance, boardRemotes, persistId, loaded), BoardServer)

	self.Watchers = {}

	self._destructor:Add(Players.PlayerRemoving:Connect(function(player)
		self.Watchers[player] = nil
	end))

	--[[
		Signal that fires when the board has been populated.
		Check self.Loaded before connecting to this signal.
	--]]
	self.LoadedSignal = Signal.new()
	self._destructor:Add(function()
		self.LoadedSignal:DisconnectAll()
	end)

	return self
end


return BoardServer