-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")

-- Import
local Config = require(Common.Config)
local Board = require(Common.Board)

-- Helper functions
local connectDrawingTaskEvents = require(Common.connectDrawingTaskEvents)

-- BoardServer
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part, boardRemotes, persistId: string?, status: string)
	-- A server board has no canvas, so we pass nil
	local self = setmetatable(Board.new(instance, boardRemotes, persistId, status), BoardServer)

	self.Watchers = {}

	self._destructor:Add(Players.PlayerRemoving:Connect(function(player)
		self.Watchers[player] = nil
	end))

	connectDrawingTaskEvents(self, self._destructor)

	return self
end


return BoardServer