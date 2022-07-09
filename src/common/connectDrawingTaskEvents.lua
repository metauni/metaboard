-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")

-- Imports
local Config = require(Common.Config)
local History = require(Common.History)
local DrawingTask = require(Common.DrawingTask)
local EraseGrid = require(Common.EraseGrid)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Dictionary Operations
local set = Dictionary.set
local merge = Dictionary.merge

return function(board, destructor)

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
		Triggered after something changes the board state
		Clients behave differently so that they only react to changes once per
		frame (otherwise it affects writing performance).

		TODO: Is there any reason why the server shouldn't behave the same way?
	--]]
	local onChange = function()
		if isServer then
			board.DataChangedSignal:Fire()
		else
			board:DataChanged()
		end
	end

	--[[
		Connect remote event callbacks to respond to init/update/finish's of a drawing task,
		as well as undo, redo, clear events.
		The order these remote events are received is the globally agreed order.

		Note that everything is treated immutably, so that simple equality of objects (e.g. tables)
		can be used to detected changes (or lack of changes) of those objects.

		TODO: I don't think Player histories needs to be treated immutably. Check this reasoning.
	--]]

	destructor:Add(board.Remotes.InitDrawingTask[OnXEvent]:Connect(function(player: Player, drawingTask, canvasPos: Vector2)

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

		local newHistory = playerHistory:Clone()
		newHistory:Push(initialisedDrawingTask)
		board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

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

		onChange()
	end))

	destructor:Add(board.Remotes.UpdateDrawingTask[OnXEvent]:Connect(function(player: Player, canvasPos: Vector2)

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.UpdateDrawingTask:FireClient(watcher, player, canvasPos)
			end
		end

		local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
		assert(drawingTask)

		local updatedDrawingTask = DrawingTask.Update(drawingTask, board, canvasPos)

		local newHistory = board.PlayerHistories[tostring(player.UserId)]:Clone()
		newHistory:SetMostRecent(updatedDrawingTask)

		board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

		board.DrawingTasks = set(board.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

		onChange()
	end))

	destructor:Add(board.Remotes.FinishDrawingTask[OnXEvent]:Connect(function(player: Player)

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.FinishDrawingTask:FireClient(watcher, player)
			end
		end

		local drawingTask = board.PlayerHistories[tostring(player.UserId)]:MostRecent()
		assert(drawingTask)

		local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, board), "Finished", true)

		local newHistory = board.PlayerHistories[tostring(player.UserId)]:Clone()
		newHistory:SetMostRecent(finishedDrawingTask)

		board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

		board.DrawingTasks = set(board.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

		onChange()
	end))


	destructor:Add(board.Remotes.Undo[OnXEvent]:Connect(function(player: Player)

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

		local newHistory = playerHistory:Clone()

		local drawingTask = newHistory:StepBackward()
		assert(drawingTask)

		DrawingTask.Undo(drawingTask, board)

		board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, nil)
		board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

		onChange()
	end))

	destructor:Add(board.Remotes.Redo[OnXEvent]:Connect(function(player: Player)

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

		local newHistory = playerHistory:Clone()

		local drawingTask = newHistory:StepForward()
		assert(drawingTask)

		board.DrawingTasks = set(board.DrawingTasks, drawingTask.Id, drawingTask)
		board.PlayerHistories = set(board.PlayerHistories, tostring(player.UserId), newHistory)

		DrawingTask.Redo(drawingTask, board)

		onChange()
	end))

	destructor:Add(board.Remotes.Clear[OnXEvent]:Connect(function(player: Player)

		if isServer then
			for watcher in pairs(board.Watchers) do
				board.Remotes.Clear:FireClient(watcher, player)
			end
		end

		board.PlayerHistories = {}
		board.DrawingTasks = {}
		board.Figures = {}
		board.NextFigureZIndex = 0
		board.EraseGrid = EraseGrid.new(board:SurfaceSize().X / board:SurfaceSize().Y)

		onChange()
	end))

end