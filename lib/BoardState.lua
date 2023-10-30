-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local root = script.Parent
local EraseGrid = require(root.EraseGrid)
local DrawingTask = require(root.DrawingTask)
local Figure = require(root.Figure)
local Config = require(root.Config)
local History = require(root.History)
local Sift = require(root.Parent.Sift)
local Dictionary = Sift.Dictionary
local BaseObject = require(root.Util.BaseObject)

--[[
	For creating and updating board state
]]
local BoardState = {}
BoardState.__index = setmetatable({}, BaseObject)

export type DrawingTaskDict = {[string]: {DrawingTask.DrawingTask}}
export type FigureDict = {[string]: {Figure.AnyFigure}}
export type FigureMaskDict = {[string]: {Figure.AnyMask}}

export type BoardState = {
	AspectRatio: number,
	Figures: FigureDict,
	DrawingTasks: DrawingTaskDict,
	PlayerHistories: {[string]: History.History},
	NextFigureZIndex: number,
	ClearCount: number?,
	EraseGrid: EraseGrid.EraseGrid?,
}

function BoardState.commitAllDrawingTasks(drawingTasks: DrawingTaskDict, figures: FigureDict)

	local drawingTaskFigures = {}

	for taskId, drawingTask in pairs(drawingTasks) do
		-- TODO: Should we only commit finished drawing tasks? If not then
		-- things get inserted into the erase grid that shouldn't be in LoadData
		-- Update: LoadData has been replaced by .deserialise. Question still stands.
		if drawingTask.Type ~= "Erase" and drawingTask.Finished then
			drawingTaskFigures[taskId] = DrawingTask.Render(drawingTask)
		end
	end

	local allFigures = Dictionary.merge(figures, drawingTaskFigures)

	local allMaskedFigures = allFigures
	for _, drawingTask in pairs(drawingTasks) do
		if drawingTask.Type == "Erase" then
			allMaskedFigures = DrawingTask.Commit(drawingTask, allMaskedFigures)
		end
	end

	return allMaskedFigures
end

function BoardState.emptyState(aspectRatio: number)
	assert(typeof(aspectRatio) == "number", "Bad aspectRatio")
	return {
		AspectRatio = aspectRatio,
		Figures = {},
		DrawingTasks = {},
		PlayerHistories = {},
		NextFigureZIndex = 0,
		EraseGrid = EraseGrid.new(aspectRatio), 
	}
end

