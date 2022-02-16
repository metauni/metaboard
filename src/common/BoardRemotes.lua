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

-- The remote events needed for a board (parented to the board instance)
-- This should be created by the server and waited for by the clients
function BoardRemotes.new(instance : Model | Part)
  local remotesFolder = Instance.new("Folder")
  remotesFolder.Name = "Remotes"
  local self = setmetatable({
    InitDrawingTask = createRemoteEvent("InitDrawingTask", remotesFolder),
    UpdateDrawingTask = createRemoteEvent("UpdateDrawingTask", remotesFolder),
    FinishDrawingTask = createRemoteEvent("FinishDrawingTask", remotesFolder),
    Undo = createRemoteEvent("Undo", remotesFolder),
    Redo = createRemoteEvent("Redo", remotesFolder),
    Clear = createRemoteEvent("Clear", remotesFolder),
  }, BoardRemotes)

  remotesFolder.Parent = instance
  return self
end

function BoardRemotes.WaitForRemotes(instance)
  local remotesFolder = instance:WaitForChild("Remotes")
  return setmetatable({
    InitDrawingTask = remotesFolder:WaitForChild("InitDrawingTask"),
    UpdateDrawingTask = remotesFolder:WaitForChild("UpdateDrawingTask"),
    FinishDrawingTask = remotesFolder:WaitForChild("FinishDrawingTask"),
    Undo = remotesFolder:WaitForChild("Undo"),
    Redo = remotesFolder:WaitForChild("Redo"),
    Clear = remotesFolder:WaitForChild("Clear"),
  }, BoardRemotes)
end

return BoardRemotes