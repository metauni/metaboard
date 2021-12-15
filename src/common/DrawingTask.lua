local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

local DrawingTask = {}
DrawingTask.__index = DrawingTask

DrawingTask.InitRemoteEvent = Common.Remotes.DrawingTaskInit
DrawingTask.UpdateRemoteEvent = Common.Remotes.DrawingTaskUpdate
DrawingTask.FinishRemoteEvent = Common.Remotes.DrawingTaskFinish

function DrawingTask.new(init, update, finish)
  return setmetatable(
    {
      State = {},
      Init = init,
      Update = update,
      Finish = finish
    }, DrawingTask)
end

return DrawingTask