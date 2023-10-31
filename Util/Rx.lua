--[[
	Rx library adapted from https://gist.github.com/Anaminus/1f31af4e5280b9333f3f58e13840c670

	Changelog (incomplete)
	- 31/10/23
		- Added .ClassName based typing for compatibility with duplicate Util libraries
	- 23/10/23
		- Updated to use Nevermore promise library
		- add Rx.toPromise
	- ??/??/23
		- Updated to use Nevermore maid library
]]

local Maid = require(script.Parent.Maid)
local Promise = require(script.Parent.Promise)

export type Task = Maid.Task
export type Fire = (...any) -> ()
export type Fail = (...any) -> ()
export type Complete = () -> ()
export type Subscribe = (Subscriber) -> Task
export type Transformer = (Observable) -> Observable
export type Subscription = () -> ()

-- Rx is a standalone ReactiveX module ripped from Nevermore.Rx.
--
-- https://quenty.github.io/NevermoreEngine/api/Rx
local export = {}

local UNSET = newproxy()

type stateType = "pending" | "failed" | "complete" | "cancelled"

local PENDING: "pending" = "pending"
local FAILED: "failed" = "failed"
local COMPLETE: "complete" = "complete"
local CANCELLED: "cancelled" = "cancelled"

-- Clean up task belonging to subscriber.
local function doCleanup(self: _Subscriber)
	if self._cleanupTask then
		local job = self._cleanupTask
		self._cleanupTask = nil
		Maid.cleanTask(job)
	end
end

export type Subscriber = {
	Fire: (self: Subscriber, ...any) -> (),
	Fail: (self: Subscriber, ...any) -> (),
	Complete: (self: Subscriber) -> (),
	GetFireFailComplete: (self: Subscriber) -> (Fire, Fail, Complete),
	GetFailComplete: (self: Subscriber) -> (Fail, Complete),
	IsPending: (self: Subscriber) -> boolean,
}

type _Subscriber = Subscriber & {
	_state: stateType,
	_fireCallback: Fire,
	_failCallback: Fail,
	_completeCallback: Complete,
	_cleanupTask: Task?,
}

local Subscriber = {__index={}}

function newSubscriber(fire: Fire?, fail: Fail?, complete: Complete?): Subscriber
	local subscriber = setmetatable({
		_state = PENDING,
		_fireCallback = fire,
		_failCallback = fail,
		_completeCallback = complete,
		_cleanupTask = nil,
	}, Subscriber)
	return subscriber
end

function Subscriber.__index:Fire(...: any)
	if self._state == PENDING then
		if self._fireCallback then
			self._fireCallback(...)
		end
	elseif self._state == CANCELLED then
		warn("Subscriber.Fire: event pushed to cancelled subscriber")
	end
end

function Subscriber.__index:Fail(...: any)
	if self._state ~= PENDING then
		return
	end

	self._state = FAILED

	if self._failCallback then
		self._failCallback(...)
	end

	doCleanup(self)
end

function Subscriber.__index:GetFireFailComplete(): (Fire, Fail, Complete)
	return function(...)
		self:Fire(...)
	end, function(...)
		self:Fail(...)
	end, function()
		self:Complete()
	end
end

function Subscriber.__index:GetFailComplete(): (Fail, Complete)
	return function(...)
		self:Fail(...)
	end, function()
		self:Complete()
	end
end

function Subscriber.__index:Complete()
	if self._state ~= PENDING then
		return
	end

	self._state = COMPLETE
	if self._completeCallback then
		self._completeCallback()
	end

	doCleanup(self)
end

function Subscriber.__index:IsPending(): boolean
	return self._state == PENDING
end

export type Observable = {
	Pipe: (self: Observable, transformers: {Transformer}) -> Observable,
	Subscribe: (self: Observable,
		onFire: Fire?,
		onFail: Fail?,
		onComplete: Complete?
	) -> Subscription,
}

local Observable = {__index={}}
Observable.ClassName = "Observable"

function isObservable(v: any): boolean
	-- Duck typing yeehaw
	return getmetatable(v) == Observable
		or (getmetatable(v) and getmetatable(v).ClassName == Observable.ClassName)
end
export.isObservable = isObservable

local function newObservable(onSubscribe: Subscribe): Observable
	assert(type(onSubscribe) == "function", "onSubscribe must be function")
	local self = setmetatable({
		_onSubscribe = onSubscribe,
	}, Observable)
	return self
end
export.observable = newObservable

function Observable.__index:Pipe(transformers: {Transformer}): Observable
	assert(type(transformers) == "table", "transformers must be a table")

	local current = self
	for _, transformer in pairs(transformers) do
		assert(type(transformer) == "function", "transformer must be function")
		current = transformer(current)
		assert(isObservable(current))
	end

	return current
end

function Observable.__index:Subscribe(fire: Fire?, fail: Fail?, complete: Complete?): Subscription
	local sub = newSubscriber(fire, fail, complete)
	local task = self._onSubscribe(sub)

	local function subscription()
		if sub._state == PENDING then
			sub._state = CANCELLED
		end
		doCleanup(sub)
	end

	if not task then
		return subscription
	end
	if sub._state ~= PENDING then
		subscription()
		return subscription
	end
	sub._cleanupTask = task
	return subscription
end

