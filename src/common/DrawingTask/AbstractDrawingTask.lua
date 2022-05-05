-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

local AbstractDrawingTask = {}
AbstractDrawingTask.__index = AbstractDrawingTask

function AbstractDrawingTask.new(taskType: string, taskId: string, verified: boolean)
	return setmetatable({
		TaskType = taskType,
		TaskId = taskId,
		Verified = verified
	}, AbstractDrawingTask)
end

local function notImplemented(methodName, className)
	error(string.format("%s not implemented for drawing task '%s'\nSee AbstractDrawingTask", methodName, className))
end

function AbstractDrawingTask:Verify()
	self.Verified = true
end

function AbstractDrawingTask:Render(renderer, figureMask)
	notImplemented("Render", self.TaskType)
end

function AbstractDrawingTask:Init(pos)
	notImplemented("Init", self.TaskType)
end

function AbstractDrawingTask:Update(pos)
	notImplemented("Update", self.TaskType)
end

function AbstractDrawingTask:Finish()
	notImplemented("Finish", self.TaskType)
end

function AbstractDrawingTask:CheckCollision(eraserCentre: Vector2, eraserThicknessYScale: number, figureId: string)
	notImplemented("CheckCollision", self.TaskType)
end

return AbstractDrawingTask