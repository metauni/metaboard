-- Services

-- Import

-- History
local History = {}
History.__index = History

function History.new(capacity)
  return setmetatable({
    _capacity = capacity,
    _next = 1,
    _ahead = 0,
    _behind = 0,
    _count = 0,
    _table = {},
  }, History)
end

local function toCycle(n, capacity)
  return ((n-1) % capacity) + 1
end

function History:Current()
  assert(self._behind > 0, "No current item in History")
  return self._table[toCycle(self._next - 1, self._capacity)]
end

function History:Push(item, pastDestructor, futureDestructor)
  if self._ahead > 0 then
    futureDestructor = futureDestructor or function(x) print("Forgetting Future: "..(tostring(x or "nil"))) end
    if futureDestructor then
      for i=1, self._ahead do
        local j = toCycle(self._next - 1 + i, self._capacity)
        futureDestructor(self._table[j])
        self._table[j] = nil
      end
    end
    self._table[self._next] = item
    self._count = self._count - self._ahead + 1
    self._ahead = 0
    self._behind += 1
    self._next = toCycle(self._next + 1, self._capacity)
  elseif self._behind < self._capacity then
    self._table[self._next] = item
    self._count += 1
    self._behind += 1
    self._next = toCycle(self._next + 1, self._capacity)
  elseif self._behind == self._capacity then
    pastDestructor = pastDestructor or function(x) print("Forgetting Past: "..(tostring(x or "nil"))) end
    if pastDestructor then
      pastDestructor(self._table[self._next])
    end
    self._table[self._next] = item
    self._next = toCycle(self._next + 1, self._capacity)
    -- count is unchanged
  else
    print(self)
    error("History._behind should not exceed History._capacity: ")
  end
end

function History:Advance()
  if self._ahead <= 0 then
    error("Nothing in the future")
  end

  self._ahead -= 1
  self._behind += 1
  local item = self._table[self._next]
  self._next = toCycle(self._next + 1, self._capacity)
  return item
end

function History:Recede()
  if self._behind <= 0 then
    error("Nothing in the past")
  end

  self._ahead += 1
  self._behind -= 1
  self._next = toCycle(self._next - 1, self._capacity)
  return self._table[self._next]
end

function History:__tostring()
  local output = "("..self._behind..","..self._next..","..self._ahead..",".."{"

  for i=1, self._capacity do
    local item = tostring(self._table[i] or "")
    
    if self._ahead > 0 and i == toCycle(self._next + self._ahead - 1, self._capacity) then
      item = item..">"
    end
    
    if self._ahead == 0 and i == self._next and self._behind ~= self._capacity then
      item = item..">"
    end
    
    if self._behind == self._capacity and toCycle(i+1, self._capacity) == self._next then
      item = item..">"
    end
    
    if self._behind > 0 and i == toCycle(self._next - self._behind, self._capacity) then
      item = "<"..item
    end

    if i == self._next then
      item = "|"..item
    end
    
    if self._behind == 0 and i == toCycle(self._next - self._behind, self._capacity) then
      item = "<"..item
    end
    
    
    output = output..item..(i == self._capacity and "" or ",")
  end

  return output.."})"
end

function History:_OldestIndex()
  return toCycle(self._next - self._behind, self._capacity)
end

function History:_YoungestIndex()
  return toCycle(self._next - 1 +  self._ahead, self._capacity)
end

function History:Count()
  return self._count
end

function History:Expand(capacity)
  assert(capacity >= self._capacity, "Cannot shrink History Capacity")

  if (self._ahead > 0 or self._behind > 0) and self:_OldestIndex() > self:_YoungestIndex() then
    for i=1, self:_YoungestIndex() do
      self._table[toCycle(self._capacity + i, capacity)] = self._table[i]
      self._table[i] = nil
      if i == self._next then
        self._next = toCycle(self._capacity + i, capacity)
      end
    end

    if self._next == self._capacity + 1 then
      self._next = toCycle(self._capacity + self._next, capacity)
    end
  end

  self._capacity = capacity
end

return History