--[=[
	An empty observable that completes immediately
	@prop EMPTY Observable<()>
	@readonly
	@within Rx
]=]

--[=[
	An observable that never completes.
	@prop NEVER Observable<()>
	@readonly
	@within Rx
]=]
export.empty = newObservable(function(sub)
	sub:Complete()
end)
export.never = newObservable(function()end)

--[=[
	Pipes the tranformers through each other
	https://rxjs-dev.firebaseapp.com/api/index/function/pipe

	@param transformers { Observable<any> }
	@return (source: Observable<T>) -> Observable<U>
]=]
function export.pipe(transformers: {Transformer}): Transformer
	assert(type(transformers) == "table", "transformers must be a table")
	for index, transformer in transformers do
		if type(transformer) ~= "function" then
			error(string.format("bad transformer %s: function expected, got %s", tostring(index), typeof(transformer)), 2)
		end
	end

	return function(source: Observable): Observable
		assert(source, "Bad source")

		local current = source
		for key, transformer in transformers do
			current = transformer(current)

			if not isObservable(current) then
				error(string.format("bad result from transformer %s: Observable expected, got %q", tostring(key), tostring(current)), 2)
			end
		end

		return current
	end
end

--[=[
	http://reactivex.io/documentation/operators/just.html

	```lua
	Rx.of(1, 2, 3):Subscribe(print, function()
		print("Complete")
	end)) --> 1, 2, 3, "Complete"
	```

	@param ... any -- Arguments to emit
	@return Observable
]=]
function export.of(...: any): Observable
	local args = table.pack(...)

	return newObservable(function(sub)
		for i = 1, args.n do
			sub:Fire(args[i])
		end

		sub:Complete()
	end)
end

--[=[
	Converts an item
	http://reactivex.io/documentation/operators/from.html

	@param item Promise | table
	@return Observable
]=]
function export.from(item: {any}): Observable
	if Promise.isPromise(item) then
		return export.fromPromise(item)
	elseif type(item) == "table" then
		return export.of(table.unpack(item))
	else
		-- TODO: Iterator?
		error("[Rx.from] - cannot convert")
	end
end

--[=[
	Converts a Signal into an observable.
	https://rxjs-dev.firebaseapp.com/api/index/function/fromEvent

	@param event Signal<T>
	@return Observable<T>
]=]
function export.fromSignal(event: RBXScriptSignal): Observable
	return newObservable(function(sub)
		-- This stream never completes or fails!
		return event:Connect(function(...)
			sub:Fire(...)
		end)
	end)
end

--[=[
	Converts a Promise into an observable.
	https://rxjs-dev.firebaseapp.com/api/index/function/from

	@param promise Promise<T>
	@return Observable<T>
]=]
function export.fromPromise(promise)
	assert(Promise.isPromise(promise), "Bad promise")

	return newObservable(function(sub)
		if promise:IsFulfilled() then
			sub:Fire(promise:Wait())
			sub:Complete()
			return nil
		end

		local maid = Maid.new()

		local pending = true
		maid:GiveTask(function()
			pending = false
		end)

		promise:Then(
			function(...)
				if pending then
					sub:Fire(...)
					sub:Complete()
				end
			end,
			function(...)
				if pending then
					sub:Fail(...)
					sub:Complete()
				end
			end)

		return maid
	end)
end

--[=[
	Converts an observable to a promise that will either resolve with the
	first emitted value, or reject on complete or fail.
	Does not have cancelToken functionality.
	@param observable Observable<T>
	@return Promise<T>
]=]
function export.toPromise(observable)
	local maid = Maid.new()

	local promise = Promise.new(function(resolve, reject)
		maid:GiveTask(observable:Subscribe(resolve, reject, reject))
	end)

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

--[=[
	https://rxjs-dev.firebaseapp.com/api/operators/merge

	@param observables { Observable }
	@return Observable
]=]
function export.merge(observables: {Observable}): Observable
	assert(type(observables) == "table", "observables must be array of Obserable values")

	for _, item in pairs(observables) do
		assert(isObservable(item), "Observable expected")
	end

	return newObservable(function(sub)
		local maid = {}
		for _, observable in pairs(observables) do
			table.insert(maid, observable:Subscribe(sub:GetFireFailComplete()))
		end
		return maid
	end)
end

