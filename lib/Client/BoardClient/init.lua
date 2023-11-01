-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local RunService = game:GetService("RunService")

local root = script.Parent.Parent
local BoardUtils = require(root.BoardUtils)
local Rx = require(root.Util.Rx)
local ValueObject = require(root.Util.ValueObject)
local BoardState = require(root.BoardState)
local BaseObject = require(root.Util.BaseObject)
-- local ValueObject = require(root.Util.ValueObject)
local GoodSignal = require(root.Util.GoodSignal)
local BoardRemotes = require(root.BoardRemotes)
local Sift = require(root.Parent.Sift)

--[[
	The client-side version of a board.
--]]
local BoardClient = setmetatable({}, BaseObject)
BoardClient.__index = BoardClient
BoardClient.ClassName = "BoardClient"

export type BoardClient = {
	-- These are all reactive ValueObjects
	Remotes: BoardRemotes.BoardRemotes,
	State: BoardState.BoardState,
	StateChanged: { Connect:(() -> ()) -> { Disconnect: () -> ()} },

	ClientState: { DrawingTasks: BoardState.DrawingTaskDict },
} & typeof(BoardClient)

function BoardClient.new(part: Part) : BoardClient
	local self = setmetatable(BaseObject.new(part), BoardClient)

	-- These may not replicate immediately
	self.Remotes = BoardRemotes.WaitForRemotes(part)

	self.State = nil
	self.ClientState = {
		DrawingTasks = {},
	}
	-- Fires at most once per-frame
	self.StateChanged = self._maid:Add(GoodSignal.new())

	self.SurfaceCFrame = self._maid:Add(ValueObject.fromObservable(BoardUtils.getSurfaceCFrameFromPart(part)))
	self.SurfaceSize = self._maid:Add(ValueObject.fromObservable(BoardUtils.getSurfaceSizeFromPart(part)))

	-- self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Size"):Connect(function()
	-- 	self.SurfaceSize.Value = BoardState.getSurfaceSizeFromPart(self._obj)
	-- end))
	
	-- self._maid:GiveTask(self._obj:GetPropertyChangedSignal("CFrame"):Connect(function()
	-- 	self.SurfaceCFrame.Value = BoardState.getSurfaceCFrameFromPart(self._obj)
	-- end))

	return self
end

function BoardClient:GetPart()
	return self._obj
end

function BoardClient:GetSurfaceCFrame()
	return self.SurfaceCFrame.Value
end

function BoardClient:GetSurfaceSize()
	return self.SurfaceSize.Value
end

--[[
	Connect remote event callbacks to respond to init/update/finish's of a drawing task,
	as well as undo, redo, clear events.
	The order these remote events are received is the globally agreed order.
	--]]
function BoardClient:ConnectRemotes()
	
	local tasks = {}
	-- This first cleans up the old list of connections if there was one
	-- then remembers these tasks in the maid
	self._maid._remoteTasks = tasks
	
	-- Remotes trip this flag so we can defer updates to the end of the frame
	local stateChangedThisFrame = false

	local function checkUpdate()
		if stateChangedThisFrame then
			self.StateChanged:Fire()
			-- Does ordering matter here? Is it possible that the state changes again?
			stateChangedThisFrame = false
		end
	end

	-- Check once per frame, and once on cleanup in case of race.
	table.insert(tasks, RunService.RenderStepped:Connect(checkUpdate))
	table.insert(tasks, checkUpdate)

	for _, actionName in {
		"InitDrawingTask",
		"UpdateDrawingTask",
		"FinishDrawingTask",
		"Undo",
		"Redo",
		"Clear",
	}
	do
		local remote = self.Remotes[actionName]
		table.insert(tasks, remote.OnClientEvent:Connect(function(...)
			BoardState[actionName](self.State, ...)
			if actionName == "FinishDrawingTask" then
				self:_trimClientState()
			end
			stateChangedThisFrame = true
		end))
	end
	
	table.insert(tasks, self.Remotes.SetData.OnClientEvent:Connect(function(data)
		self.State = BoardState.deserialise(data)
		self:_trimClientState()
		stateChangedThisFrame = true
	end))
end

function BoardClient:GetCombinedState(): BoardState.BoardState
	return BoardState.combineWithClientState(self.State, self.ClientState)
end

function BoardClient:ObserveCombinedState()
	self._combined = self._combined or Rx.fromSignal(self.StateChanged):Pipe {
		Rx.map(function()
			return self:GetCombinedState()
		end),
		Rx.share(),
	}

	return self._combined
end

function BoardClient:_trimClientState()
	self.ClientState.DrawingTasks = Sift.Dictionary.filter(self.ClientState.DrawingTasks, function(_, taskId)
		local verifiedDrawingTask = self.State.DrawingTasks[taskId]
		return not (verifiedDrawingTask and verifiedDrawingTask.Finished)
	end)
end

return BoardClient