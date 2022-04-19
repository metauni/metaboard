-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Queue = require(Common.Queue)

-- JobQueue
local DelayedJobQueue = {}
DelayedJobQueue.__index = DelayedJobQueue

function DelayedJobQueue.new(delayTime)
  return setmetatable({
    _queue = Queue.new(),
		_delayTime = delayTime
  }, DelayedJobQueue)
end

function DelayedJobQueue:Enqueue(job)
  self._queue:Enqueue(coroutine.create(job))
end

function DelayedJobQueue:RunJobsUntilYield(yielder)
  while self._queue:Count() > 0 do
		local co = self._queue:PeekFront()
		task.wait(self._delayTime)
		local success, msg = coroutine.resume(co, yielder)
		if not success then
			self._queue:Dequeue()
			error(msg, 0)
		end

		if coroutine.status(co) == "suspended" then
			return
		else
			self._queue:Dequeue()
		end
	end
end

function DelayedJobQueue:Clear()
  self._queue = Queue.new()
end

return DelayedJobQueue