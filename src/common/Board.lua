-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local RunService = game:GetService("RunService")
-- Services
local Common = script.Parent

-- Imports
local Config = require(Common.Config)
local EraseGrid = require(Common.EraseGrid)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local Signal = require(Common.Packages.GoodSignal)
local Destructor = require(Common.Destructor)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Board
local Board = {}
Board.__index = Board

export type BoardArgs = {
	Instance: Model | Part,
	BoardRemotes: any,
	SurfaceCFrame: CFrame,
	SurfaceSize: Vector2,
}

function Board.new(boardArgs)
	local self = setmetatable({
		_instance = boardArgs.Instance,
		Remotes = boardArgs.BoardRemotes,
		SurfaceCFrame = boardArgs.SurfaceCFrame,
		SurfaceSize = boardArgs.SurfaceSize,
		PlayerHistories = {},
		DrawingTasks = {},
		Figures = {},
		NextFigureZIndex = 0,
	}, Board)

	--[[
		:Add() RBXSignalConnections, Instances and destroyer functions to this
		to be cleaned up when Board:Destroy() is called. Currently we don't have
		a use case where we actually need to destroy a board (not just the canvas),
		but it's right to keep track of such connected things.
	--]]
	self._destructor = Destructor.new()

	--[[
		Fired (at most) once per frame when either self.Figures or self.DrawingTasks
		changes. Note that these tables are treated immutably, so e.g. if
		oldFigures == self.NewFigures, then oldFigures has the exact same contents
		as self.Figures.
	--]]
	self.DataChangedSignal = Signal.new()
	self._destructor:Add(function()
		self.DataChangedSignal:DisconnectAll()
	end)

	--[[
		Other scripts should use `Board:DataChanged()` instead of firing the signal,
		so that connected callbacks are fired (at most) once per frame.
	--]]
	local schedulerSignal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
	self._destructor:Add(schedulerSignal:Connect(function()

		if self._dataChangedThisFrame then
			self.DataChangedSignal:Fire()
			self._dataChangedThisFrame = false
		end
	end))

	self.EraseGrid = EraseGrid.new(self:AspectRatio())

	self._instance.Destroying:Connect(function()
	
		self._destructor:Destroy()
	end)

	return self
end

function Board:Destroy()
	
	self._destructor:Destroy()
end

function Board:Name()
	return self._instance.Name
end

function Board:FullName()
	return self._instance:GetFullName()
end

function Board:DataChanged()
	self._dataChangedThisFrame = true
end

function Board:CommitAllDrawingTasks()

	local drawingTaskFigures = {}

	for taskId, drawingTask in pairs(self.DrawingTasks) do
		-- TODO: Should we only commit finished drawing tasks? If not then
		-- things get inserted into the erase grid that shouldn't be in LoadData
		if drawingTask.Type ~= "Erase" and drawingTask.Finished then
			drawingTaskFigures[taskId] = DrawingTask.Render(drawingTask)
		end
	end

	local allFigures = Dictionary.merge(self.Figures, drawingTaskFigures)

	local allMaskedFigures = allFigures
	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.Type == "Erase" then
			allMaskedFigures = DrawingTask.Commit(drawingTask, allMaskedFigures)
		end
	end

	return allMaskedFigures
end

function Board:LoadData(data)
	assert(data.Figures)
	assert(data.DrawingTasks)
	assert(data.PlayerHistories)
	assert(data.NextFigureZIndex)
	-- eraseGrid can be nil (can be recreated)
	-- clearCount is not always needed

	for userId, playerHistory in pairs(data.PlayerHistories) do
		setmetatable(playerHistory, History)
	end

	self.Figures = data.Figures
	self.DrawingTasks = data.DrawingTasks
	self.PlayerHistories = data.PlayerHistories
	self.NextFigureZIndex = data.NextFigureZIndex
	self.ClearCount = data.ClearCount

	local eraseGrid = data.EraseGrid do
		
		if not eraseGrid then
			eraseGrid = EraseGrid.new(self:AspectRatio())
	
			local committedFigures = self:CommitAllDrawingTasks()
	
			for figureId, figure in pairs(committedFigures) do
				eraseGrid:AddFigure(figureId, figure)
			end
		end
	end

	self.EraseGrid = eraseGrid
end

