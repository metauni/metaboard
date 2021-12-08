local args = {...}
local input = args[1] or "build.rbxlx"
local output = args[2] or "metaboard.rbxmx"

local game = remodel.readPlaceFile(input)

local metaBoardServer = game.ServerScriptService.MetaBoardServer
local metaBoardPlayer = game.StarterPlayer.StarterPlayerScripts.MetaBoardPlayer
local metaBoardCommon = game.ReplicatedStorage.MetaBoardCommon
local boardGui = game.StarterGui.BoardGui
local cursorsGui = game.StarterGui.CursorsGui

metaBoardPlayer.Parent = metaBoardServer
metaBoardCommon.Parent = metaBoardServer
boardGui.Parent = metaBoardServer
cursorsGui.Parent = metaBoardServer

remodel.writeModelFile(metaBoardServer, output)