--[=[
	Taps into the observable and executes the onFire/onFail/onComplete
	commands.

	https://rxjs-dev.firebaseapp.com/api/operators/tap

	@param onFire function?
	@param onFail function?
	@param onComplete function?
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.tap(onFire: Fire?, onFail: Fail?, onComplete: Complete?): Transformer
	assert(type(onFire) == "function" or onFire == nil, "onFire must be function or nil")
	assert(type(onFail) == "function" or onFail == nil, "onFail must be function or nil")
	assert(type(onComplete) == "function" or onComplete == nil, "onComplete must be function or nil")

	return function(source: Observable): Observable
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(
				function(...)
					if onFire then
						onFire(...)
					end
					if sub:IsPending() then
						sub:Fire(...)
					end
				end,
				function(...)
					if onFail then
						onFail(...)
					end
					sub:Fail(...)
				end,
				function()
					if onComplete then
						onComplete()
					end
					sub:Complete()
				end)
		end)
	end
end

--[=[
	Starts the observable with the given value from the callback

	http://reactivex.io/documentation/operators/start.html

	@param callback function
	@return (source: Observable) -> Observable
]=]
function export.start(callback: () -> any): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			sub:Fire(callback())

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Returns a new Observable that multicasts (shares) the original Observable. As long as there is at least one Subscriber this Observable will be subscribed and emitting data.
	When all subscribers have unsubscribed it will unsubscribe from the source Observable.

	https://rxjs.dev/api/operators/share

	@return (source: Observable) -> Observable
]=]
function export.share(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		local _currentSub: Subscription? = nil
		local subs = {}

		local lastFail = UNSET
		local lastComplete = UNSET

		local function connectToSourceIfNeeded()
			if not _currentSub then
				lastFail = UNSET
				lastComplete = UNSET

				_currentSub = source:Subscribe(function(...)
					for _, sub in pairs(subs) do
						sub:Fire(...)
					end
				end, function(...)
					lastFail = table.pack(...)
					for _, sub in pairs(subs) do
						sub:Fail(...)
					end
				end, function(...)
					lastComplete = table.pack(...)
					for _, sub in pairs(subs) do
						sub:Complete(...)
					end
				end)
			end
		end

		local function disconnectFromSource()
			if _currentSub then
				_currentSub()
				_currentSub = nil
			end

			lastFail = UNSET
			lastComplete = UNSET
		end

		return newObservable(function(sub)
			if lastFail ~= UNSET then
				sub:Fail(table.unpack(lastFail, 1, lastFail.n))
				return
			end

			if lastComplete ~= UNSET then
				sub:Fail(table.unpack(lastComplete, 1, lastComplete.n))
				return
			end

			table.insert(subs, sub)
			connectToSourceIfNeeded()

			return function()
				local index = table.find(subs, sub)
				if index then
					table.remove(subs, index)

					if #subs == 0 then
						disconnectFromSource()
					end
				end
			end
		end)
	end
end

--[=[
	Same as [Rx.share] except it also replays the value

	@param bufferSize number -- Number of entries to cache
	@param windowTimeSeconds number -- Time
	@return (source: Observable) -> Observable
]=]
function export.shareReplay(bufferSize: number?, windowTimeSeconds: number?): Transformer
	assert(type(bufferSize) == "number" or bufferSize == nil, "bufferSize must be number or nil")
	assert(type(windowTimeSeconds) == "number" or windowTimeSeconds == nil, "windowTimeSeconds must be number or nil")

	bufferSize = bufferSize or math.huge
	windowTimeSeconds = windowTimeSeconds or math.huge

	return function(source)
		assert(isObservable(source), "source must be Observable")

		local _currentSub: Subscription? = nil
		local subs = {}

		local buffer = {}
		local lastFail = UNSET
		local lastComplete = UNSET

		local function getEventsCopy()
			local now = os.clock()
			local events = {}

			for _, event in pairs(buffer) do
				if (now - event.timestamp) <= windowTimeSeconds then
					table.insert(events, event)
				end
			end

			return events
		end

		local function connectToSourceIfNeeded()
			if not _currentSub then
				buffer = {}
				lastFail = UNSET
				lastComplete = UNSET

				_currentSub = source:Subscribe(function(...)
					-- TODO: also prune events by timestamp

					if #buffer + 1 > bufferSize then
						table.remove(buffer, 1) -- O(n), not great.
					end

					-- Queue before we start
					local event = table.pack(...)
					event.timestamp = os.clock()
					table.insert(buffer, event)

					for _, sub in pairs(subs) do
						sub:Fire(...)
					end
				end, function(...)
					lastFail = table.pack(...)
					for _, sub in pairs(subs) do
						sub:Fail(...)
					end
				end, function(...)
					lastComplete = table.pack(...)
					for _, sub in pairs(subs) do
						sub:Complete(...)
					end
				end)
			end
		end

		local function disconnectFromSource()
			if _currentSub then
				_currentSub()
				_currentSub = nil
			end

			buffer = {}
			lastFail = UNSET
			lastComplete = UNSET
		end

		return newObservable(function(sub)
			if lastFail ~= UNSET then
				sub:Fail(table.unpack(lastFail, 1, lastFail.n))
				return
			end

			if lastComplete ~= UNSET then
				sub:Fail(table.unpack(lastComplete, 1, lastComplete.n))
				return
			end

			table.insert(subs, sub)

			-- Firing could lead to re-entrance. Lets just use the buffer as-is.
			for _, item in pairs(getEventsCopy()) do
				sub:Fire(table.unpack(item, 1, item.n))
			end

			connectToSourceIfNeeded()

			return function()
				local index = table.find(subs, sub)
				if index then
					table.remove(subs, index)

					if #subs == 0 then
						disconnectFromSource()
					end
				end
			end
		end)
	end
end

--[=[
	Caches the current value

	@return (source: Observable) -> Observable
]=]
function export.cache(): Transformer
	return export.shareReplay(1)
end

--[=[
	Like start, but also from (list!)

	@param callback () -> { T }
	@return (source: Observable) -> Observable
]=]
function export.startFrom(callback: () -> {any}): Transformer
	assert(type(callback) == "function", "callback must be function")
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			for _, value in pairs(callback()) do
				sub:Fire(value)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Starts with the given values
	https://rxjs-dev.firebaseapp.com/api/operators/startWith

	@param values { T }
	@return (source: Observable) -> Observable
]=]
function export.startWith(values: {any}): Transformer
	assert(type(values) == "table", "values must be array of values")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			for _, item in pairs(values) do
				sub:Fire(item)
			end

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
end

