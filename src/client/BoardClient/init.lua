-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Import
local Config = require(Common.Config)
local Board = require(Common.Board)

--[[
	The client-side version of a board.
--]]
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes, persistId: number?, loaded: boolean)
	return setmetatable(Board.new(instance, boardRemotes, persistId, loaded), BoardClient)
end

function BoardClient:SetToolState(toolState)
	self._toolState = toolState
end

function BoardClient:GetToolState()
	return self._toolState
end

return BoardClient