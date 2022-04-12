-- Queue
local Queue = {}
Queue.__index = Queue


function Queue.new()
  return setmetatable({
    _front = nil,
    _back = nil,
    _count = 0,
  }, Queue)
end

function Queue:Count()
  return self._count
end

function Queue:Enqueue(item)
  if self._back == nil then
    local node = {
      _item = item,
			_behind = nil,
    }
    self._front = node
    self._back = node
    self._count = 1
  else
    local node = {
      _item = item,
			_behind = nil,
		}
		self._back._behind = node
    self._back = node
    self._count += 1
  end
end

function Queue:Dequeue()
  if self._front == nil then
    error("Queue empty")
  else
    local node = self._front
    self._front = node._behind
    if self._front == nil then
      self._back = nil
    end

    self._count -= 1
    return node._item
  end
end

function Queue:PeekFront()
  if self._front then
    return self._front._item
  else
    return nil
  end
end

return Queue