--[=[
	Defaults the observable to a value if it isn't fired immediately

	```lua
	Rx.NEVER:Pipe({
		Rx.defaultsTo("Hello")
	}):Subscribe(print) --> Hello
	```

	@param value any
	@return (source: Observable) -> Observable
]=]
function export.defaultsTo(value: any): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local fired = false

			local subscription = source:Subscribe(
				function(...)
					fired = true
					sub:Fire(...)
				end,
				sub:GetFailComplete())

			if not fired then
				sub:Fire(value)
			end

			return subscription
		end)
	end
end

--[=[
	Defaults the observable value to nil

	```lua
	Rx.NEVER:Pipe({
		Rx.defaultsToNil
	}):Subscribe(print) --> nil
	```

	Great for defaulting Roblox attributes and objects

	@function defaultsToNil
	@param source Observable
	@return Observable
	@within Rx
]=]
export.defaultsToNil = export.defaultsTo(nil)

--[=[
	Ends the observable with these values before cancellation
	https://www.learnrxjs.io/learn-rxjs/operators/combination/endwith

	@param values { T }
	@return (source: Observable) -> Observable
]=]
function export.endWith(values: {any}): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(
				function(...)
					sub:Fire(...)
				end,
				function(...)
					for _, item in pairs(values) do
						sub:Fire(item)
					end
					sub:Fail(...)
				end,
				function()
					for _, item in pairs(values) do
						sub:Fire(item)
					end
					sub:Complete()
				end)
		end)
	end
end

export type Predicate = (...any) -> boolean

--[=[
	http://reactivex.io/documentation/operators/filter.html

	Filters out values

	```lua
	Rx.of(1, 2, 3, 4, 5):Pipe({
		Rx.where(function(value)
			return value % 2 == 0
		end)
	}):Subscribe(print) --> 2, 4
	```
	@param predicate (value: T) -> boolean
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.where(predicate: Predicate): Transformer
	assert(type(predicate) == "function", "predicate must be function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(
				function(...)
					if predicate(...) then
						sub:Fire(...)
					end
				end,
				sub:GetFailComplete()
			)
		end)
	end
end

-- Return values if they satisfy predicate. Return defaults otherwise.
function export.whereElse(predicate: Predicate, ...: any): Transformer
	assert(type(predicate) == "function", "predicate must be function")
	local args = table.pack(...)
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(
				function(...)
					if predicate(...) then
						sub:Fire(...)
					else
						sub:Fire(table.unpack(args, 1, args.n))
					end
				end,
				sub:GetFailComplete()
			)
		end)
	end
end

