-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")

-- Import
local root = script.Parent.Parent
local Board = require(root.Board)
local BoardRemotes = require(root.BoardRemotes)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

--[[
	The server-side version of a board
--]]
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Part)

	local boardRemotes = BoardRemotes.new(instance)

	local self = setmetatable(Board.new({
	
		Instance = instance,
		BoardRemotes = boardRemotes,
	}), BoardServer)

	self.Watchers = {}

	self._destructor:Add(Players.PlayerRemoving:Connect(function(player)
		self.Watchers[player] = nil
	end))

	return self
end

function BoardServer:ConnectRemotes(beforeClear)

	local connections = {}

	--[[
		Connect remote event callbacks to respond to init/update/finish's of a drawing task,
		as well as undo, redo, clear events.
		The order these remote events are received is the globally agreed order.

		Note that everything is treated immutably, so that simple equality of objects (e.g. tables)
		can be used to detected changes (or lack of changes) of those objects.

		TODO: I don't think Player histories needs to be treated immutably. Check this reasoning.
	--]]

	table.insert(connections, self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

		-- Some drawing task behaviours mutate the board (usually EraseGrid)
		-- but they should only do that when it's verified (w.r.t. server authority about order of events)
		drawingTask = Dictionary.merge(drawingTask, { Verified = true })

		-- Tell only the clients that have an up-to-date version of this board
		for watcher in pairs(self.Watchers) do
			self.Remotes.InitDrawingTask:FireClient(watcher, tostring(player.UserId), drawingTask, canvasPos)
		end

		self:ProcessInitDrawingTask(tostring(player.UserId), drawingTask, canvasPos)
	end))

	table.insert(connections, self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)

		for watcher in pairs(self.Watchers) do
			self.Remotes.UpdateDrawingTask:FireClient(watcher, tostring(player.UserId), canvasPos)
		end

		self:ProcessUpdateDrawingTask(tostring(player.UserId), canvasPos)
	end))

	table.insert(connections, self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player)

		for watcher in pairs(self.Watchers) do
			self.Remotes.FinishDrawingTask:FireClient(watcher, tostring(player.UserId))
		end

		self:ProcessFinishDrawingTask(tostring(player.UserId))
	end))


	table.insert(connections, self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)

		local playerHistory = self.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountPast() < 1 then
			-- error("Cannot undo, past empty")
			-- No error so clients can just attempt undo
			return
		end

		for watcher in pairs(self.Watchers) do
			self.Remotes.Undo:FireClient(watcher, tostring(player.UserId))
		end

		self:ProcessUndo(tostring(player.UserId))
	end))

	table.insert(connections, self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)

		local playerHistory = self.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountFuture() < 1 then
			-- error("Cannot redo, future empty")
			-- No error so clients can just attempt redo
			return
		end

		for watcher in pairs(self.Watchers) do
			self.Remotes.Redo:FireClient(watcher, tostring(player.UserId))
		end

		self:ProcessRedo(tostring(player.UserId))
	end))

	table.insert(connections, self.Remotes.Clear.OnServerEvent:Connect(function(player: Player)

		for watcher in pairs(self.Watchers) do
			self.Remotes.Clear:FireClient(watcher, tostring(player.UserId))
		end
		
		-- This function is written externally so that the datastore is accessible
		if beforeClear then
			beforeClear()
		end

		self:ProcessClear()
	end))

	self._destructor:Add(function()
		
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)
end


return BoardServer