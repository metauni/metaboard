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


function History.ForgetFuture(playerHistory)
  local taskObjectValue = playerHistory.MostImminent.Value

  while taskObjectValue do
    taskObjectValue.Value:Destroy()
    taskObjectValue = taskObjectValue:FindFirstChildOfClass("ObjectValue")

    playerHistory:SetAttribute("Size", playerHistory:GetAttribute("Size") - 1)
  end

  if playerHistory.MostImminent.Value then
    -- Destroys this and all future object values in the chain (because they are parented to this one)
    playerHistory.MostImminent.Value:Destroy()
  end

  -- Destroying the value of this seems to not make this nil, so we do it manually
  playerHistory.MostImminent.Value = nil
end

-- Make sure to ForgetFuture before calling this function
function History.RecordTaskToHistory(playerHistory, taskObject)
	if taskObject:GetAttribute("TaskType") == "Attention" then
		return
	end

	local newTaskObjectValue = Instance.new("ObjectValue")
	newTaskObjectValue.Name = taskObject.Name
	newTaskObjectValue.Value = taskObject
	newTaskObjectValue.Parent = playerHistory.MostRecent.Value or playerHistory

  playerHistory.MostRecent.Value = newTaskObjectValue

	playerHistory:SetAttribute("Size", playerHistory:GetAttribute("Size") + 1)
end

function History.GetOldest(playerHistory)
  for _, child in ipairs(playerHistory:GetChildren()) do
    if child.Name ~= "MostRecent" and child.Name ~= "MostImminent" then
      return child
    end
  end
end

function History.ForgetOldestUntilSize(playerHistory, targetSize, committer)

  local taskObjectValue = History.GetOldest(playerHistory)
  local size = playerHistory:GetAttribute("Size")

  while taskObjectValue and size > targetSize do
    committer(taskObjectValue.Value)
    local nextTaskObjectValue = taskObjectValue:FindFirstChildOfClass("ObjectValue")

    if nextTaskObjectValue then
      nextTaskObjectValue.Parent = playerHistory
    end

    if taskObjectValue == playerHistory.MostRecent.Value then
      taskObjectValue:Destroy()
      playerHistory.MostRecent.Value = nil
      size -= 1
      break
    else
      taskObjectValue:Destroy()
      size -= 1
      taskObjectValue = nextTaskObjectValue
    end
  end

  playerHistory:SetAttribute("Size", size)
end

function History.ForgetPastAndFuture(playerHistory, committer)
  local taskObjectValue = History.GetOldest(playerHistory)

  local isPast = playerHistory.MostRecent.Value ~= nil

  while taskObjectValue do

    if isPast then
      committer(taskObjectValue.Value)
    end

    local nextTaskObjectValue = taskObjectValue:FindFirstChildOfClass("ObjectValue")
    if nextTaskObjectValue then
      nextTaskObjectValue.Parent = playerHistory
    end

    if taskObjectValue == playerHistory.MostRecent.Value then
      isPast = false
    end
    taskObjectValue:Destroy()
    taskObjectValue = nextTaskObjectValue
  end

end

return History
