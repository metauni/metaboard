-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local RunService = game:GetService("RunService")

local root = script.Parent.Parent
local DrawingTask = require(script.Parent.Parent.DrawingTask)
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

	self.SurfaceCFrame = self._maid:Add(ValueObject.fromObservable(BoardUtils.observeSurfaceCFrame(part)))
	self.SurfaceSize = self._maid:Add(ValueObject.fromObservable(BoardUtils.observeSurfaceSize(part)))

	return self
end

function BoardClient:GetPart()
	return self._obj
end

function BoardClient:GetSurfaceCFrame(): CFrame
	return self.SurfaceCFrame.Value
end

function BoardClient:GetSurfaceSize(): Vector2
	return self.SurfaceSize.Value
end

function BoardClient:GetAspectRatio(): number
	local surfaceSize = self.SurfaceSize.Value
	return surfaceSize.X / surfaceSize.Y
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

function BoardClient:HandleLocalDrawingTaskEvent(event: string, taskId: string, ...)
	if event == "InitDrawingTask" then
		local drawingTask, canvasPos = select(1, ...)
		assert(drawingTask.Id == taskId, "Bad taskId match")

		local initialisedDrawingTask = DrawingTask.Init(drawingTask, self.State, canvasPos)
		self.ClientState.DrawingTasks[taskId] = initialisedDrawingTask

		self.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)
	elseif event == "UpdateDrawingTask" then
		local canvasPos = select(1, ...)
		local drawingTask = self.ClientState.DrawingTasks[taskId]
		if not drawingTask then
			error(`No drawingTask with taskId {taskId}`)
		end

		local updatedDrawingTask = DrawingTask.Update(drawingTask, self.State, canvasPos)
		self.ClientState.DrawingTasks[taskId] = updatedDrawingTask
		self.Remotes.UpdateDrawingTask:FireServer(canvasPos)
	elseif event == "FinishDrawingTask" then
		local drawingTask = self.ClientState.DrawingTasks[taskId]
		if not drawingTask then
			error(`No drawingTask with taskId {taskId}`)
		end

		local finishedDrawingTask = Sift.Dictionary.set(DrawingTask.Finish(drawingTask, self.State), "Finished", true)
		self.ClientState.DrawingTasks[taskId] = finishedDrawingTask
		
		self.Remotes.FinishDrawingTask:FireServer()
	else
		error(`Event {event} not recognised`)
	end

	self.StateChanged:Fire()
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