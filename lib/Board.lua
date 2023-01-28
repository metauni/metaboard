-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local RunService = game:GetService("RunService")

-- Imports
local root = script.Parent
local Config = require(root.Config)
local EraseGrid = require(root.EraseGrid)
local DrawingTask = require(root.DrawingTask)
local History = require(root.History)
local Signal = require(root.Parent.GoodSignal)
local Destructor = require(root.Destructor)
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Board
local Board = {}
Board.__index = Board

export type Connection = {
	Disconnect: () -> (),
}

export type Signal = {
	Connect: ((...any) -> ()) -> Connection,
	Fire: (...any) -> (),
}

export type Board = {
	_instance: Part,
	Remotes: BoardRemotes,
	PlayerHistories: {[string]: History},
	DrawingTasks: {[string]: DrawingTask},
	Figures: {[string]: Figure},
	NextFigureZIndex: number,
	DataChangedSignal: {Connect: () -> ()},
	SurfaceChangedSignal: {Connect: () -> ()},
}

export type BoardArgs = {
	Instance: Model | Part,
	BoardRemotes: any,
}

function Board.new(boardArgs): Board
	local self = setmetatable({
		_instance = boardArgs.Instance,
		Remotes = boardArgs.BoardRemotes,
		PlayerHistories = {},
		DrawingTasks = {},
		Figures = {},
		NextFigureZIndex = 0,
	}, Board) :: Board

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

	-- Orientation of the face CFrame
	local FACE_ANGLE_CFRAME = {
		Front  = CFrame.Angles(0, 0, 0),
		Left   = CFrame.Angles(0, math.pi / 2, 0),
		Back   = CFrame.Angles(0, math.pi, 0),
		Right  = CFrame.Angles(0, -math.pi / 2, 0),
		Top    = CFrame.Angles(math.pi / 2, 0, 0),
		Bottom = CFrame.Angles(-math.pi / 2, 0, 0)
	}
	
	-- The width, height and normal axes to the face
	local FACE_AXES = {
		Front  = {"X", "Y", "Z"},
		Left   = {"Z", "Y", "X"},
		Back   = {"X", "Y", "Z"},
		Right  = {"Z", "Y", "X"},
		Top    = {"X", "Z", "Y"},
		Bottom = {"X", "Z", "Y"},
	}
	
	local faceValue = self._instance:FindFirstChild("Face")
	local face = faceValue and faceValue.Value or "Front"
	local faceAxes = FACE_AXES[face]
	local faceAngleCFrame = FACE_ANGLE_CFRAME[face]

	local function size()
		return Vector2.new(
			self._instance.Size[faceAxes[1]],
			self._instance.Size[faceAxes[2]])
	end

	local function cframe()
		return self._instance.CFrame
			* faceAngleCFrame
			* CFrame.new(0, 0, -self._instance.Size[faceAxes[3]]/2)
	end

	self.SurfaceSize = size()
	self.SurfaceCFrame = cframe()

	self.SurfaceChangedSignal = Signal.new()
	self._destructor:Add(function()
		self.SurfaceChangedSignal:DisconnectAll()
	end)

	self._destructor:Add(self._instance:GetPropertyChangedSignal("Size"):Connect(function()
		self.SurfaceSize = size()
		self.SurfaceChangedSignal:Fire()
	end))
	
	self._destructor:Add(self._instance:GetPropertyChangedSignal("CFrame"):Connect(function()
		self.SurfaceCFrame = cframe()
		self.SurfaceChangedSignal:Fire()
	end))
	
	self._destructor:Add(self._instance.AncestryChanged:Connect(function()
		self.SurfaceChangedSignal:Fire()
	end))

	self.EraseGrid = EraseGrid.new(self:AspectRatio())

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
	for _, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.Type == "Erase" then
			allMaskedFigures = DrawingTask.Commit(drawingTask, allMaskedFigures)
		end
	end

	return allMaskedFigures
end

function Board:LoadData(data)
	local msg = "[metaboard] Bad board data "..tostring(self:FullName())
	assert(data.Figures, msg)
	assert(data.DrawingTasks, msg)
	assert(data.PlayerHistories, msg)
	assert(data.NextFigureZIndex, msg)
	-- eraseGrid can be nil (can be recreated)
	-- clearCount is not always needed

	for _, playerHistory in pairs(data.PlayerHistories) do
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

	for _, figure in pairs(self.Figures) do
		if figure.Type == "Curve" then
			count += #figure.Points
		else
			count += 1
		end
	end

	for _, drawingTask in pairs(self.DrawingTasks) do
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

	if not drawingTask then
		error(("[metaboard] Tried to init nil Drawing Task\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end
	
	-- Get or create the player history for this player
	local playerHistory = self.PlayerHistories[authorId] or History.new(Config.History.Capacity)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self, canvasPos)
	self.DrawingTasks = Dictionary.set(self.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

	playerHistory:Push(initialisedDrawingTask)
	self.PlayerHistories[authorId] = playerHistory

	-- Any drawing task which doesn't appear in any player history is a candidate for committing
	local needsCommitDrawingTasks = table.clone(self.DrawingTasks)
	for _, pHistory in pairs(self.PlayerHistories) do

		for historyDrawingTask in pHistory:IterPastAndFuture() do

			needsCommitDrawingTasks[historyDrawingTask.Id] = nil

		end
	end

	for _, dTask in pairs(needsCommitDrawingTasks) do
		local canCommit

		if dTask.Type == "Erase" then
			-- Every figure being (partially) erased must be gone from DrawingTasks
			canCommit = Dictionary.every(dTask.FigureIdToMask, function(_mask, figureId)
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

	local playerHistory = self.PlayerHistories[authorId]
	if not playerHistory then
		error(("[metaboard] Tried to update drawing task of player with no history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end

	local drawingTask = playerHistory:MostRecent()
	if not drawingTask then
		error(("[metaboard] Tried to update non-existent drawing task\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self, canvasPos)

	playerHistory:SetMostRecent(updatedDrawingTask)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)

	self:DataChanged()
end

function Board:ProcessFinishDrawingTask(authorId: string)
	
	local playerHistory = self.PlayerHistories[authorId]
	if not playerHistory then
		error(("[metaboard] Tried to finish drawing task of player with no history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end

	local drawingTask = playerHistory:MostRecent()
	if not drawingTask then
		error(("[metaboard] Tried to finish non-existent drawing task\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end

	local finishedDrawingTask = Dictionary.set(DrawingTask.Finish(drawingTask, self), "Finished", true)

	playerHistory:SetMostRecent(finishedDrawingTask)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)

	self:DataChanged()
end

function Board:ProcessUndo(authorId: string)

	local playerHistory = self.PlayerHistories[authorId]
	if not playerHistory then
		error(("[metaboard] Tried to perform undo for player with no history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end
	if playerHistory:CountPast() < 1 then
		error(("[metaboard] Tried to perform undo for player with empty history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end
	
	local drawingTask = playerHistory:StepBackward()

	DrawingTask.Undo(drawingTask, self)

	self.DrawingTasks = Dictionary.set(self.DrawingTasks, drawingTask.Id, nil)

	self:DataChanged()
end

function Board:ProcessRedo(authorId: string)
	
	local playerHistory = self.PlayerHistories[authorId]
	if not playerHistory then
		error(("[metaboard] Tried to perform redo for player with no history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end
	if playerHistory:CountFuture() < 1 then
		error(("[metaboard] Tried to perform redo for player with empty history\nBoard Name: %s, authorId: %s"):format(self:FullName(), authorId))
	end
	
	local drawingTask = playerHistory:StepForward()

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