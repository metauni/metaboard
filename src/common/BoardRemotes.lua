-- Services

-- Imports

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

function BoardRemotes.WaitForRemotes(instance)
	local remotesFolder = instance:WaitForChild("Remotes")

	local self = setmetatable({}, BoardRemotes)

	for _, eventName in ipairs(events) do
		self[eventName] = remotesFolder:WaitForChild(eventName)
	end

	return self
end

return BoardRemotes