--[=[
	Only takes distinct values from the observable stream.

	http://reactivex.io/documentation/operators/distinct.html

	```lua
	Rx.of(1, 1, 2, 3, 3, 1):Pipe({
		Rx.distinct()
	}):Subscribe(print) --> 1, 2, 3, 1
	```
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.distinct(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local last = UNSET

			return source:Subscribe(
				function(value)
					-- TODO: Support tuples
					if last == value then
						return
					end

					last = value
					sub:Fire(last)
				end,
				sub:GetFailComplete()
			)
		end)
	end
end

--[=[
	https://rxjs.dev/api/operators/mapTo
	@param ... any -- The value to map each source value to.
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.mapTo(...: any): Transformer
	local args = table.pack(...)
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(function()
				sub:Fire(table.unpack(args, 1, args.n))
			end, sub:GetFailComplete())
		end)
	end
end

export type Project = (...any) -> (...any)

--[=[
	http://reactivex.io/documentation/operators/map.html

	Maps one value to another

	```lua
	Rx.of(1, 2, 3, 4, 5):Pipe({
		Rx.map(function(x)
			return x + 1
		end)
	}):Subscribe(print) -> 2, 3, 4, 5, 6
	```

	@param project (T) -> U
	@return (source: Observable<T>) -> Observable<U>
]=]
function export.map(project: Project): Transformer
	assert(type(project) == "function", "project must be function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return source:Subscribe(function(...)
				sub:Fire(project(...))
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Merges higher order observables together.

	Basically, if you have an observable that is emitting an observable,
	this subscribes to each emitted observable and combines them into a
	single observable.

	```lua
	Rx.of(Rx.of(1, 2, 3), Rx.of(4))
		:Pipe({
			Rx.mergeAll()
		})
		:Subscribe(print) -> 1, 2, 3, 4
	```

	@return (source: Observable<Observable<T>>) -> Observable<T>
]=]
function export.mergeAll(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = Maid.new()

			local pendingCount = 0
			local topComplete = false

			maid:GiveTask(source:Subscribe(
				function(observable)
					assert(isObservable(observable), "Observable expected")

					pendingCount = pendingCount + 1

					local subscription
					subscription = observable:Subscribe(
						function(...)
							-- Merge each inner observable
							sub:Fire(...)
						end,
						function(...)
							-- Emit failure automatically
							sub:Fail(...)
						end,
						function()
							maid[subscription] = nil
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								sub:Complete()
								maid:Destroy()
							end
						end)
					maid[subscription] = subscription
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					maid:Destroy()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						sub:Complete()
						maid:Destroy()
					end
				end)
			)

			return maid
		end)
	end
end

--[=[
	Merges higher order observables together

	https://rxjs.dev/api/operators/switchAll

	Works like mergeAll, where you subscribe to an observable which is
	emitting observables. However, when another observable is emitted it
	disconnects from the other observable and subscribes to that one.

	@return (source: Observable<Observable<T>>) -> Observable<T>
]=]
function export.switchAll(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local outerMaid = Maid.new()
			local topComplete = false
			local insideComplete = false
			local currentInside = nil

			outerMaid:GiveTask(function()
				-- Ensure inner subscription is disconnected first. This prevents
				-- the inner sub from firing while the outer is subscribed,
				-- throwing a warning.
				outerMaid._innerSub = nil
				outerMaid._outerSuber = nil
			end)

			outerMaid._outerSuber = source:Subscribe(
				function(observable)
					assert(isObservable(observable), "Observable expected")

					insideComplete = false
					currentInside = observable
					outerMaid._innerSub = observable:Subscribe(
						function(...)
							sub:Fire(...)
						end, -- Merge each inner observable
						function(...)
							if currentInside == observable then
								sub:Fail(...)
							end
						end, -- Emit failure automatically
						function()
							if currentInside == observable then
								insideComplete = true
								if insideComplete and topComplete then
									sub:Complete()
									outerMaid:Destroy() -- Paranoid ensure cleanup.
								end
							end
						end)
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					outerMaid:Destroy()
				end,
				function()
					topComplete = true
					if insideComplete and topComplete then
						sub:Complete()
						outerMaid:Destroy() -- Paranoid ensure cleanup
					end
				end)

			return outerMaid
		end)
	end
end

--[=[
	Sort of equivalent of promise.then()

	This takes a stream of observables

	@param project (value: T) -> Observable<U>
	@param resultSelector ((initialValue: T, outputValue: U) -> U)?
	@return (source: Observable<T>) -> Observable<U>
]=]
function export.flatMap(project: (any) -> Observable, resultSelector: ((any, any) -> any)?): Transformer
	assert(type(project) == "function", "project must be function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = Maid.new()

			local pendingCount = 0
			local topComplete = false

			maid:GiveTask(source:Subscribe(
				function(...)
					local outerValue = ...

					local observable = project(...)
					assert(isObservable(observable), "project must return Observable")

					pendingCount = pendingCount + 1

					local innerMaid = Maid.new()

					innerMaid:GiveTask(observable:Subscribe(
						function(...)
							-- Merge each inner observable
							if resultSelector then
								sub:Fire(resultSelector(outerValue, ...))
							else
								sub:Fire(...)
							end
						end,
						function(...)
							sub:Fail(...)
						end, -- Emit failure automatically
						function()
							innerMaid:Destroy()
							pendingCount = pendingCount - 1
							if pendingCount == 0 and topComplete then
								sub:Complete()
								maid:Destroy()
							end
						end)
					)

					maid:GiveTask(innerMaid)
				end,
				function(...)
					sub:Fail(...) -- Also reflect failures up to the top!
					maid:Destroy()
				end,
				function()
					topComplete = true
					if pendingCount == 0 then
						sub:Complete()
						maid:Destroy()
					end
				end)
			)

			return maid
		end)
	end
end

function export.switchMap(project: Project): Transformer
	return export.pipe({
		export.map(project),
		export.switchAll(),
	})
end

function export.takeUntil(notifier: Observable): Transformer
	assert(isObservable(notifier))

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = Maid.new()
			local cancelled = false

			local function cancel()
				maid:Destroy()
				cancelled = true
			end

			-- Any value emitted will cancel (complete without any values allows all values to pass)
			maid:GiveTask(notifier:Subscribe(cancel, cancel, nil))

			-- Cancelled immediately? Oh boy.
			if cancelled then
				maid:Destroy()
				return nil
			end

			-- Subscribe!
			maid:GiveTask(source:Subscribe(sub:GetFireFailComplete()))

			return maid
		end)
	end
end

--[=[
	Returns an observable that takes in a tuple, and emits that tuple, then
	completes.

	```lua
	Rx.packed("a", "b")
		:Subscribe(function(first, second)
			print(first, second) --> a, b
		end)
	```

	@param ... any
	@return Observable
]=]
function export.packed(...: {any}): Observable
	local args = table.pack(...)

	return newObservable(function(sub)
		sub:Fire(table.unpack(args, 1, args.n))
		sub:Complete()
	end)
end

--[=[
	Unpacks the observables value if a table is received
	@param observable Observable<{T}>
	@return Observable<T>
]=]
function export.unpacked(observable: Observable, i: number?, j: number?): Observable
	assert(isObservable(observable), "observable must be Observable")

	return newObservable(function(sub)
		return observable:Subscribe(function(value)
			if type(value) == "table" then
				sub:Fire(table.unpack(value, i or 1, j or #value))
			else
				warn(string.format("Observable result: table expected, got %s", typeof(value)))
			end
		end, sub:GetFailComplete())
	end)
end

--[=[
	Acts as a finalizer callback once the subscription is unsubscribed.

	```lua
		Rx.of("a", "b"):Pipe({
			Rx.finalize(function()
				print("Subscription done!")
			end)
		})
	```

	http://reactivex.io/documentation/operators/do.html
	https://rxjs-dev.firebaseapp.com/api/operators/finalize
	https://github.com/ReactiveX/rxjs/blob/master/src/internal/operators/finalize.ts

	@param finalizerCallback () -> ()
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.finalize(finalizerCallback: () -> ()): Transformer
	assert(type(finalizerCallback) == "function", "finalizerCallback must be function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			return {
				source:Subscribe(sub:GetFireFailComplete()),
				finalizerCallback,
			}
		end)
	end
end

--[=[
	Given an observable that emits observables, emit an
	observable that once the initial observable completes,
	the latest values of each emitted observable will be
	combined into an array that will be emitted.

	https://rxjs.dev/api/operators/combineLatestAll

	@return (source: Observable<Observable<T>>) -> Observable<{ T }>
]=]
function export.combineLatestAll(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local observables = {}
			local alive = true
			local maid = {}

			table.insert(maid, function()
				alive = false
			end)
			table.insert(maid, source:Subscribe(
				function(value)
					assert(isObservable(value))
					table.insert(observables, value)
				end,
				function(...)
					sub:Fail(...)
				end,
				function()
					if not alive then
						return
					end
					table.insert(maid, export.combineLatest(observables):Subscribe(sub:GetFireFailComplete()))
				end
			))

			return maid
		end)
	end
end

--[=[
	The same as combineLatestAll.

	This is for backwards compatability, and is deprecated.

	@function combineAll
	@deprecated 1.0.0 -- Use Rx.combineLatestAll
	@within Rx
	@return (source: Observable<Observable<T>>) -> Observable<{ T }>
]=]
export.combineAll = export.combineLatestAll

--[=[
	Catches an error, and allows another observable to be subscribed
	in terms of handling the error.

	:::warning
	This method is not yet tested
	:::

	@param callback (error: TError) -> Observable<TErrorResult>
	@return (source: Observable<T>) -> Observable<T | TErrorResult>
]=]
function export.catchError(callback: (...any) -> Observable): Transformer
	assert(type(callback) == "function", "callback must be a function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = {}

			-- Yikes, let's hope event ordering is good
			local alive = true
			table.insert(maid, function() alive = false end)
			table.insert(maid, source:Subscribe(
				function(...)
					sub:Fire(...)
				end,
				function(...)
					if not alive then
						-- if we failed because maid was cancelled, then we'll get called here?
						-- I think.
						return
					end

					-- at this point, we can only have one error, so we need to subscribe to the result
					-- and continue the observiable
					local observable = callback(...)
					assert(isObservable(observable), "callback must return Observable")

					table.insert(maid, observable:Subscribe(sub:GetFireFailComplete()))
				end,
				function()
					sub:Complete()
				end
			))

			return maid
		end)
	end
end

--[=[
	One of the most useful functions this combines the latest values of
	observables at each chance!

	```lua
	Rx.combineLatest({
		child = Rx.fromSignal(Workspace.ChildAdded),
		lastChildRemoved = Rx.fromSignal(Workspace.ChildRemoved),
		value = 5,

	}):Subscribe(function(data)
		print(data.child) --> last child
		print(data.lastChildRemoved) --> other value
		print(data.value) --> 5
	end)

	```

	:::tip
	Note that the resulting observable will not emit until all input
	observables are emitted.
	:::

	@param observables { [TKey]: Observable<TEmitted> | TEmitted }
	@return Observable<{ [TKey]: TEmitted }>
]=]
function export.combineLatest(observables: {[any]: Observable}): Observable
	assert(type(observables) == "table", "observables must be a dictionary")

	return newObservable(function(sub)
		local pending = 0

		local latest = {}
		for key, value in pairs(observables) do
			if isObservable(value) then
				pending = pending + 1
				latest[key] = UNSET
			else
				latest[key] = value
			end
		end

		if pending == 0 then
			sub:Fire(latest)
			sub:Complete()
			return
		end

		local maid = {}

		local function fireIfAllSet()
			for _, value in pairs(latest) do
				if value == UNSET then
					return
				end
			end

			sub:Fire(table.clone(latest))
		end

		for key, observer in pairs(observables) do
			if isObservable(observer) then
				table.insert(maid, observer:Subscribe(
					function(value)
						latest[key] = value
						fireIfAllSet()
					end,
					function(...)
						pending = pending - 1
						sub:Fail(...)
					end,
					function()
						pending = pending - 1
						if pending == 0 then
							sub:Complete()
						end
					end)
				)
			end
		end

		return maid
	end)
end

--[=[
	http://reactivex.io/documentation/operators/using.html

	Each time a subscription occurs, the resource is constructed
	and exists for the lifetime of the observation. The observableFactory
	uses the resource for subscription.

	:::note
	Note from Quenty: I haven't found this that useful.
	:::

	@param resourceFactory () -> MaidTask
	@param observableFactory (MaidTask) -> Observable<T>
	@return Observable<T>
]=]
function export.using(resourceFactory: () -> Task, observableFactory: (Task) -> Observable): Observable
	return newObservable(function(sub)
		local maid = {}

		local resource = resourceFactory()
		table.insert(maid, resource)

		local observable = observableFactory(resource)
		assert(isObservable(observable), "factory must return Observable")

		table.insert(maid, observable:Subscribe(sub:GetFireFailComplete()))

		return maid
	end)
end

--[=[
	Takes the first entry and terminates the observable. Equivalent to the following:

	```lua
	Rx.take(1)
	```

	https://reactivex.io/documentation/operators/first.html
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.first(): Transformer
	return export.take(1)
end

--[=[
	Takes n entries and then completes the observation.

	https://rxjs.dev/api/operators/take
	@param number number
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.take(number: number): Transformer
	assert(type(number) == "number", "number must be number")
	assert(number > 0, "Bad number")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local taken = 0

			return source:Subscribe(function(...)
				if taken >= number then
					warn("Rx.take: still getting values past subscription")
					return
				end

				taken = taken + 1
				sub:Fire(...)

				if taken >= number then
					sub:Complete()
				end
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Takes n entries and then completes the observation.

	https://rxjs.dev/api/operators/take
	@param toSkip number
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.skip(toSkip: number): Transformer
	assert(type(toSkip) == "number", "toSkip must be number")
	assert(toSkip > 0, "toSkip must be greater than 0")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local skipped = 0
			return source:Subscribe(function(...)
				if skipped < toSkip then
					skipped = skipped + 1
					return
				end

				sub:Fire(...)
			end, sub:GetFailComplete())
		end)
	end
end

--[=[
	Defers the subscription and creation of the observable until the
	actual subscription of the observable.

	https://rxjs-dev.firebaseapp.com/api/index/function/defer
	https://netbasal.com/getting-to-know-the-defer-observable-in-rxjs-a16f092d8c09

	@param observableFactory () -> Observable<T>
	@return Observable<T>
]=]
function export.defer(observableFactory: () -> Observable): Observable
	return newObservable(function(sub)
		local observable
		local ok, err = pcall(function()
			observable = observableFactory()
		end)

		if not ok then
			sub:Fail(err)
			return
		end

		if not isObservable(observable) then
			sub:Fail("Observable expected")
			return
		end

		return observable:Subscribe(sub:GetFireFailComplete())
	end)
end

--[=[
	Shift the emissions from an Observable forward in time by a particular amount.

	@param seconds number
	@return (source: Observable<T>) -> Observable<T>
]=]
function export.delay(seconds: number): Transformer
	assert(type(seconds) == "number", "seconds must be number")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = Maid.new()

			maid:GiveTask(source:Subscribe(function(...)
				local args = table.pack(...)

				maid[args] = task.delay(seconds, function()
					maid[args] = nil
					sub:Fire(table.unpack(args, 1, args.n))
				end)
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	Emits output every `n` seconds

	@param initialDelaySeconds number
	@param seconds number
	@return (source: Observable<number>) -> Observable<number>
]=]
function export.timer(initialDelaySeconds: number?, seconds: number): Observable
	assert(type(initialDelaySeconds) == "number" or initialDelaySeconds == nil, "initialDelaySeconds must be number or nil")
	assert(type(seconds) == "number", "seconds must be number")

	return newObservable(function(sub)
		local number = -1
		local running = true

		local function intervalLoop()
			while running do
				number += 1
				sub:Fire(number)
				task.wait(seconds)
			end
		end

		task.spawn(function()
			if initialDelaySeconds and initialDelaySeconds > 0 then
				task.wait(initialDelaySeconds)
			end
			intervalLoop()
		end)

		return function()
			running = false
		end
	end)
end


--[=[
	Honestly, I have not used this one much.

	https://rxjs-dev.firebaseapp.com/api/operators/withLatestFrom
	https://medium.com/js-in-action/rxjs-nosy-combinelatest-vs-selfish-withlatestfrom-a957e1af42bf

	@param inputObservables {Observable<TInput>}
	@return (source: Observable<T>) -> Observable<{T, ...TInput}>
]=]
function export.withLatestFrom(inputObservables: {Observable}): Transformer
	assert(type(inputObservables) == "table", "inputObservables must be array of Observable values")

	for _, observable in pairs(inputObservables) do
		assert(isObservable(observable), "observable expected")
	end

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = {}

			local latest = {}

			for key, observable in pairs(inputObservables) do
				latest[key] = UNSET

				table.insert(maid, observable:Subscribe(function(value)
					latest[key] = value
				end, nil, nil))
			end

			table.insert(maid, source:Subscribe(function(value)
				for _, item in pairs(latest) do
					if item == UNSET then
						return
					end
				end

				sub:Fire({value, unpack(latest)})
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--[=[
	https://rxjs-dev.firebaseapp.com/api/operators/scan

	@param accumulator (current: TSeed, ...: TInput) -> TResult
	@param seed TSeed
	@return (source: Observable<TInput>) -> Observable<TResult>
]=]
function export.scan(accumulator: (any, ...any) -> any, seed: any): Transformer
	assert(type(accumulator) == "function", "accumulator must be function")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local current = seed

			return source:Subscribe(function(...)
				current = accumulator(current, ...)
				sub:Fire(current)
			end, sub:GetFailComplete())
		end)
	end
end

local ThrottledFunction = {}
ThrottledFunction.ClassName = "ThrottledFunction"
ThrottledFunction.__index = ThrottledFunction

function ThrottledFunction.new(timeoutInSeconds, func, config)
	assert(type(timeoutInSeconds) == "number", "timeoutInSeconds must be number")
	assert(type(func) == "function", "func must be function")
	local self = setmetatable({}, ThrottledFunction)

	self._nextCallTimeStamp = 0
	self._timeout = timeoutInSeconds
	self._func = func

	self._trailingValue = nil

	self._callLeading = true
	self._callTrailing = true

	self:_configureOrError(config)

	return self
end

function ThrottledFunction:Call(...)
	if self._trailingValue then
		-- Update the next value to be dispatched
		self._trailingValue = table.pack(...)
	elseif self._nextCallTimeStamp <= tick() then
		if self._callLeading or self._callLeadingFirstTime then
			self._callLeadingFirstTime = false
			-- Dispatch immediately
			self._nextCallTimeStamp = tick() + self._timeout
			self._func(...)
		elseif self._callTrailing then
			-- Schedule for trailing at exactly timeout
			self._trailingValue = table.pack(...)
			task.delay(self._timeout, function()
				if self.Destroy then
					self:_dispatch()
				end
			end)
		else
			error("trailing and leading are both disabled", 2)
		end
	elseif self._callLeading or self._callTrailing or self._callLeadingFirstTime then
		self._callLeadingFirstTime = false
		-- As long as either leading or trailing are set to true, we are good
		local remainingTime = self._nextCallTimeStamp - tick()
		self._trailingValue = table.pack(...)

		task.delay(remainingTime, function()
			if self.Destroy then
				self:_dispatch()
			end
		end)
	end
end

function ThrottledFunction:_dispatch()
	self._nextCallTimeStamp = tick() + self._timeout

	local trailingValue = self._trailingValue
	if trailingValue then
		-- Clear before call so we are in valid state!
		self._trailingValue = nil
		self._func(unpack(trailingValue, 1, trailingValue.n))
	end
end

function ThrottledFunction:_configureOrError(throttleConfig)
	if throttleConfig == nil then
		return
	end

	assert(type(throttleConfig) == "table", "throttleConfig must be table")

	for key, value in pairs(throttleConfig) do
		assert(type(value) == "boolean", "throttleConfig entry must be boolean")

		if key == "leading" then
			self._callLeading = value
		elseif key == "trailing" then
			self._callTrailing = value
		elseif key == "leadingFirstTimeOnly" then
			self._callLeadingFirstTime = value
		else
			error(string.format("bad key %q in throttleConfig", tostring(key)))
		end
	end

	assert(self._callLeading or self._callTrailing, "cannot configure both leading and trailing disabled")
end

function ThrottledFunction:Destroy()
	self._trailingValue = nil
	self._func = nil
	setmetatable(self, nil)
end

--[=[
	Throttles emission of observables.

	https://rxjs-dev.firebaseapp.com/api/operators/throttleTime

	:::note
	Note that on complete, the last item is not included, for now, unlike the existing version in rxjs.
	:::

	@param duration number
	@param throttleConfig { leading = true, trailing = true }
	@return (source: Observable) -> Observable
]=]
function export.throttleTime(duration: number, throttleConfig: {leading: boolean?, trailing: boolean?}): Transformer
	assert(type(duration) == "number", "duration must be number")
	assert(type(throttleConfig) == "table" or throttleConfig == nil, "throttleConfig must be table or nil")

	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local throttledFunction = ThrottledFunction.new(duration, function(...)
				sub:Fire(...)
			end, throttleConfig)

			return {
				throttledFunction,
				source:Subscribe(function(...)
					throttledFunction:Call(...)
				end, sub:GetFailComplete()),
			}
		end)
	end
end

--[=[
	Throttles emission of observables on the defer stack to the last emission.
	@return (source: Observable) -> Observable
]=]
function export.throttleDefer(): Transformer
	return function(source)
		assert(isObservable(source), "source must be Observable")

		return newObservable(function(sub)
			local maid = Maid.new()

			local lastResult

			maid:GiveTask(source:Subscribe(function(...)
				if not lastResult then
					lastResult = table.pack(...)

					-- Queue up our result
					maid._currentQueue = task.defer(function()
						local current = lastResult
						lastResult = nil

						if sub:IsPending() then
							sub:Fire(table.unpack(current, 1, current.n))
						end
					end)
				else
					lastResult = table.pack(...)
				end
			end, sub:GetFailComplete()))

			return maid
		end)
	end
end

--------------------------------------------------------------------------------
-- metauni ADDITIONS
--------------------------------------------------------------------------------

-- GPT-4 wrote this concat Transformer after debugging an incorrect
-- usage of Rx.merge.

--[=[
    Concatenates the given observables in order, waiting for the previous observable to complete before starting the next one.
    https://rxjs.dev/api/operators/concat

    @param observables { Observable }
    @return Observable
]=]
function export.concat(observables: {Observable}): Observable
	assert(type(observables) == "table", "observables must be array of Observable values")

	for _, item in pairs(observables) do
			assert(isObservable(item), "Observable expected")
	end

	return newObservable(function(sub)
			local currentIndex = 1

			local function onNextObservable()
					if currentIndex > #observables then
							sub:Complete()
					else
							local currentObservable = observables[currentIndex]
							currentIndex = currentIndex + 1
							currentObservable:Subscribe(
									function(...) sub:Fire(...) end,
									function(...) sub:Fail(...) end,
									onNextObservable
							)
					end
			end

			onNextObservable()
	end)
end


return table.freeze(export)
