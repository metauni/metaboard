-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

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