
--[[
	Sourced from NevermoreEngine: https://github.com/Quenty/NevermoreEngine/blob/bf9e3d66e5c31ec0dafcc1c9e4142d963d309c65/src/maid/src/Shared/Maid.lua
	
	Changelog

	14/11/23
	- Added Maid.Wrap

	17/10/23
	- Added types
	- Added Maid.cleanTask for cleaning a single task
		- Recursively cleans up tables of tasks (must have no metatable)
		- Refactored DoCleaning and __newIndex to use cleanTask

	24/10/23
	- Fixed bug not cleaning up instances
]]

--[=[
	Manages the cleaning of events and other things. Useful for
	encapsulating state and make deconstructors easy.

	See the [Five Powerful Code Patterns talk](https://developer.roblox.com/en-us/videos/5-powerful-code-patterns-behind-top-roblox-games)
	for a more in-depth look at Maids in top games.

	```lua
	local maid = Maid.new()

	maid:GiveTask(function()
		print("Cleaning up")
	end)

	maid:GiveTask(workspace.ChildAdded:Connect(print))

	-- Disconnects all events, and executes all functions
	maid:DoCleaning()
	```

	@class Maid
]=]
local Maid = {}
Maid.ClassName = "Maid"

export type Maid = typeof(setmetatable({}, Maid))
export type Task = () -> () | thread | RBXScriptConnection | {Destroy: (self: any) -> ()} | {}

--[=[
	Constructs a new Maid object

	```lua
	local maid = Maid.new()
	```

	@return Maid
]=]
function Maid.new()
	return setmetatable({
		_tasks = {}
	}, Maid)
end

--[=[
	Returns true if the class is a maid, and false otherwise.

	```lua
	print(Maid.isMaid(Maid.new())) --> true
	print(Maid.isMaid(nil)) --> false
	```

	@param value any
	@return boolean
]=]
function Maid.isMaid(v)
	return getmetatable(v) == Maid or getmetatable(v) and getmetatable(v).ClassName == Maid.ClassName
end

--[=[
	Returns Maid[key] if not part of Maid metatable

	```lua
	local maid = Maid.new()
	maid._current = Instance.new("Part")
	print(maid._current) --> Part

	maid._current = nil
	print(maid._current) --> nil
	```

	@param index any
	@return MaidTask
]=]
function Maid:__index(index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks[index]
	end
end

--[=[
	Add a task to clean up. Tasks given to a maid will be cleaned when
	maid[index] is set to a different value.

	Task cleanup is such that if the task is an event, it is disconnected.
	If it is an object, it is destroyed.

	```
	Maid[key] = (function)         Adds a task to perform
	Maid[key] = (event connection) Manages an event connection
	Maid[key] = (thread)           Manages a thread
	Maid[key] = (Maid)             Maids can act as an event connection, allowing a Maid to have other maids to clean up.
	Maid[key] = (Object)           Maids can cleanup objects with a `Destroy` method
	Maid[key] = nil                Removes a named task.
	```

	@param index any
	@param newTask MaidTask
]=]
function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		error(("Cannot use '%s' as a Maid key"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	tasks[index] = newTask

	if oldTask then
		Maid.cleanTask(oldTask)
	end
end

--[=[
	Gives a task to the maid for cleanup and returnsthe resulting value

	@param task MaidTask -- An item to clean
	@return MaidTask
]=]
function Maid:Add(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	self[#self._tasks+1] = task

	if type(task) == "table" and (not task.Destroy) then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return task
end

--[=[
	Gives a task to the maid for cleanup, but uses an incremented number as a key.

	@param task MaidTask -- An item to clean
	@return number -- taskId
]=]
function Maid:GiveTask(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks+1
	self[taskId] = task

	if type(task) == "table" and (not task.Destroy) then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

--[=[
	Gives a promise to the maid for clean.

	@param promise Promise<T>
	@return Promise<T>
]=]
function Maid:GivePromise(promise)
	if not promise:IsPending() then
		return promise
	end

	local newPromise = promise.resolved(promise)
	local id = self:GiveTask(newPromise)

	-- Ensure GC
	newPromise:Finally(function()
		self[id] = nil
	end)

	return newPromise
end

--[=[
	Cleans up all tasks and removes them as entries from the Maid.

	:::note
	Signals that are already connected are always disconnected first. After that
	any signals added during a cleaning phase will be disconnected at random times.
	:::

	:::tip
	DoCleaning() may be recursively invoked. This allows the you to ensure that
	tasks or other tasks. Each task will be executed once.

	However, adding tasks while cleaning is not generally a good idea, as if you add a
	function that adds itself, this will loop indefinitely.
	:::
]=]
function Maid:DoCleaning()
	local tasks = self._tasks

	-- Disconnect all events first as we know this is safe
	for index, job in pairs(tasks) do
		if typeof(job) == "RBXScriptConnection" then
			tasks[index] = nil
			job:Disconnect()
		end
	end

	-- Clear out tasks table completely, even if clean up tasks add more tasks to the maid
	local index, job = next(tasks)
	while job ~= nil do
		tasks[index] = nil
		Maid.cleanTask(job)
		index, job = next(tasks)
	end
end

--[=[
	Static class function that cleans up a single task given as argument.
	Can be a function, thread, event connection, instance, maid,
	a numeric-table of tasks or a table with a Destroy method.

	The key "Destroy" in a table is always assumed to point to a function or nil.
	An error will be thrown if there is a non-function stored - this is intentional.
	Do not use this key for anything other than a cleanup method.

	If the task is a table with a destroy method, that will be called, otherwise
	if it also has no metatable and only numeric keys, it is treated as a list
	of tasks, and all the values will be recursively cleaned as tasks, and the
	table will be cleared if it's not frozen.

	A table with any non-numeric keys, but no destroy method, will not be cleaned
	(nor will its values be recursively cleaned). This allows class objects to be
	cleaned only once by dropping their Destroy method after Destroy is called.
]=]
function Maid.cleanTask(job: Task, refs: {[any]:true}?)
	if type(job) == "function" then
		job()
	elseif type(job) == "thread" then
		local cancelled
		if coroutine.running() ~= job then
			cancelled = pcall(function()
				task.cancel(job)
			end)
		end

		if not cancelled then
			local toCancel = job
			task.defer(function()
				task.cancel(toCancel)
			end)
		end
	elseif typeof(job) == "RBXScriptConnection" then
		job:Disconnect()
	elseif typeof(job) == "Instance" then
		job:Destroy()
	elseif typeof(job) == "table" then
		local taskTable = job :: any

		if taskTable.Destroy then
			taskTable:Destroy()
		elseif getmetatable(taskTable) == nil then
			for key in taskTable do
				if typeof(key) ~= "number" then
					warn("[Maid] Aborted cleaning non-numeric task table - might be an already destroyed object")
					return
				end
			end
			if refs then
				if refs[job] then
					return
				end
				refs[job] = true
			else
				refs = {[job]=true}
			end
			for k, v in taskTable do
				Maid.cleanTask(v, refs)
			end
			if not table.isfrozen(job) then
				table.clear(job)
			end
		end
	end
end

--[=[
	Alias for Maid.DoCleaning()

	@function Destroy
	@within Maid
]=]
Maid.Destroy = Maid.DoCleaning

--[[
	Turns a Maid or MaidTask into a function that cleans it up.
	Usage:
	```lua
		local maid = Maid.new()
		local cleanup = maid:Wrap()
		cleanup() --> maid is cleaned
	```
]]
function Maid.Wrap(maidOrTask)
	return function()
		Maid.cleanTask(maidOrTask)
	end
end

Maid.GetDestroy = Maid.Wrap

return Maid