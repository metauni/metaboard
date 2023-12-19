-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- BoardRemotes Module
local BoardRemotes = {}
BoardRemotes.__index = BoardRemotes

local function createRemoteEvent(name : string, parent : Instance)
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = parent
	return remoteEvent
end

local function createRemoteFunction(name : string, parent : Instance)
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = parent
	return remoteFunction
end

local remoteEventNames = {
	"InitDrawingTask",
	"UpdateDrawingTask",
	"FinishDrawingTask",
	"Undo",
	"Redo",
	"Clear",
	"SetData",
}

local remoteFunctionNames = {
	"GetBoardData",
}

export type BoardRemotes = {
	InitDrawingTask: RemoteEvent,
	UpdateDrawingTask: RemoteEvent,
	FinishDrawingTask: RemoteEvent,
	Undo: RemoteEvent,
	Redo: RemoteEvent,
	Clear: RemoteEvent,
	SetData: RemoteEvent,

	GetBoardData: RemoteFunction,
} & typeof(BoardRemotes)

-- The remote events needed for a board (parented to the board instance)
-- This should be created by the server and waited for by the clients
function BoardRemotes.new(instance : Part): BoardRemotes
	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "metaboardRemotes"
	local self = setmetatable({}, BoardRemotes)

	for _, eventName in ipairs(remoteEventNames) do
		self[eventName] = createRemoteEvent(eventName, remotesFolder)
	end

	for _, functionName in ipairs(remoteFunctionNames) do
		self[functionName] = createRemoteFunction(functionName, remotesFolder)
	end

	remotesFolder.Parent = instance
	self._remotesFolder = remotesFolder
	return self
end

function BoardRemotes.WaitForRemotes(instance: Part): BoardRemotes

	local remotesFolder = instance:WaitForChild("metaboardRemotes")

	local self = setmetatable({}, BoardRemotes)

	for _, eventName in ipairs(remoteEventNames) do
		self[eventName] = remotesFolder:WaitForChild(eventName)
	end

	for _, functionName in ipairs(remoteFunctionNames) do
		self[functionName] = remotesFolder:WaitForChild(functionName)
	end

	return self
end

function BoardRemotes:Destroy()
	
	for _, eventName in ipairs(remoteEventNames) do
		self[eventName]:Destroy()
	end

	for _, functionName in ipairs(remoteFunctionNames) do
		self[functionName]:Destroy()
	end

	self._remotesFolder:Destroy()
end

return BoardRemotes