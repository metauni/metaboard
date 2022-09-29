-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Import
local Board = require(Common.Board)
local BoardRemotes = require(Common.BoardRemotes)

--[[
	The client-side version of a board.
--]]
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part)

	-- These may not replicate immediately
	local surfaceCFrameValue = instance:WaitForChild("SurfaceCFrameValue")
	local surfaceSizeValue = instance:WaitForChild("SurfaceSizeValue")
	local boardRemotes = BoardRemotes.WaitForRemotes(instance)

	return setmetatable(Board.new({
	
		Instance = instance,
		BoardRemotes = boardRemotes,
		SurfaceCFrame = surfaceCFrameValue.Value,
		SurfaceSize = surfaceSizeValue.Value
	}), BoardClient)
end

function BoardClient:SetToolState(toolState)
	self._toolState = toolState
end

function BoardClient:GetToolState()
	return self._toolState
end

function BoardClient:ConnectRemotes()

	local connections = {}

	--[[
		Connect remote event callbacks to respond to init/update/finish's of a drawing task,
		as well as undo, redo, clear events.
		The order these remote events are received is the globally agreed order.
	--]]

	-- Turn a method into a function with self as first argument
	local function fix(method)

		return function (...)
		
			method(self, ...)
		end
	end

	table.insert(connections, self.Remotes.InitDrawingTask.OnClientEvent:Connect(fix(self.ProcessInitDrawingTask)))
	table.insert(connections, self.Remotes.UpdateDrawingTask.OnClientEvent:Connect(fix(self.ProcessUpdateDrawingTask)))
	table.insert(connections, self.Remotes.FinishDrawingTask.OnClientEvent:Connect(fix(self.ProcessFinishDrawingTask)))
	table.insert(connections, self.Remotes.Undo.OnClientEvent:Connect(fix(self.ProcessUndo)))
	table.insert(connections, self.Remotes.Redo.OnClientEvent:Connect(fix(self.ProcessRedo)))
	table.insert(connections, self.Remotes.Clear.OnClientEvent:Connect(fix(self.ProcessClear)))

	table.insert(connections, self.Remotes.SetData.OnClientEvent:Connect(function(data)

		self:LoadData(data)
		self:DataChanged()
	end))

	self._destructor:Add(function()
		
		for _, connection in ipairs(connections) do
			connection:Destroy()
		end
	end)
end

return BoardClient