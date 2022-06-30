-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Queue = require(Common.Queue)

-- JobQueue
local JobQueue = {}
JobQueue.__index = JobQueue

function JobQueue.new()
	return setmetatable({
		_queue = Queue.new()
	}, JobQueue)
end

function JobQueue:Enqueue(job)
	self._queue:Enqueue(coroutine.create(job))
end

function JobQueue:RunJobsUntilYield(yielder)
	while self._queue:Count() > 0 do
		local co = self._queue:PeekFront()
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

function JobQueue:Clear()
	self._queue = Queue.new()
end

return JobQueue