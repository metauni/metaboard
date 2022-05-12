-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Queue = require(Common.Queue)

-- InstantJobQueue
local InstantJobQueue = {}
InstantJobQueue.__index = InstantJobQueue

function InstantJobQueue.new()
	return setmetatable({
	}, InstantJobQueue)
end

function InstantJobQueue:Enqueue(job)
	job(function()
		-- no yield
	end)
end

function InstantJobQueue:RunJobsUntilYield()

end

function InstantJobQueue:Clear()
	self._queue = Queue.new()
end

return InstantJobQueue