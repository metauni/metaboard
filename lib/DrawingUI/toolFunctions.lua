-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services

-- Imports
local root = script.Parent.Parent
local Config = require(root.Config)
local DrawingTask = require(root.DrawingTask)
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement
local Sift = require(root.Parent.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local set = Dictionary.set
local merge = Dictionary.merge


local toolDown, toolMoved, toolUp

function toolDown(self, state, canvasPos)
	-- Must finish tool drawing task before starting a new one
	if state.ToolHeld then
		state = merge(state, toolUp(self, state))
	end

	local drawingTask = state.ToolState.EquippedTool.newDrawingTask(self, state)
	
	self.props.Board.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self.props.Board, canvasPos)

	return {

		ToolHeld = true,

		SubMenu = Roact.None,

		CurrentUnverifiedDrawingTaskId = initialisedDrawingTask.Id,

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, initialisedDrawingTask.Id, initialisedDrawingTask),

	}
end

function toolMoved(self, state, canvasPos)
	if not state.ToolHeld then return end

	local drawingTask = state.UnverifiedDrawingTasks[state.CurrentUnverifiedDrawingTaskId]

	self.props.Board.Remotes.UpdateDrawingTask:FireServer(canvasPos)

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self.props.Board, canvasPos)

	return {

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, updatedDrawingTask.Id, updatedDrawingTask),

	}
end

function toolUp(self, state)
	if not state.ToolHeld then return end

	local drawingTask = state.UnverifiedDrawingTasks[state.CurrentUnverifiedDrawingTaskId]

	local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, self.props.Board), "Finished", true)

	self.props.Board.Remotes.FinishDrawingTask:FireServer()

	return {

		ToolHeld = false,

		CurrentUnverifiedDrawingTaskId = Roact.None,

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, finishedDrawingTask.Id, finishedDrawingTask),

	}

end

return {
	ToolDown = toolDown,
	ToolMoved = toolMoved,
	ToolUp = toolUp,
}