function BoardState.deserialise(data: any)
	assert(typeof(data) == "table", "Bad board data, not a table")
	local msg = "[metaboard] Bad board data"
	assert(typeof(data.AspectRatio) == "number", msg)
	assert(typeof(data.Figures) == "table", msg)
	assert(typeof(data.DrawingTasks) == "table", msg)
	assert(typeof(data.PlayerHistories) == "table", msg)
	assert(typeof(data.NextFigureZIndex) == "number", msg)
	assert(data.ClearCount == nil or typeof(data.ClearCount) == "number", msg)

	local playerHistories = {}
	for key, playerHistory in pairs(data.PlayerHistories) do
		playerHistories[key] = setmetatable(playerHistory, History)
	end
	
	-- Ignores erase grid even if it appears in data
	-- TODO: consider (data won't have metatable)
	local eraseGrid = EraseGrid.new(data.AspectRatio)
	
	local committedFigures = BoardState.commitAllDrawingTasks(data.DrawingTasks, data.Figures)
	for figureId, figure in committedFigures do
		(eraseGrid :: any):AddFigure(figureId, figure)
	end

	return {
		AspectRatio = data.AspectRatio,
		Figures = data.Figures,
		DrawingTasks = data.DrawingTasks,
		PlayerHistories = playerHistories,
		NextFigureZIndex = data.NextFigureZIndex,
		ClearCount = data.ClearCount,
		EraseGrid = eraseGrid,
	}
end

--[[
	An upper bound on the number of lines on the board
	(doesn't account for erased lines)
--]]
function BoardState.linesForBudget(state)
	local count = 0

	for _, figure in state.Figures do
		if figure.Type == "Curve" then
			count += #figure.Points
		else
			count += 1
		end
	end

	for _, drawingTask in state.DrawingTasks do
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

function BoardState.render(state: BoardState, clientState: BoardState?): (FigureDict, FigureMaskDict)

	local drawingTasks = state.DrawingTasks
	if clientState then
		drawingTasks = Sift.Dictionary.merge(state.DrawingTasks, clientState.DrawingTasks)
	end
	
	local figures = table.clone(state.Figures)
	local figureMaskBundles = {}

	-- Apply all of the drawingTasks to the figures,
	-- then all of the unverified ones on top.

	for taskId, drawingTask in drawingTasks do
		
		if drawingTask.Type == "Erase" then

			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			
			for figureId, figureMask in figureIdToFigureMask do
				local bundle = figureMaskBundles[figureId] or {}
				bundle[taskId] = figureMask
				figureMaskBundles[figureId] = bundle
			end
		else
			figures[taskId] = DrawingTask.Render(drawingTask)
		end
	end

	return figures, figureMaskBundles
end

--[[
	These functions update the board state given some event.
	BoardServer and BoardClient make uses of these in the :ConnectRemotes() method.
--]]

function BoardState.InitDrawingTask(state: BoardState, authorId: string, drawingTask: DrawingTask.DrawingTask, canvasPos: Vector2)
	-- Get or create the player history for this player
	local playerHistory = state.PlayerHistories[authorId] or History.new(Config.History.Capacity)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, state, canvasPos)
	state.DrawingTasks = Dictionary.set(state.DrawingTasks, drawingTask.Id, initialisedDrawingTask)

	playerHistory:Push(initialisedDrawingTask)
	state.PlayerHistories[authorId] = playerHistory

	-- Any drawing task which doesn't appear in any player history is a candidate for committing
	local needsCommitDrawingTasks = table.clone(state.DrawingTasks)
	for _, pHistory in pairs(state.PlayerHistories) do

		for historyDrawingTask in pHistory:IterPastAndFuture() do

			needsCommitDrawingTasks[historyDrawingTask.Id] = nil

		end
	end

	for _, dTask in pairs(needsCommitDrawingTasks) do
		local canCommit

		if dTask.Type == "Erase" then
			-- Every figure being (partially) erased must be gone from DrawingTasks
			canCommit = Dictionary.every(dTask.FigureIdToMask, function(_mask, figureId)
				return state.DrawingTasks[figureId] == nil
			end)
		else
			canCommit = true
		end

		if canCommit then
			state.Figures = DrawingTask.Commit(dTask, state.Figures)
			state.DrawingTasks = Dictionary.set(state.DrawingTasks, dTask.Id, nil)
		end

		-- Drawing Tasks not committed now will be committed later when canCommitt == true

	end
end

function BoardState.UpdateDrawingTask(state: BoardState, authorId: string, canvasPos: Vector2)

	local playerHistory = state.PlayerHistories[authorId]
	if not playerHistory then
		error(`[metaboard] Tried to update drawing task of player with no history. AuthorId: {authorId}`)
	end

	local drawingTask = playerHistory:MostRecent()
	if not drawingTask then
		error(`[metaboard] Tried to update non-existent drawing task. AuthorId: {authorId}`)
	end

	local updatedDrawingTask = DrawingTask.Update(drawingTask, state, canvasPos)

	playerHistory:SetMostRecent(updatedDrawingTask)

	state.DrawingTasks = Dictionary.set(state.DrawingTasks, updatedDrawingTask.Id, updatedDrawingTask)
end

function BoardState.FinishDrawingTask(state: BoardState, authorId: string)
	
	local playerHistory = state.PlayerHistories[authorId]
	if not playerHistory then
		error(`[metaboard] Tried to finish drawing task of player with no history. AuthorId: {authorId}`)
	end

	local drawingTask = playerHistory:MostRecent()
	if not drawingTask then
		error(`[metaboard] Tried to finish non-existent drawing task. AuthorId: {authorId}`)
	end

	local finishedDrawingTask = Dictionary.set(DrawingTask.Finish(drawingTask, state), "Finished", true)

	playerHistory:SetMostRecent(finishedDrawingTask)

	state.DrawingTasks = Dictionary.set(state.DrawingTasks, finishedDrawingTask.Id, finishedDrawingTask)
end

function BoardState.Undo(state: BoardState, authorId: string)

	local playerHistory = state.PlayerHistories[authorId]
	if not playerHistory then
		error(`[metaboard] Tried to perform undo for player with no history. AuthorId: {authorId}`)
	end
	if playerHistory:CountPast() < 1 then
		error(`[metaboard] Tried to perform undo for player with empty history. AuthorId: {authorId}`)
	end
	
	local drawingTask = playerHistory:StepBackward()
	DrawingTask.Undo(drawingTask, state)
	state.DrawingTasks = Dictionary.set(state.DrawingTasks, drawingTask.Id, nil)
end

function BoardState.Redo(state: BoardState, authorId: string)
	
	local playerHistory = state.PlayerHistories[authorId]
	if not playerHistory then
		error(`[metaboard] Tried to perform redo for player with no history. AuthorId: {authorId}`)
	end
	if playerHistory:CountFuture() < 1 then
		error(`[metaboard] Tried to perform redo for player with empty history. AuthorId: {authorId}`)
	end
	
	local drawingTask = playerHistory:StepForward()
	state.DrawingTasks = Dictionary.set(state.DrawingTasks, drawingTask.Id, drawingTask)
	DrawingTask.Redo(drawingTask, state)
end

function BoardState.Clear(state: BoardState)
	
	state.PlayerHistories = {}
	state.DrawingTasks = {}
	state.Figures = {}
	state.NextFigureZIndex = 0
	state.EraseGrid = EraseGrid.new(state.AspectRatio)
	state.ClearCount = (state.ClearCount or 0) + 1
end


return BoardState