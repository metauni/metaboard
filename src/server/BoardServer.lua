-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")

-- Import
local Board = require(Common.Board)
local BoardRemotes = require(Common.BoardRemotes)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

--[[
	The server-side version of a board
--]]
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part)

	if workspace.StreamingEnabled then
		
		assert(instance:IsA("Model"), 
			"[metaboard] metaboard instance "..instance:GetFullName().." is not a model.\n"
			.."Incompatible with Workspace.StreamingEnabled = true"
		)
	end

	local surfaceCFrame, surfaceSize3
	
	local surfacePart

	if instance:IsA("Model") then
		
		assert(instance.PrimaryPart, "metaboard Model must have PrimaryPart set: "..instance:GetFullName())
		surfacePart = instance.PrimaryPart
	else
		
		surfacePart = instance
	end

	local faceAngleCFrame = {
		Front  = CFrame.Angles(0, 0, 0),
		Left   = CFrame.Angles(0, math.pi / 2, 0),
		Back   = CFrame.Angles(0, math.pi, 0),
		Right  = CFrame.Angles(0, -math.pi / 2, 0),
		Top    = CFrame.Angles(math.pi / 2, 0, 0),
		Bottom = CFrame.Angles(-math.pi / 2, 0, 0)
	}

	local faceSurfaceOffsetGetter = {
		Front  = function(size) return size.Z / 2 end,
		Left   = function(size) return size.X / 2 end,
		Back   = function(size) return size.Z / 2 end,
		Right  = function(size) return size.X / 2 end,
		Top    = function(size) return size.Y / 2 end,
		Bottom = function(size) return size.Y / 2 end
	}

	local faceDimensionsGetter = {
		Front  = function(size) return Vector3.new(size.X, size.Y, 0) end,
		Left   = function(size) return Vector3.new(size.Z, size.Y, 0) end,
		Back   = function(size) return Vector3.new(size.X, size.Y, 0) end,
		Right  = function(size) return Vector3.new(size.Z, size.Y, 0) end,
		Top    = function(size) return Vector3.new(size.X, size.Z, 0) end,
		Bottom = function(size) return Vector3.new(size.X, size.Z, 0) end,
	}

	local face do

		local faceValue = instance:FindFirstChild("Face")
		face = faceValue and faceValue.Value or "Front"
	end


	surfaceSize3 = faceDimensionsGetter[face](surfacePart.Size)
	surfaceCFrame = surfacePart.CFrame
		* faceAngleCFrame[face]
		* CFrame.new(0, 0, -faceSurfaceOffsetGetter[face](surfacePart.Size))

-- Values needed for clients with board streamed out
	
	local surfaceCFrameValue = Instance.new("CFrameValue")
	surfaceCFrameValue.Name = "SurfaceCFrameValue"
	surfaceCFrameValue.Value = surfaceCFrame
	surfaceCFrameValue.Parent = instance
	
	local surfaceSizeValue = Instance.new("Vector3Value")
	surfaceSizeValue.Name = "SurfaceSizeValue"
	surfaceSizeValue.Value = surfaceSize3
	surfaceSizeValue.Parent = instance

	local boardRemotes = BoardRemotes.new(instance)

	local self = setmetatable(Board.new({
	
		Instance = instance,
		BoardRemotes = boardRemotes,
		SurfaceCFrame = surfaceCFrame,
		SurfaceSize = surfaceSize3
	}), BoardServer)

	self.Watchers = {}

	self._destructor:Add(Players.PlayerRemoving:Connect(function(player)
		self.Watchers[player] = nil
	end))

	self._destructor:Add(surfacePart:GetPropertyChangedSignal("CFrame"):Connect(function()
		
		surfaceCFrameValue.Value = surfacePart.CFrame
			* faceAngleCFrame[face]
			* CFrame.new(0, 0, -faceSurfaceOffsetGetter[face](surfacePart.Size))
	end))

	self._destructor:Add(surfacePart:GetPropertyChangedSignal("Size"):Connect(function()
		
		surfaceSizeValue.Value = faceDimensionsGetter[face](surfacePart.Size)
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