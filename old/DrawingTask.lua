local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

local DrawingTask = {}
DrawingTask.__index = DrawingTask

DrawingTask.InitRemoteEvent = Common.Remotes.DrawingTaskInit
DrawingTask.UpdateRemoteEvent = Common.Remotes.DrawingTaskUpdate
DrawingTask.FinishRemoteEvent = Common.Remotes.DrawingTaskFinish

return DrawingTask