--[[
	An upper bound on the number of lines on the board
	(doesn't account for erased lines)
--]]
function Board:LinesForBudget()
	local count = 0

	for figureId, figure in pairs(self.Figures) do
		if figure.Type == "Curve" then
			count += #figure.Points
		else
			count += 1
		end
	end

	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.Type ~= "Erase" then
			local figure = DrawingTask.Render(drawingTask)

			if figure.Type == "Curve" then
				count += #figure.Points
			else
				count += 1
			end
		end
	end

	return count
end


function Board:AspectRatio()

	return self.SurfaceSize.X / self.SurfaceSize.Y
end

--[[
	These ProcessX methods implement a change to the board state, most of them
	corresponding to some user input.
	BoardServer and BoardClient make uses of these in the :ConnectRemotes() method.
--]]

function Board:ProcessInitDrawingTask(authorId: string, drawingTask, canvasPos: Vector2)
	
	-- Get or create the player history for this player
	local playerHistory = self.PlayerHistories[authorId] or History.new(Config.History.Capacity)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self, canvasPos)
	self.DrawingTasks = Dictionary.set(self.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

	playerHistory:Push(initialisedDrawingTask)
	self.PlayerHistories[authorId] = playerHistory

	-- Any drawing task which doesn't appear in any player history is a candidate for committing
	local needsCommitDrawingTasks = table.clone(self.DrawingTasks)
	for playerId, pHistory in pairs(self.PlayerHistories) do

		for historyDrawingTask in pHistory:IterPastAndFuture() do

			needsCommitDrawingTasks[historyDrawingTask.Id] = nil

		end
	end

	for taskId, dTask in pairs(needsCommitDrawingTasks) do
		local canCommit

		if dTask.Type == "Erase" then
			-- Every figure being (partially) erased must be gone from DrawingTasks
			canCommit = Dictionary.every(dTask.FigureIdToMask, function(mask, figureId)
				return self.DrawingTasks[figureId] == nil
			end)
		else
			canCommit = true
		end

		if canCommit then
			self.Figures = DrawingTask.Commit(dTask, self.Figures)
			self.DrawingTasks = Dictionary.set(self.DrawingTasks, dTask.Id, nil)
		end

		-- Drawing Tasks not committed now will be committed later when canCommitt == true

	end

	-- Any callbacks connected to self.DataChangedSignal will fire in RenderStepped.
	self:DataChanged()
end

function Board:ProcessUpdateDrawingTask(authorId: string, canvasPos: Vector2)

	local drawingTask = self.PlayerHistories[authorId]:MostRecent()
	assert(drawingTask)

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self, canvasPos)

	local playerHistory = self.PlayerHistories[authorId]
	playerHistory:SetMostRecent(updatedDrawingTask)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

	self:DataChanged()
end

function Board:ProcessFinishDrawingTask(authorId: string)
	
	local drawingTask = self.PlayerHistories[authorId]:MostRecent()
	assert(drawingTask)

	local finishedDrawingTask = Dictionary.set(DrawingTask.Finish(drawingTask, self), "Finished", true)

	local playerHistory = self.PlayerHistories[authorId]
	playerHistory:SetMostRecent(finishedDrawingTask)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

	self:DataChanged()
end

function Board:ProcessUndo(authorId: string)

	local playerHistory = self.PlayerHistories[authorId]

	if playerHistory == nil or playerHistory:CountPast() < 1 then
		error("Cannot undo, past empty")
		return
	end
	
	local drawingTask = playerHistory:StepBackward()
	assert(drawingTask)

	DrawingTask.Undo(drawingTask, self)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, drawingTask.Id, nil)

	self:DataChanged()
end

function Board:ProcessRedo(authorId: string)
	
	local playerHistory = self.PlayerHistories[authorId]

	if playerHistory == nil or playerHistory:CountFuture() < 1 then
		error("Cannot redo, future empty")
		return
	end

	local drawingTask = playerHistory:StepForward()
	assert(drawingTask)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, drawingTask.Id, drawingTask)

	DrawingTask.Redo(drawingTask, self)

	self:DataChanged()
end

function Board:ProcessClear(_)
	
	self.PlayerHistories = {}
	self.DrawingTasks = {}
	self.Figures = {}
	self.NextFigureZIndex = 0
	self.EraseGrid = EraseGrid.new(self:AspectRatio())

	self:DataChanged()
end

return Board