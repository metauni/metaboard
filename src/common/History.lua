-- Services

-- Import

-- History
local History = {}
History.__index = History

function History.new(capacity)
  return setmetatable({
    Capacity = capacity,
    Position = 1,
    Ahead = 0,
    Behind = 0,
    _table = {},
  }, History)
end

local function normalise(n, capacity)
  return ((n-1) % capacity) + 1
end

function History:Push(item, itemDestructor)
  if self.Ahead > 0 then
    self._table[self.Position] = item
    self.Ahead -= 1
    self.Behind += 1
    self.Position = normalise(self.Position + 1, self.Capacity)
  elseif self.Behind < self.Capacity then
    self._table[self.Position] = item
    self.Behind += 1
    self.Position = normalise(self.Position + 1, self.Capacity)
  elseif self.Behind == self.Capacity then
    itemDestructor(self._table[self.Position])
    self._table[self.Position] = item
  else
    print(self)
    error("History.Behind should not exceed History.Capacity: ")
  end
end

function History:Advance()
  if self.Ahead <= 0 then
    error("Nothing in the future")
  end

  self.Ahead -= 1
  self.Behind += 1
  local item = self._table[self.Position]
  self.Position = normalise(self.Position + 1, self.Capacity)
  return item
end

function History:Recede()
  if self.Behind <= 0 then
    error("Nothing in the past")
  end

  self.Ahead += 1
  self.Behind -= 1
  self.Position = normalise(self.Position - 1, self.Capacity)
  return self._table[self.Position]
end

return History