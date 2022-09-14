-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local History = require(Common.History)
local DrawingTask = require(Common.DrawingTask)
local Figure = require(Common.Figure)
local EraseGrid = require(Common.EraseGrid)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Dictionary Operations
local set = Dictionary.set
local merge = Dictionary.merge

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

local events = {
	"InitDrawingTask",
	"UpdateDrawingTask",
	"FinishDrawingTask",
	"Undo",
	"Redo",
	"Clear",
	"SetData",
	"RequestBoardData",
}

-- The remote events needed for a board (parented to the board instance)
-- This should be created by the server and waited for by the clients
function BoardRemotes.new(instance : Model | Part)
	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	local self = setmetatable({}, BoardRemotes)

	for _, eventName in ipairs(events) do
		self[eventName] = createRemoteEvent(eventName, remotesFolder)
	end

	remotesFolder.Parent = instance
	return self
end

function BoardRemotes:Destroy()
	for _, eventName in ipairs(events) do
		self[eventName]:Destroy()
	end
end

return BoardRemotes