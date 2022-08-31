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

function BoardRemotes:Connect(board, serverOnClear)

	local connections = {}

	local isServer = RunService:IsServer()

	-- The Roblox client-server model forms a boolean topos
	local isClient = not isServer

	--[[
		Note that the first argument in all of the callbacks below is the player
		who is performing the associated drawing task.
		For `OnServerEvent`, Roblox inserts the client who fired the remote
		event in front of whatever arguments they supply. For `OnClientEvent`,
		this argument is given explicitly (it's the second argument in `FireClient`)

		This is why the arguments are uniform regardless of what `OnXEvent` is.
	--]]
	local OnXEvent = isServer and "OnServerEvent" or "OnClientEvent"

	--[[
		Connect remote event callbacks to respond to init/update/finish's of a drawing task,
		as well as undo, redo, clear events.
		The order these remote events are received is the globally agreed order.

		Note that everything is treated immutably, so that simple equality of objects (e.g. tables)
		can be used to detected changes (or lack of changes) of those objects.

		TODO: I don't think Player histories needs to be treated immutably. Check this reasoning.
	--]]

	table.insert(connections, board.Remotes.InitDrawingTask[OnXEvent]:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

		if isServer then
			-- Some drawing task behaviours mutate the board (usually EraseGrid)
			-- but they should only do that when it's verified (w.r.t. server authority about order of events)
			drawingTask = merge(drawingTask, { Verified = true })

			-- Tell only the clients that have an up-to-date version of this board
			for watcher in pairs(board.Watchers) do
				board.Remotes.InitDrawingTask:FireClient(watcher, player, drawingTask, canvasPos)
			end
		end

		-- Get or create the player history for this player
		local playerHistory = board.PlayerHistories[tostring(player.UserId)] or History.new(Config.History.Capacity)

		local initialisedDrawingTask = DrawingTask.Init(drawingTask, board, canvasPos)
		board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

		playerHistory:Push(initialisedDrawingTask)
		board.PlayerHistories[tostring(player.UserId)] = playerHistory

		-- Any drawing task which doesn't appear in any player history is a candidate for committing
		local needsCommitDrawingTasks = table.clone(board.DrawingTasks)
		for playerId, pHistory in pairs(board.PlayerHistories) do

			for historyDrawingTask in pHistory:IterPastAndFuture() do

				needsCommitDrawingTasks[historyDrawingTask.Id] = nil

			end
		end

		for taskId, dTask in pairs(needsCommitDrawingTasks) do
			local canCommit

			if dTask.Type == "Erase" then
				-- Every figure being (partially) erased must be gone from DrawingTasks
				canCommit = Dictionary.every(dTask.FigureIdToMask, function(mask, figureId)
					return board.DrawingTasks[figureId] == nil
				end)
			else
				canCommit = true
			end

			if canCommit then
				board.Figures = DrawingTask.Commit(dTask, board.Figures)
				board.DrawingTasks = set(board.DrawingTasks, dTask.Id, nil)
			end

			-- Drawing Tasks not committed now will be committed later when canCommitt == true

		end

		-- Any callbacks connected to board.DataChangedSignal will fire in RenderStepped.
		board:DataChanged()
	end))

	table.insert(connections, board.Remotes.UpdateDrawingTask[OnXEvent]:Connect(function(player: Player, canvasPos: Vector2)

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.UpdateDrawingTask:FireClient(watcher, player, canvasPos)
			end
		end

		local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
		assert(drawingTask)

		local updatedDrawingTask = DrawingTask.Update(drawingTask, board, canvasPos)

		local playerHistory = board.PlayerHistories[tostring(player.UserId)]
		playerHistory:SetMostRecent(updatedDrawingTask)

		board.DrawingTasks = set(board.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

		board:DataChanged()
	end))

	table.insert(connections, board.Remotes.FinishDrawingTask[OnXEvent]:Connect(function(player: Player)

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.FinishDrawingTask:FireClient(watcher, player)
			end
		end

		local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
		assert(drawingTask)

		local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, board), "Finished", true)

		local playerHistory = board.PlayerHistories[tostring(player.UserId)]
		playerHistory:SetMostRecent(finishedDrawingTask)

		board.DrawingTasks = set(board.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

		board:DataChanged()
	end))


	table.insert(connections, board.Remotes.Undo[OnXEvent]:Connect(function(player: Player)

		local playerHistory = board.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountPast() < 1 then
			-- error("Cannot undo, past empty")
			-- No error so clients can just attempt undo
			return
		end

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.Undo:FireClient(watcher, player)
			end
		end

		local drawingTask = playerHistory:StepBackward()
		assert(drawingTask)

		DrawingTask.Undo(drawingTask, board)

		board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, nil)

		board:DataChanged()
	end))

	table.insert(connections, board.Remotes.Redo[OnXEvent]:Connect(function(player: Player)

		local playerHistory = board.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountFuture() < 1 then
			-- error("Cannot redo, future empty")
			-- No error so clients can just attempt redo
			return
		end

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.Redo:FireClient(watcher, player)
			end
		end

		local drawingTask = playerHistory:StepForward()
		assert(drawingTask)

		board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, drawingTask)

		DrawingTask.Redo(drawingTask, board)

		board:DataChanged()
	end))

	table.insert(connections, board.Remotes.Clear[OnXEvent]:Connect(function(player: Player)

		if isServer then

			for watcher in pairs(board.Watchers) do
				board.Remotes.Clear:FireClient(watcher, player)
			end
			
			-- This function is written externally so that the datastore is accessible
			if serverOnClear then
				serverOnClear()
			end
		end

		board.PlayerHistories = {}
		board.DrawingTasks = {}
		board.Figures = {}
		board.NextFigureZIndex = 0
		board.EraseGrid = EraseGrid.new(board:SurfaceSize().X / board:SurfaceSize().Y)

		board:DataChanged()
	end))

	return function ()
		for _, connection in ipairs(connections) do
			connection:Destroy()
		end
	end

end

return BoardRemotes