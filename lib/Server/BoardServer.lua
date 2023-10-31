-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import
local root = script.Parent.Parent
local BoardState = require(root.BoardState)
local BaseObject = require(root.Util.BaseObject)
local GoodSignal = require(root.Util.GoodSignal)
local Promise = require(root.Util.Promise)
local Blend = require(root.Util.Blend)
local ValueObject = require(root.Util.ValueObject)
local BoardRemotes = require(root.BoardRemotes)
local BoardUtils = require(root.BoardUtils)
local Persistence = require(root.Persistence)
local Config = require(root.Config)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

--[[
	The server-side version of a board
--]]
local BoardServer = setmetatable({}, BaseObject)
BoardServer.__index = BoardServer
BoardServer.ClassName = "BoardServer"

export type BoardServer = {
	State: BoardState.BoardState,
	Remotes: BoardRemotes.BoardRemotes,
	Watchers: {[Player]: true},
	BeforeClearSignal: { Connect: () -> {Disconnect: () -> ()}},
} & typeof(BoardServer)

function BoardServer.new(part: Part): BoardServer
	if part:IsA("Model") then
		error(`[metaboard] Model {part:GetFullName()} tagged as metaboard. Must tag PrimaryPart instead.`)
	end
	assert(part:IsA("Part"), "[metaboard] Tagged instance must be a Part: "..tostring(part:GetFullName()))

	local self = setmetatable(BaseObject.new(part), BoardServer)

	-- Will be nil until Loaded.Value = true
	self.State = nil
	-- Fires at most once per-frame
	self.StateChanged = self._maid:Add(GoodSignal.new())

	self.Remotes = self._maid:Add(BoardRemotes.new(part))
	self.Watchers = {}
	self.BeforeClearSignal = self._maid:Add(GoodSignal.new())
	-- When set to true, self.State should be set to a valid state
	self.Loaded = self._maid:Add(ValueObject.new(false, "boolean"))

	self._persistId = part:FindFirstChild("PersistId")
	if self._persistId then
		assert(typeof(self._persistId) == "Instance", `Bad persistId: {self._persistId}`)
		assert(self._persistId.ClassName == "IntValue", `Bad persistId.ClassName: {self._persistId.ClassName}`)
	end

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self.Watchers[player] = nil
	end))

	self._maid:GiveTask(function()
		self:GetPart():RemoveTag("BoardClient")
	end)

	return self
end

function BoardServer:GetPersistId(): number?
	if self._persistId then
		return self._persistId.Value
	end
	return nil
end

function BoardServer:GetPart(): Part
	return self._obj
end

function BoardServer:GetAspectRatio(): number
	return BoardUtils.getAspectRatioFromPart(self._obj)
end

--[[
	Connect remote event callbacks to respond to init/update/finish's of a drawing task,
	as well as undo, redo, clear events.
	The order these remote events are received is the globally agreed order.

	Note that everything is treated immutably, so that simple equality of objects (e.g. tables)
	can be used to detected changes (or lack of changes) of those objects.

	TODO: I don't think Player histories needs to be treated immutably. Check this reasoning.
--]]
function BoardServer:ConnectRemotes()

	local tasks = {}
	-- This first cleans up the old list of connections if there was one
	-- then remembers these tasks in the maid
	self._maid._remoteTasks = tasks

	local stateChangedThisFrame = false
	local function checkUpdate()
		if stateChangedThisFrame then
			self.StateChanged:Fire()
			-- Does ordering matter here? Is it possible that the state changes again?
			stateChangedThisFrame = false
		end
	end

	-- Check once per frame, and once on cleanup in case of race.
	table.insert(tasks, RunService.Heartbeat:Connect(checkUpdate))
	table.insert(tasks, checkUpdate)

	table.insert(tasks, self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

		-- Some drawing task behaviours mutate the board (usually EraseGrid)
		-- but they should only do that when it's verified (w.r.t. server authority about order of events)
		drawingTask = Dictionary.merge(drawingTask, { Verified = true })

		-- Tell only the clients that have an up-to-date version of this board
		for watcher in pairs(self.Watchers) do
			self.Remotes.InitDrawingTask:FireClient(watcher, tostring(player.UserId), drawingTask, canvasPos)
		end

		BoardState.InitDrawingTask(self.State, tostring(player.UserId), drawingTask, canvasPos)
		stateChangedThisFrame = true
	end))

	table.insert(tasks, self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, canvasPos: Vector2)

		for watcher in pairs(self.Watchers) do
			self.Remotes.UpdateDrawingTask:FireClient(watcher, tostring(player.UserId), canvasPos)
		end

		BoardState.UpdateDrawingTask(self.State, tostring(player.UserId), canvasPos)
		stateChangedThisFrame = true
	end))

	table.insert(tasks, self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player)

		for watcher in pairs(self.Watchers) do
			self.Remotes.FinishDrawingTask:FireClient(watcher, tostring(player.UserId))
		end

		BoardState.FinishDrawingTask(self.State, tostring(player.UserId))
		stateChangedThisFrame = true
	end))


	table.insert(tasks, self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)

		local playerHistory = self.State.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountPast() < 1 then
			-- error("Cannot undo, past empty")
			-- No error so clients can just attempt undo
			return
		end

		for watcher in pairs(self.Watchers) do
			self.Remotes.Undo:FireClient(watcher, tostring(player.UserId))
		end

		BoardState.Undo(self.State, tostring(player.UserId))
		stateChangedThisFrame = true
	end))

	table.insert(tasks, self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)

		local playerHistory = self.State.PlayerHistories[tostring(player.UserId)]

		if playerHistory == nil or playerHistory:CountFuture() < 1 then
			-- error("Cannot redo, future empty")
			-- No error so clients can just attempt redo
			return
		end

		for watcher in pairs(self.Watchers) do
			self.Remotes.Redo:FireClient(watcher, tostring(player.UserId))
		end

		BoardState.Redo(self.State, tostring(player.UserId))
		stateChangedThisFrame = true
	end))

	table.insert(tasks, self.Remotes.Clear.OnServerEvent:Connect(function(player: Player)

		for watcher in pairs(self.Watchers) do
			self.Remotes.Clear:FireClient(watcher, tostring(player.UserId))
		end
		
		-- Behaviour is written externally so that the datastore is accessible
		self.BeforeClearSignal:Fire()

		BoardState.Clear(self.State)
		stateChangedThisFrame = true
	end))

	self.Remotes.GetBoardData.OnServerInvoke = function(player: Player)
		self.Watchers[player] = true
		return {
			Figures = self.State.Figures,
			DrawingTasks = self.State.DrawingTasks,
			AspectRatio = self.State.AspectRatio,
			PlayerHistories = self.State.PlayerHistories,
			NextFigureZIndex = self.State.NextFigureZIndex,
		}
	end

	table.insert(tasks, function()
		self.Remotes.GetBoardData.OnServerInvoke = nil
	end)
