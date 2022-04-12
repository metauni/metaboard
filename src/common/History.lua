-- History
local History = {}
History.__index = History

--[[ A History is an ordered collection, which can be conceptualised as two
components, a past and a future. This is implemented as a single array
with an index (self._next) which divides it into a past and a future
(it indicates the beginning of the future). Walking left from this index
travels backwards in time, and to the right travels forwards in time.
We refer to the dividing line as the present. The most recent item is
just before the present, and the most imminent is just after. There is
no concept of a present item, all items must be in the past or future.

Example: we can store the history <1,2,3|4,5>, in which 3 is the "most-recent"
item, 4 is the "most-imminent", 1 is the furthest in the past and 5 is the
furthest into the future. The vertical bar indicates the present.

The primary edit operation is `History:Push(item)`, which records the item
as occurring "next" relative to the current present in the history.
This behaves like a new branch in the timeline from the present,
and any exisiting items in the history's future are destroyed.
For example, pushing 6 to the history <1,2,3|4,5> would result in the history
<1,2,3,6|>.
If the history is full (see Capacity) and the future is empty,
the oldest item in the past will be destroyed before pushing the item
For example, if the history <1,2,3,4,5|> has capacity 5 and we push 6, the
resulting history will be <2,3,4,5,6|>.

There are two operations for adjusting the position of the present. They also
return the item which crossed between the past and the future.

History:StepForward() shifts the present one item into the future, and
returns the original most imminent item (which is now in the past).
Example: StepForward applied to <1,2,3|4,5> changes it to <1,2,3,4|5> and
returns 4.
If there are no items in the future, this operation fails.

History:StepBackward() shifts the present one item into the past, and
returns the original most recent item (which is now in the future).
Example: StepBackward applied to <1,2,3|4,5> changes it to <1,2|3,4,5> and
returns 3.
If there are no items in the past, this operation fails.

Capacity. The capacity property of the history constrains the maximum
total number of items that can be stored in the history, across the
past and future. This is maintained in the Push operation, which culls the
the oldest past-item if there is a need to make room.
There is an O(n) expand operation, which increases the capacity of the history.

Implementation. A history is a numeric table, along with values which track the
index of the first item in the history (_next), the number of items in the
past (_behind) and the number of items in the future (_ahead). In the naive
approach, you can perform Push by writing to the table at index _next and then
incrementing it, followed by destroying the item at index _next - _behind
if the History exceeds the chosen capacity. However the drawback here is that
we are needlessly "walking along the memory" and eventually storing data at
very high indices of the table, even if there are only 5 items in the History.

Bad Solution: Perform an O(n) shift to all of the items so that they fit
within 1 -> _capacity
Good Solution: Treat indexing cyclically between 1 and _capacity, so that a
history that reaches the last index continues from the first index.

For example: The history <1|2,3,4,5> with capacity 7 might be stored as
{
  _capacity = 7,
  _next = 6,
  _behind = 1,
  _ahead = 4,
  _table = {4,5,nil,nil,1,2,3}
}

equivalent histories arise by cycling the elements of the table and updating
the _next value to point to the same item.

Note that the positions of the start of the past and the end of the future
can be calculated from _next, _ahead, _behind, using modular arithmetic.
--]]

function History.new(capacity: number, itemToString)
  return setmetatable({
    _capacity = capacity,
    _next = 1,
    _behind = 0,
    _ahead = 0,
    _table = table.create(capacity, nil),
    _itemToString = itemToString or tostring,
  }, History)
end

-- We use the wrap function so that modular arithmetic can be more naturally
-- done with respect to indexing-at-one, i.e. wrap ranges from 1 to capacity.
local function wrap(n: number, capacity: number)
  return ((n-1) % capacity) + 1
end

function History:MostRecent()
  assert(self._behind > 0, "Cannot get most recent from empty past")
  return self._table[wrap(self._next - 1, self._capacity)]
end

