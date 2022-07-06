-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local DrawingTask = require(Common.DrawingTask)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local set = Dictionary.set
local merge = Dictionary.merge


local toolDown, toolMoved, toolUp

function toolDown(self, state, canvasPos)

	-- Must finish tool drawing task before starting a new one
	if self.ToolHeld then
		state = merge(state, toolUp(self, state))
		self.ToolHeld = false
	end

	self.ToolHeld = true

	local drawingTask = self.EquippedTool.newDrawingTask(self, state)

	self.props.Board.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self.props.Board, canvasPos)

	return {

		CurrentUnverifiedDrawingTaskId = initialisedDrawingTask.Id,

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, initialisedDrawingTask.Id, initialisedDrawingTask),

	}
end

function toolMoved(self, state, canvasPos)
	if not self.ToolHeld then return end

	local drawingTask = state.UnverifiedDrawingTasks[state.CurrentUnverifiedDrawingTaskId]

	self.props.Board.Remotes.UpdateDrawingTask:FireServer(canvasPos)

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self.props.Board, canvasPos)

	return {

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, updatedDrawingTask.Id, updatedDrawingTask),

	}
end

function toolUp(self, state)
	if not self.ToolHeld then return end

	local drawingTask = state.UnverifiedDrawingTasks[state.CurrentUnverifiedDrawingTaskId]

	local finishedDrawingTask = set(DrawingTask.Finish(drawingTask, self.props.Board), "Finished", true)

	self.props.Board.Remotes.FinishDrawingTask:FireServer()

	self.ToolHeld = false

	return {

		CurrentUnverifiedDrawingTaskId = Roact.None,

		UnverifiedDrawingTasks = set(state.UnverifiedDrawingTasks, finishedDrawingTask.Id, finishedDrawingTask),

	}

end

return {
	ToolDown = toolDown,
	ToolMoved = toolMoved,
	ToolUp = toolUp,
}