end

function BoardServer:IsLoadPending(): boolean
	return self._loadPromise and self._loadPromise:IsPending()
end

function BoardServer:LoadFromDataStore(datastore: DataStore)
	if self._loadPromise then
		if not self._loadPromise:IsRejected() then
			return
		end
	end

	local persistId = self:GetPersistId()
	if not persistId then
		self.State = BoardState.emptyState(self:GetAspectRatio())
		self.Loaded.Value = true
		return
	end

	self._loadPromise = Promise.spawn(function(resolve, reject)
		local boardKey = Config.Persistence.PersistIdToBoardKey(persistId)
		local success, result = Persistence.Restore(datastore, boardKey, self)
		if success then
			return resolve(result)
		else
			return reject(result)
		end
	end):Then(function(data)
		self.State = BoardState.deserialise({
			Figures = data.Figures,
			AspectRatio = self:GetAspectRatio(),
			DrawingTasks = {},
			PlayerHistories = {},
			NextFigureZIndex = data.NextFigureZIndex,
			EraseGrid = data.EraseGrid,
			ClearCount = data.ClearCount,
		})

		self.Loaded.Value = true
	end)

	self._loadPromise:Catch(function(msg)
		self:_indicateInvalidBoard(msg)
	end)
end

function BoardServer:_indicateInvalidBoard(message)

	local surfaceCFrame = BoardUtils.getSurfaceCFrameFromPart(self:GetPart())
	local surfaceSize = BoardUtils.getSurfaceSizeFromPart(self:GetPart())

	local cleanup = {}
	self._maid[cleanup] = cleanup

	table.insert(cleanup, self.Loaded.Changed:Connect(function(isLoaded: boolean)
		if isLoaded then
			self._maid[cleanup] = nil
		end
	end))

	table.insert(cleanup, Blend.mount(workspace, {
		Blend.New "Part" {
			Name = "BoardInvalidIndicator",
			Size = Vector3.new(surfaceSize.X, surfaceSize.Y, 0.01),
			CFrame = surfaceCFrame + surfaceCFrame.LookVector * 0.01/2,
			Transparency = 1,
			Anchored = true,
			CanCollide = false,
			CastShadow = false,
			CanTouch = false,
			CanQuery = true,

			Blend.New "SurfaceGui" {
				[Blend.Instance] = function(instance)
					instance.Adornee = instance.Parent
				end,

				Blend.New "TextLabel" {
					AnchorPoint = Vector2.new(0.5,0.5),
					Position = UDim2.fromScale(0.5,0.5),
					Size = UDim2.fromScale(0.75, 0.75),
					Text = "Failed to Load Board from DataStore for "..self:GetPart():GetFullName().."\n"..message,
					TextScaled = true,
					BackgroundColor3 = Color3.new(1,0,0),
				}
			}
		}
	}))
end


return BoardServer