function History:Push(item: any, pastDestructor, futureDestructor)
  if self._ahead > 0 then
    -- There are some items in the future, destroy them all first before pushing
    -- futureDestructor = futureDestructor or function(x) print("Forgetting Future: "..(tostring(x or "nil"))) end
    if futureDestructor then
      for i=1, self._ahead do
        local j = wrap(self._next - 1 + i, self._capacity)
        futureDestructor(self._table[j])
        self._table[j] = nil
      end
    end

    -- the index self._next is now available, place the item there and
    -- update relevant properties
    self._table[self._next] = item
    self._ahead = 0
    self._behind += 1
    self._next = wrap(self._next + 1, self._capacity)

  elseif self._behind < self._capacity then
    -- There is nothing in the future, and the history is not full so there
    -- is free space at self._next

    self._table[self._next] = item
    self._behind += 1
    self._next = wrap(self._next + 1, self._capacity)

  elseif self._behind == self._capacity then
    -- There is nothing in the future, and the history is full.
    -- Destroy the oldest item to make space at self._next

    -- pastDestructor = pastDestructor or function(x) print("Forgetting Past: "..(tostring(x or "nil"))) end
    if pastDestructor then
      pastDestructor(self._table[self._next])
      self._table[self._next] = nil
    end

    self._table[self._next] = item
    self._next = wrap(self._next + 1, self._capacity)
  else
    print(self)
    error("History._behind should not exceed History._capacity: ")
  end
end

function History:StepForward()
  if self._ahead <= 0 then
    error("Nothing in the future")
  end

  self._ahead -= 1
  self._behind += 1
  local item = self._table[self._next]
  self._next = wrap(self._next + 1, self._capacity)
  return item
end

function History:StepBackward()
  if self._behind <= 0 then
    error("Nothing in the past")
  end

  self._ahead += 1
  self._behind -= 1
  self._next = wrap(self._next - 1, self._capacity)
  return self._table[self._next]
end

function History:ToDebugString()
  local output = "("..self._behind..","..self._next..","..self._ahead..",".."{"

  for i=1, self._capacity do
    output = output..self._itemToString(self._table[i])..(i < self._capacity and "," or "")
  end

  return output.."})"
end

function History:ToFormattedString()
  local past = ""
  for j=1, self._behind do
    past = self._itemToString(self._table[wrap(self._next - j, self._capacity)])..(j > 1 and "," or "")..past
  end

  local future = ""
  for j=1, self._ahead do
    future = future..(j > 1 and "," or "")..self._itemToString(self._table[wrap(self._next - 1 + j, self._capacity)])
  end

  return "<"..past.."|"..future..">"
end

function History:__tostring()
  return self:ToFormattedString()
  -- return self:ToDebugString()
end

function History:_OldestIndex()
  return wrap(self._next - self._behind, self._capacity)
end

function History:_YoungestIndex()
  return wrap(self._next - 1 +  self._ahead, self._capacity)
end

function History:Count()
  return self._behind + self._ahead
end

function History:CountPast()
  return self._behind
end

function History:CountFuture()
  return self._ahead
end

function History:Expand(capacity)
  assert(capacity >= self._capacity, "Cannot shrink History Capacity")

  -- Check if the history is sitting across the start/end boundary
  -- i.e. some true-suffix of the history is a prefix of the array
  if self:Count() > 0 and self:_OldestIndex() > self:_YoungestIndex() then
    -- Recalcuate the positions of the initial segment, wrapped according to
    -- the new capacity
    for i=1, self:_YoungestIndex() do
      self._table[wrap(self._capacity + i, capacity)] = self._table[i]
      self._table[i] = nil
    end

    -- Reposition the next index, if it was attached to that relocated prefix
    if self._next <= self:_YoungestIndex() + 1 then
      self._next = wrap(self._capacity + self._next, capacity)
    end
  end

  self._capacity = capacity
end

function History:MapPrint(f)
  return 
end

return History