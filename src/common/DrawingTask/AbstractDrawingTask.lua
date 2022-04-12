-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports


-- AbstractDrawingTask
local AbstractDrawingTask = {}
AbstractDrawingTask.__index = AbstractDrawingTask

-- A Drawing Task represents an interaction with the board that lasts
-- the lifetime of the tool's contact with the board.
-- Each tool should spawn an object of some DrawingTask-subclass,
-- and update the appropriate method based on the user input.

-- Example:
-- 1. User begins touch with pen/finger at pos
--    -> Make dt = DrawingTask.new(...) and call dt:Init(pos)
-- 2. User drags pen/finger to pos
--    -> Call dt:Update(pos)
-- ... repeat (2) as many times as it happens
-- n. User lifts finger at pos
--    -> Call dt:Finish(pos)

-- Any other relevant information to the drawing task, like the board, canvas,
-- author etc, should be set via an argument to the .new() method.

-- If the DrawingTask object has a .Canvas set, it is expected to update
-- the rendering of the figure defined by the drawing task. But whether or not
-- there is a canvas, it should be possible to render it once a canvas is
-- supplied via the :Render(canvas) method

-- After this live-interaction, the drawing task remains in the history of the
-- author, and :Undo()'d or :Redo'() any number of times.

-- The :Commit() method is called when the history decides that it will
-- never undo this task again, so unneeded information can be discarded

function AbstractDrawingTask.new(taskId, provisional)
  return setmetatable({
    TaskId = taskId,
    Provisional = provisional,
  }, AbstractDrawingTask)
end

function AbstractDrawingTask:RenewVerified(board)
  self.Provisional = false
end

function AbstractDrawingTask:Init(board, pos: Vector2)
  error("Init method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Update(board, pos: Vector2)
  error("Update method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Finish(board)
  error("Finish method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Render(board)
  error("Render method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Undo(board)
  error("Undo method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Redo(board)
  error("Redo method not implemented for subclass of DrawingTask")
end

function AbstractDrawingTask:Commit(board)
  error("Commit method not implemented for subclass of DrawingTask")
end

return AbstractDrawingTask