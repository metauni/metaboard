local History = {}
History.__index = History

function History.Init(player)
	local playerHistory = Instance.new("Folder")
	playerHistory.Name = player.UserId

	-- The value of this thing is an ObjectValue, whose value is a TaskObject
	local MostRecent = Instance.new("ObjectValue")
	MostRecent.Name = "MostRecent"
	MostRecent.Parent = playerHistory

	-- The value of this thing is an ObjectValue, whose value is a TaskObject
	local MostImminent = Instance.new("ObjectValue")
	MostImminent.Name = "MostImminent"
	MostImminent.Parent = playerHistory

	playerHistory:SetAttribute("Size", 0)
	return playerHistory
end


function History.ForgetFuture(playerHistory, taskForgetter)
  local taskObjectValue = playerHistory.MostImminent.Value

  while taskObjectValue do
    taskForgetter(taskObjectValue.Value)
    local oldTaskObjectValue = taskObjectValue
    taskObjectValue = taskObjectValue:FindFirstChildOfClass("ObjectValue")
    oldTaskObjectValue:Destroy()
    playerHistory:SetAttribute("Size", playerHistory:GetAttribute("Size") - 1)
  end

  -- Destroying the value of this seems to not make this nil, so we do it manually
  playerHistory.MostImminent.Value = nil
end

-- Make sure to ForgetFuture before calling this function
function History.RecordTaskToHistory(playerHistory, taskObject)

	local newTaskObjectValue = Instance.new("ObjectValue")
	newTaskObjectValue.Name = taskObject.Name
	newTaskObjectValue.Value = taskObject
	newTaskObjectValue.Parent = playerHistory.MostRecent.Value or playerHistory

  playerHistory.MostRecent.Value = newTaskObjectValue

	playerHistory:SetAttribute("Size", playerHistory:GetAttribute("Size") + 1)
end

function History.ForgetFutureTask(taskObject)

end

function History.ForgetHistoryTask(taskObject)

end

function History.GetOldestTaskObjectValue(playerHistory)
  for _, child in ipairs(playerHistory:GetChildren()) do
    if child.Name ~= "MostRecent" and child.Name ~= "MostImminent" then
      return child
    end
  end

  return nil
end

return History