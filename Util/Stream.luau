--!strict
--!native
--[[
MIT License

Copyright (c) 2024 Billy Snikkers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--[[
--------------------------------------------------------------------------------
-- Stream
--------------------------------------------------------------------------------
Original author: Billy Snikkers
Modifications by: <you>

Contents:
- clean : A general purpose cleanup function
- Stream constructors and transformers
	- `Stream<T...>` type
	- of, from, map filter, delayed, merge, pipe, combineLatest, switchMap etc...
- Roblox-instance-related stream constructors/transformers
	- propertyOf, attributeOf, fromSignal, fromValueBase, firstChildOf etc...
- LifeStream constructors, transformers and lifetime management.
	- `LifeStream<T> = Stream<T,boolean>` type
	- eachPlayer, eachChildOf, toEachChild, eachTagged
- mount & new (for declarative and reactive instance creation)
	- mount, new, compute, toStream

ATTENTION: The clean function comes first but it's not so interesting.
Skip ahead to `export type Stream<T>` to read about streams.
]]


-- This is set to `any` instead of the commented out version because luau just unfolds it
-- into a mess when you try and hover over any type involving CleanupTask.
export type CleanupTask = any
-- export type CleanupTask = () -> ()
-- 	| thread | RBXScriptConnection | Instance
-- 	| {Destroy: (self: any) -> ()} | {}
-- 	| {CleanupTask} | nil

--[[

	The creation of an object or initiation of a behaviour can (should always) yield
	an artifact called a "cleanup task". This artifact enables any resources created
	or behaviours connected to be "cleaned up". Some examples
	- A thread can be cancelled
	- A connection can be disconnected
	- An instance (or a class-object with Destroy method) can be destroyed
	We can also have higher-order cleanup tasks:
	- A collection (array) of cleanups can be cleaned up one-by-one (in reverse order)
	- A function can be called to perform arbitrary clean-up or other housekeeping behaviour.

	`clean` is a function which uniformly cleans up any of these artifacts (recursively).

	Notes:
	- We typically use the verb `cleanup` for a CleanupTask variable, pretending it is the function kind of CleanupTask.
	- Instead of using this clean function, we could choose to always wrap a cleanup task in a function,
		but this clutters the code and creates extra functions unecessarily.
		> We just want to return *stuff* and have it dealt with!
	- CleanupTasks can be nil
	- Multiple CleanupTasks can be simply gathered into an array (itself a cleanup task),
		e.g. {cleanup1, cleanup2}. But since any CleanupTask can be nil, this is an array with holes.
		Thus you cannot reliably get the length with #, or make other array-iteration assumptions.
	- Ignore the refs argument when using clean. It is used internally to avoid infinite recursion.
]]
local function clean(cleanup: CleanupTask, refs: {[any]:true}?)
	if cleanup == nil then
		return
	elseif type(cleanup) == "function" then
		cleanup()
	elseif type(cleanup) == "thread" then
		local cancelled
		if coroutine.running() ~= cleanup then
			cancelled = pcall(function()
				task.cancel(cleanup)
			end)
		end

		if not cancelled then
			local toCancel = cleanup
			task.defer(function()
				task.cancel(toCancel)
			end)
		end
	elseif typeof(cleanup) == "RBXScriptConnection" then
		cleanup:Disconnect()
	elseif typeof(cleanup) == "Instance" then
		cleanup:Destroy()
	elseif typeof(cleanup) == "table" then

		if (cleanup :: any).Destroy then
			(cleanup :: any):Destroy()
		elseif getmetatable((cleanup :: any)) == nil then
			local max_index = 0
			for key in (cleanup :: any) do
				if typeof(key) == "number" then
					max_index = math.max(max_index, key)
				else
					warn(`[clean] Cannot clean non-numeric task table - might be an already destroyed object\nTraceback:\n{debug.traceback()}`)
					return
				end
			end
			if refs then
				if refs[cleanup] then
					return
				end
				refs[cleanup] = true
			else
				refs = {[cleanup]=true :: true}
			end
			-- Cleanup in reverse order of creation
			for i=max_index, 1, -1 do
				clean((cleanup :: any)[i], refs)
			end
			if not table.isfrozen(cleanup) then
				table.clear(cleanup)
			end
		else
			error(`[clean] Cannot cleanup table with a metatable but no :Destroy() method.\nTable:{cleanup}\nTraceback:\n{debug.traceback()}`)
		end
	end
end

--[[
	Useful in Hoarcekat stories. Don't over use this.
]]
local function getCleanupFunc(cleanup: CleanupTask): () -> ()
	return function()
		clean(cleanup)
		cleanup = nil
	end
end

export type Stream<T...> = ((T...) -> ()) -> CleanupTask
--[[
	A stream is
	- Literally: A function that takes a callback-function (we call it a listener),
		which it calls with data whenever it pleases, until it is "cleaned up".
	- Conceptually: a stream of data, whose datum is emitted synchronously or asynchronously
	
	Example:
	```lua
	local function myStream(listener: (number) -> ()): CleanupTask
		-- Emits synchronously
		listener(1)
		listener(2)

		-- Emits asynchronously
		local value = 3
		local thread = task.spawn(function()
			while true do
				task.wait(1)
				listener(value)
				value += 1
			end
		end)

		-- This is the cleanup - `clean(thread)` will stop this stream.
		return thread
	end

	local cleanup = myStream(print) -- prints 1 and 2 immediately
	-- will print 3,4,5,6... every second until cleanup is called
	task.wait(4.5)
	clean(cleanup)
	```

	How to think about streams?

	Streams are about control-flow and data-flow. By listening to a stream, i.e. giving it a callback/behaviour, you
	yield control to the stream to decide when and with-what-data that behaviour is executed.
	In this sense, they can be thought of as a common generalisation of for-loops and events, which both provide data from some source,
	and execute a behaviour synchronously (for-loops) or asynchronously (events).

	But do not be mistaken, they are strictly more-powerful than either concept!

	-- TODO: insert link to blog post
]]

-- selene:allow(unused_variable)
local function NO_OP<T...>(... : T...): () end

--[[
	A stream that never emits anything
]]
-- selene:allow(unused_variable)
local function never<T...>(_listener: (T...) -> ()): CleanupTask
	return nil
end

--[[
	- `listen(stream, listener)` is just `stream(listener)`
	- `listen(stream)` is just `stream(NO_OP)` (listens to the stream but does nothing with the emitted values)
]]
local function listen<T...>(stream: Stream<T...>, listener: nil | (T...) -> ()): CleanupTask
	return stream(listener or NO_OP)
end

--[[
	The provided (tidy)-listener can return a cleanup task after each emission, which will be
	called before the next value is emitted (or when the stream ends).

	If you have a LifeStream<T>, use `listenTidyEach` to bind to individual lifetimes.
]]
local function listenTidy<T>(stream: Stream<T>, tidyListener: (T) -> CleanupTask): CleanupTask
	local cleanupListener: CleanupTask = nil
	local cleanupStream = stream(function(value: T): ()
		clean(cleanupListener)
		cleanupListener = nil
		cleanupListener = tidyListener(value)
	end)
	return function()
		clean(cleanupListener)
		cleanupListener = nil
		clean(cleanupStream)
		cleanupStream = nil
	end
end

--[[
	A stream that emits each item in the array synchronously (not the array itself)
]]
local function from<T>(array : {T}): Stream<T>
	return function(listener: (T) -> ()): CleanupTask
		for _, value in array do
			listener(value)
		end
		return nil
	end
end

--[[
	A stream that emits each argument synchronously
]]
local function of<T>(... : T): Stream<T>
	local array = {...}
	return function(listener: (T) -> ()): CleanupTask
		for _, value in array do
			listener(value)
		end
		return nil
	end
end

--[[
	(Transformer)
	`Stream<->` is a functor.
	- `map(fn)(stream)` emits `fn(x)` whenever `stream` emits `x`.
	Example (using pipe2)
	```lua
	-- A stream that emits "2", "4" and "6"
	local stream : Stream<string> = pipe2(
		of(1,2,3),
		map(function(x)
			return 2 * x
		end)
		map(tostring)
	)
	```
]]
local function map<T...,U...>(fn: (T...) -> U...): (Stream<T...>) -> Stream<U...>
	return function(stream: Stream<T...>): Stream<U...>
		-- The mapped stream
		return function(listener: (U...) -> ()): CleanupTask
			-- Listen and map the values, returning CleanupTask
			return stream(function(...: T...): ()
				listener(fn(...))
			end)
		end
	end
end

--[[
	(Transformer)
	`mapTo(x,y,z)(stream)` emits `(x,y,z)` (together) whenever `stream` emits anything.
]]
local function mapTo<T...,U...>(...: U...): (Stream<T...>) -> Stream<U...>
	local values: {any} = table.pack(...)
	return function(stream: Stream<T...>): Stream<U...>
		-- The mapped stream
		return function(listener: (U...) -> ()): CleanupTask
			-- selene:allow(unused_variable)
			return stream(function(...): ()
				listener(table.unpack(values))
			end)
		end
	end
end

--[[
	(Transformer)
	Call `fn` with the emitted values and re-emit them. Doesn't modify the stream
	data, but is useful for inspection for debugging.
	Example:
	```lua
	local stream = of(1,2,3)
	listen(tap(print)(stream)) -- prints 1, 2, 3 (on separate lines)
	```
]]
local function tap<T...>(fn: (T...) -> ()): (Stream<T...>) -> Stream<T...>
	return function(stream: Stream<T...>): Stream<T...>
		-- The tapped stream
		return function(listener: (T...) -> ()): CleanupTask
			return stream(function(...: T...): ()
				fn(...)
				listener(...)
			end)
		end
	end
end

--[[
	(Transformer)
	Filter the stream using the provided predicate.
	`filter(predicate)(stream)` emits `x` when `stream` emits `x` if `predicate(x) == true`.
]]
local function filter<T...>(predicate: (T...) -> boolean) : (Stream<T...>) -> Stream<T...>
	return function(stream: Stream<T...>): Stream<T...>
		-- The filtered stream
		return function(listener: (T...) -> ()): CleanupTask
			return stream(function(...: T...): ()
				if predicate(...) then
					listener(...)
				end
			end)
		end
	end
end

--[[
	(Transformer)
	`delay(seconds)(stream)` is a stream which, when listened to, delays listening
	to `stream` for `seconds` seconds, and then emits the values from `stream`
	as they are emitted. It does not yield the current thread.
	Example:
	```lua
	listen(delayed(1)(of("a","b")), print)
	-- after 1 second
	-- prints "a"
	-- prints "b" (immediately after "a")
	```
]]
local function delayed<T...>(seconds: number): (Stream<T...>) -> Stream<T...>
	return function(stream: Stream<T...>): Stream<T...>
		return function(listener:(T...) -> ())
			return task.delay(seconds, stream, listener)
		end
	end
end

--[[
	(Transformer)
	Merge multiple streams into one.
	`merge(stream1, stream2, ..., stream_n)` emits `x` when any of `stream1`, `stream2` ... `stream_n` emits `x`.
	Example:
	```lua
	local stream = merge(
		delayed(2)(of("a")),
		of("b", "c"),
		delayed(1)(of("d"))
	)
	listen(stream, print)
	-- prints "b" (immediately)
	-- prints "c" (immediately)
	-- prints "d" (after 1 second)
	-- prints "a" (after 2 seconds)
	```
]]
local function merge<T...>(... : Stream<T...>): Stream<T...>
	local streams = {...}
	-- The merged stream
	return function(listener: (T...) -> ()): CleanupTask
		local cleanups = {}
		for _, stream in streams do
			table.insert(cleanups, stream(listener))
		end
		return if #cleanups == 0 then nil else cleanups
	end
end

--[[
	Pipes invert the function application syntax.
	`pipe(stream)(transformer1, transformer2, ..., transformer_n)` is the same as
	`transformer_n(...(transformer2(transformer1(stream))))`

	This variadic version can't be properly typed, use the `pipe1`, `pipe2`,
	`pipe3` and `pipe4` versions if you want to preserve types.
]]
local function pipe(stream: Stream<...any>, ...: (Stream<...any>) -> Stream<...any>): Stream<...any>
	for _, transformer in {...} do
		stream = transformer(stream)
	end
	return stream
end

--[[
	Why not lol.
]]
local function pipe0<A...>(stream: Stream<A...>): Stream<A...>
	return stream
end

--[[
	`pipe1(stream, t1)` is just `t1(stream)`.
	The pipe functions allow streams to be syntatically transformed in "chronological" order of transformation,
	with transformations of the original stream occuring from left to right (or top to bottom).
]]
local function pipe1<A...,Z...>(
	stream: Stream<A...>,
	t1: (Stream<A...>) -> Stream<Z...>) : Stream<Z...>
	return t1(stream)
end

--[[
	`pipe2(stream, t1, t2)` is just `t2(t1(stream))`.
	The pipe functions allow streams to be syntatically transformed in "chronological" order of transformation,
	with transformations of the original stream occuring from left to right (or top to bottom).
]]
local function pipe2<A...,B...,Z...>(
	stream: Stream<A...>,
	t1: (Stream<A...>) -> Stream<B...>,
	t2: (Stream<B...>) -> Stream<Z...>) : Stream<Z...>
	return t2(t1(stream))
end

--[[
	`pipe3(stream, t1, t2, t3)` is just `t3(t2(t1(stream)))`.
	The pipe functions allow streams to be syntatically transformed in "chronological" order of transformation,
	with transformations of the original stream occuring from left to right (or top to bottom).
]]
local function pipe3<A...,B...,C...,Z...>(
	stream: Stream<A...>,
	t1: (Stream<A...>) -> Stream<B...>,
	t2: (Stream<B...>) -> Stream<C...>,
	t3: (Stream<C...>) -> Stream<Z...>) : Stream<Z...>
	return t3(t2(t1(stream)))
end

--[[
	`pipe4(stream, t1, t2, t3, t4)` is just `t4(t3(t2(t1(stream))))`.
	The pipe functions allow streams to be syntatically transformed in "chronological" order of transformation, with transformations
	of the original stream occuring from left to right (or top to bottom).
]]
local function pipe4<A...,B...,C...,D...,Z...>(
	stream: Stream<A...>,
	t1: (Stream<A...>) -> Stream<B...>,
	t2: (Stream<B...>) -> Stream<C...>,
	t3: (Stream<C...>) -> Stream<D...>,
	t4: (Stream<D...>) -> Stream<Z...>) : Stream<Z...>
	return t4(t3(t2(t1(stream))))
end

--[[
	(Transformer)
	Emits the first value from any of the streams, and ignores the rest.
]]
local function firstOfAny<T...>(...: Stream<T...>): Stream<T...>
	local streams = {...}
	-- The output stream
	return function(listener: (T...) -> ()): CleanupTask
		local fired = false
		local cleanup : CleanupTask = nil
		cleanup = merge(table.unpack(streams))(function(...: T...): ()
			if not fired then
				fired = true
				clean(cleanup)
				listener(...)
			end
		end)
		-- If the stream fired immediately (synchronously), cleanup was not yet set
		-- so we must clean it up here
		if fired then
			clean(cleanup)
			cleanup = nil
		end
		return cleanup
	end
end

-- Don't export this >:(
local UNSET = newproxy(false)
type UNSET = typeof(UNSET)

--[[
	(Transformer)
	Only emits values that are not equal to the previous value.
	i.e. `1,2,2,3,1,1,2` becomes `1,2,3,1,2`
]]
local function skipUnchanged<T>(stream: Stream<T>): Stream<T>
	return function(listener: (T) -> ()): CleanupTask
		local prev: T | UNSET = UNSET
		return stream(function(x: T): ()
			if x ~= prev then
				prev = x
				listener(x)
			end
		end)
	end
end

--[[
	(Transformer)
	Converts a table of streams into a stream of tables.
	- When `combineLatest(streams)` emits `values :: {[K] : V}` with `values[key] == x` then `x`
	is the latest value emitted by the stream `t[key]`.
	- `combineLatest(streams)` will not emit until all streams have emitted at least once.
	- When all streams have emitted at least once, `combineLatest(streams)` will emit whenever any of the streams emit.

	Note: `dontCloneTheEmittedTableIKnowWhatImDoing` should only be true if you know what you're doing, i.e.
	- You've read/understand this function
	- You will just unpack it or iterate over it, and not mutate it.
	- You will not yield at any point before you are done accessing the table (it can be mutated by the stream)
	- You will not store a reference to it or mutate it (it can be mutated by the stream)
]]
local function combineLatest<K,V>(streams: {[K] : Stream<V>}, dontCloneTheEmittedTableIKnowWhatImDoing: boolean?): Stream<{[K] : V}>
	-- The combined stream
	return function(listener: ({[K] : V}) -> ()): CleanupTask
		-- Initialize values to UNSET (no emitting until all streams have emitted)
		local values: {[K] : V | UNSET} = {}
		for key in streams do
			values[key] = UNSET
		end

		-- Listen to all streams
		local cleanups = {}
		for key, stream in streams do
			table.insert(cleanups, stream(function(x: V): ()
				values[key] = x
				for _, value in values do
					if value == UNSET then
						return
					end
				end
				if dontCloneTheEmittedTableIKnowWhatImDoing then
					listener(values)
				else
					listener(table.clone(values))
				end
			end))
		end

		return cleanups
	end
end

--[[
	(Transformer)
	Map the values in stream `a` with the function `fn`.
]]
local function combine1<A,Z>(a: Stream<A>, fn: (A) -> Z): Stream<Z>
	-- Output stream is just `map(fn)(a)`, but we unfold it for less debugging whiplash
	return function(listener: (Z) -> ()): CleanupTask
		return a(function(value: A): ()
			listener(fn(value))
		end)
	end
end

--[[
	(Transformer)
	Combine the latest values of `a`, `b` with the function `fn`.
	Useful for computing derived values from multiple streams.
]]
local function combine2<A,B,Z>(a: Stream<A>, b: Stream<B>, fn: (A,B) -> Z): Stream<Z>
	return function(listener: (Z) -> ()): CleanupTask
		return combineLatest({a,b} :: {Stream<any>}, true)(function(values: {any}): ()
			listener(fn(table.unpack(values)))
		end)
	end
end

--[[
	(Transformer)
	Combine the latest values of `a`, `b`, `c` with the function `fn`.
	Useful for computing derived values from multiple streams.
]]
local function combine3<A,B,C,Z>(a: Stream<A>, b: Stream<B>, c: Stream<C>, fn: (A,B,C) -> Z): Stream<Z>
	return function(listener: (Z) -> ()): CleanupTask
		return combineLatest({a,b,c} :: {Stream<any>}, true)(function(values: {any}): ()
			listener(fn(table.unpack(values)))
		end)
	end
end

--[[
	(Transformer)
	Combine the latest values of `a`, `b`, `c`, `d` with the function `fn`.
	Useful for computing derived values from multiple streams.
]]
local function combine4<A,B,C,D,Z>(a: Stream<A>, b: Stream<B>, c: Stream<C>, d: Stream<D>, fn: (A,B,C,D) -> Z): Stream<Z>
	return function(listener: (Z) -> ()): CleanupTask
		return combineLatest({a,b,c,d} :: {Stream<any>}, true)(function(values: {any}): ()
			listener(fn(table.unpack(values)))
		end)
	end
end

--[[
	(Transformer)
	Convert a stream of streams into a stream that always emits from the latest stream,
	cleaning up previous streams when a new one is emitted.
]]
local function switchAll<T...>(stream: Stream<Stream<T...>>): Stream<T...>
	return function(listener: (T...) -> ()): CleanupTask
		local cleanupInner : CleanupTask? = nil
		local cleanupStream = stream(function(innerStream: Stream<T...>): ()
			clean(cleanupInner)
			cleanupInner = nil
			cleanupInner = innerStream(listener)
		end)
		return function()
			clean(cleanupInner)
			cleanupInner = nil
			clean(cleanupStream)
			cleanupStream = nil
		end
	end
end

--[[
	(Transformer)
	`switchMap(fn)(stream)` emits from the stream `fn(x)` while `x` is the latest emitted value of `stream`.
	Useful for when you wanted to listen to a stream that depends on the latest value of another stream.
	Prototypical example is `toProperty(property)`. Go read that, otherwise, here is a toy example.

	```lua
	-- Emits 1, 2, 3, 4, ... with a `seconds` second delay between each.
	local function timer(seconds: number): Stream<number>
		return function(listener)
			return task.spawn(function()
				local x = 1
				while true do
					task.wait(seconds)
					listener(x)
				end
			end)
		end
	end

	-- This emits "(1,1)" (time=0.4s), "(1,2)" (time=0.8s),
	-- "(2,1)" (time=1.4s), "(2,2)" (time=1.8s), "(3,1)" (time=2.4s)
	-- Note that the inner stream is being "switched out" at the whole-second points.
	local stream: Stream<number> = pipe1(
		timer(1),
		switchMap(function(x)
			return pipe1(
				timer(0.4),
				map(function(y)
					return `({x},{y})`
				end)
			)
		end)
	)
	```
]]
local function switchMap<T...,U...>(fn: (T...) -> Stream<U...>): (Stream<T...>) -> Stream<U...>
	return function(source: Stream<T...>): Stream<U...>
		-- Apply switchAll to a stream of streams
		-- so that we get a stream that emits only from the latest stream
		-- Note this code is just `switchAll(map(fn)(source))` unfolded for less debugging whiplash
		return switchAll(function(streamListener: (Stream<U...>) -> ()): CleanupTask
			-- Apply fn to every emitted value to get a stream, and give it to the streamListener
			return source(function(...: T...): ()
				streamListener(fn(...))
			end)
		end)
	end
end

--[[
	`nilOnce: Stream<T?>`
	Just emits `nil` immediately
]]
local function nilOnce<T>(listener: (T?) -> ()): CleanupTask
	listener(nil)
	return nil
end

--[[
	(Transformer) `replaceNil(value)(stream)` replaces nil-values from `stream` with `value`.
]]
local function replaceNil<T>(value: T): (Stream<T?>) -> Stream<T>
	return function(stream: Stream<T?>): Stream<T>
		return function(listener: (T) -> ())
			return stream(function(x: T?)
				if x == nil then
					listener(value)
				else
					listener(x)
				end
			end)
		end
	end
end

--[[
	(Transformer) filters out nil-values from a stream.
	Note: it's usually better to use`replaceNil(value)`, or just handle the nil
	case in your listener function, since otherwise you are not reacting to your
	data becoming unnavailable.
]]
local function blockNil<T>(stream: Stream<T?>): Stream<T>
	return function(listener: (T) -> ())
		return stream(function(x: T?)
			if x ~= nil then
				listener(x)
			end
		end)
	end
end

--[[
	`attributeOf(instance, attribute)` emits `instance:GetAttribute(attribute)`
	immediately and whenever it changes.
	Note it could be nil, so consider using `replaceNil` or `blockNil`.
]]
local function attributeOf(instance: Instance, attribute: string): Stream<any?>
	return function(listener: (any?) -> ()): CleanupTask
		listener(instance:GetAttribute(attribute))
		return instance:GetAttributeChangedSignal(attribute):Connect(function()
			listener(instance:GetAttribute(attribute))
		end)
	end
end

--[[
	Turns a `Stream<Instance?>` in to a `Stream<any?>`, where the emitted value
	is the latest value of the attribute of the latest instance, or nil if either
	the latest instance is nil, or the attribute is nil (usually if it's not yet set).
	Example:
	```lua
	-- Emits the "TorsoDamage" attribute of the PrimaryPart of the LocalPlayer's Character,
	-- or nil if the LocalPlayer's character is nil, or if the character's the PrimaryPart is nil,
	-- or if the attribute is nil.
	local stream: Stream<number?> = pipe2(
		propertyOf(Players.LocalPlayer, "Character"),
		toProperty("PrimaryPart"),
		-- the incoming stream to this next transformer is of type Stream<Instance?>
		toAttribute("TorsoDamage")
	)
	```
]]
local function toAttribute(attribute: string): (Stream<Instance?>) -> Stream<any?>
	return switchMap(function(instance: Instance?): Stream<any?>
		if instance then
			return attributeOf(instance, attribute)
		else
			return nilOnce
		end
	end)
end

--[[
	Safely verify that an instance has a property.
]]
local function hasProperty(instance: Instance, name: string): boolean
	return (pcall(instance.GetPropertyChangedSignal, instance, name))
end

--[[
	`propertyOf(instance, property)` emits `instance[property]` immediately and whenever it changes.
]]
local function propertyOf(instance: Instance, property: string): Stream<any>
	if not hasProperty(instance, property) then
		warn(`[Stream.propertyOf] Instance {instance} does not have property {property}`)
		return never
	end
	return function(listener: (any) -> ()): CleanupTask
		listener((instance :: any)[property])
		return instance:GetPropertyChangedSignal(property):Connect(function()
			listener((instance :: any)[property])
		end)
	end
end

--[[
	Turns a Stream<Instance?> into a Stream<any?>, where the emitted value is the property of the Instance,
	or nil if the latest instance is nil.
	Example:
	```lua
	-- Emits the FieldOfView of the CurrentCamera of a given viewportFrame.
	local stream: Stream<number?> = pipe1(
		propertyOf(viewPortFrame, "CurrentCamera"),
		-- the incoming stream to this next transformer is of type Stream<Instance?>
		toProperty("FieldOfView"),
	)
	```
]]
local function toProperty(property: string): (Stream<Instance?>) -> Stream<any?>
	return switchMap(function(instance: Instance?)
		if instance then
			return propertyOf(instance, property)
		else
			return nilOnce
		end
	end)
end

--[[
	Turns an RBXScriptSignal into a stream using :Connect(), emitting whatever it fires with
]]
local function fromSignal<T...>(signal: RBXScriptSignal<T...>): Stream<T...>
	return function(listener: (T...) -> ()): CleanupTask
		return signal:Connect(listener)
	end
end

--[[
	Turns an RBXScriptSignal into a stream using :Once(), emitting whatever it fires with
]]
local function fromSignalOnce<T...>(signal: RBXScriptSignal<T...>): Stream<T...>
	return function(listener: (T...) -> ()): CleanupTask
		return signal:Once(listener)
	end
end

--[[
	Turns a ValueBase object (IntValue, ObjectValue, etc) into a stream of it's current and
	future values.
]]
local fromValueBase : 
	((IntValue) -> Stream<number>) &
	((RayValue) -> Stream<Ray>) &
	((BoolValue) -> Stream<boolean>) &
	((CFrameValue) -> Stream<CFrame>) &
	((Color3Value) -> Stream<Color3>) &
	((NumberValue) -> Stream<number>) &
	((ObjectValue) -> Stream<Instance?>) &
	((StringValue) -> Stream<string>) &
	((Vector3Value) -> Stream<Vector3>) &
	((BrickColorValue) -> Stream<BrickColor>)
= function(valueBase): Stream<any>
	return function(listener: (any) -> ())
		listener(valueBase.Value)
		return (valueBase.Changed :: any):Connect(function(newValue)
			listener(newValue)
		end)
	end
end

--[[
	A LifeStream<T> emits pairs consisting of a value of type T and a boolean,
	indicating whether the value is "alive" (true) or "dead" (false).
	Most useful when fed into `listenTidyEach`, which binds entities/behaviour
	to the lifetime of a value.
]] 
export type LifeStream<T> = Stream<T,boolean>

local function listenTidyEach<T>(lifeStream: LifeStream<T>, tidyListener: (T) -> CleanupTask): CleanupTask
	local valueCleanups: {[T]: CleanupTask} = {}
	local cleanupStream = lifeStream(function(value: T, alive: boolean)
		if valueCleanups[value] ~= nil then
			clean(valueCleanups[value])
			valueCleanups[value] = nil
		end
		if alive then
			valueCleanups[value] = tidyListener(value)
		end
	end)

	return function()
		-- We worry that one of these cleanups will trigger the stream to fire again, potentionally adding more
		-- so we just keep cleaning until they're all gone.
		local value, cleanup = next(valueCleanups)
		while cleanup ~= nil do
			clean(cleanup)
			valueCleanups[value :: any] = nil
			value, cleanup = next(valueCleanups)
		end
		table.freeze(valueCleanups)
		clean(cleanupStream)
		cleanupStream = nil
	end
end

--[[
	A LifeStream<Player> of the players in the game.
	- Emits `(player: Player, inGame: boolean)` pairs
	- Use `listenTidyEach(eachPlayer, tidyListener)` to bind something to the lifetime of each player.
]]
local eachPlayer: LifeStream<Player>
do
	eachPlayer = function(listener: (Player, boolean) -> ())
		local Players = game:GetService("Players")
		for _, player in Players:GetPlayers() do
			listener(player, true)
		end
		local addedConnection = Players.PlayerAdded:Connect(function(player: Player)
			listener(player, true)
		end)
		local removingConnection = Players.PlayerRemoving:Connect(function(player: Player)
			listener(player, false)
		end)
		return {addedConnection, removingConnection}
	end
end

--[[
	A `LifeStream<Instance>` of the children of an instance.
	- Emits `(child: Instance, isParented: boolean)` pairs
	- Use `listenTidyEach(eachChildOf(instance), tidyListener)` to bind something to the lifetime of each child,
		which ends when it is deparented.
]]
local function eachChildOf(instance: Instance): LifeStream<Instance>
	return function(listener: (Instance, boolean) -> ())
		for _, child in instance:GetChildren() do
			listener(child, true)
		end
		local addedConnection = instance.ChildAdded:Connect(function(child: Instance)
			listener(child, true)
		end)
		local removedConnection = instance.ChildRemoved:Connect(function(child: Instance)
			listener(child, false)
		end)
		return {addedConnection, removedConnection}
	end
end

--[[
	A `LifeStream<Instance>` of the children of an instance with `.Name == name`.
	- Emits `(child: Instance, isNamedAndParented: boolean)` pairs
	- Use `listenTidyEach(eachChildNamedOf(instance, name), tidyListener)` to bind something to the lifetime of each child,
		which ends when it is deparented or renamed to something else.
]]
local function eachChildNamedOf(instance: Instance, name: string): LifeStream<Instance>
	return function(listener: (Instance, boolean) -> ())
		return listenTidyEach(eachChildOf(instance), function(child: Instance)
			return propertyOf(instance, "Name")(function(childName: string)
				listener(child, childName == name)
			end)
		end)
	end
end

--[[
	`firstChildOf(instance, name)` emits `instance:FindFirstChild(name)` immediately and whenever it changes.
	- Note that adding/removing any child of `instance` can effect what `instance:FindFirstChild(name)` is, but
	we only emit when the result of `instance:FindFirstChild(name)` changes (using `skipUnchanged`).
	- Optionally provide a string `classNameIsA` to error if the `child:IsA(classNameIsA) == false`.
]]
local function firstChildOf(instance: Instance, name: string, classNameIsA: string?): Stream<Instance?>
	local stream: Stream<Instance?> = function(listener)
		-- We listen to name changes of every child (and current name), since these can effect what instance:FindFirstChild(name) is.
		return listenTidyEach(eachChildOf(instance), function(child: Instance)
			-- Here we are listening to the property name of each child.
			-- This gets cleaned up by `listenTidyEach` when the child is deparented.
			return propertyOf(child, "Name")(function(_: string)
				local firstChild = instance:FindFirstChild(name)
				if firstChild then
					if classNameIsA and not firstChild:IsA(classNameIsA) then
						error(`[Stream.firstChildOf] Expected {instance}:FindFirstChild({name}):IsA({classNameIsA}) == true, but it is a {firstChild.ClassName}`)
					end
				end
				listener(firstChild)
			end)
		end)
	end

	-- `stream` can emit the same instance many times while other children are added/removed/renamed.
	-- We only want to emit when it changes (but also the initial value)
	return skipUnchanged(stream)
end

--[[
	`toFirstChild(name)(stream)` turns a `Stream<Instance?>` into a `Stream<Instance?>`
	of the :FindFirstChild(name) of the latest emitted instance (see `firstChildOf`).
	- Optionally provide a string `classNameIsA` to error if the `child:IsA(classNameIsA) == false`.
]]
local function toFirstChild(name: string, classNameIsA: string?): (Stream<Instance?>) -> Stream<Instance?>
	return switchMap(function(instance: Instance?)
		if instance then
			return firstChildOf(instance, name, classNameIsA)
		else
			return nilOnce
		end
	end)
end

--[[
	A `LifeStream<Instance>` of each instance with the given tag.
	- Optionally provide an `ancestor` to restrict to instances that are descendants of the `ancestor`.
	- Emits (instance: Instance, isTaggedAndDescendent: boolean) pairs.
	- Use `listenTidyEach(eachTagged(tag), tidyListener)`, to bind something to the lifetime of each tagged instance,
		which ends when the instance is untagged, or when it is no longer a descendant of the ancestor.
]]
local function eachTagged(tag: string, ancestor: Instance?): LifeStream<Instance>
	local CollectionService = game:GetService("CollectionService")

	local eachTaggedAnywhere = function(listener: (Instance, boolean) -> ())
		for _, instance in CollectionService:GetTagged(tag) do
			listener(instance, true)
		end
		local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			listener(instance, true)
		end)
		local removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			listener(instance, false)
		end)
		return {addedConnection, removedConnection}
	end

	if ancestor == nil then
		return eachTaggedAnywhere
	end
	
	return function(listener: (Instance, boolean) -> ()): CleanupTask
		return listenTidyEach(eachTaggedAnywhere, function(instance: Instance) : CleanupTask
			local currentIsDescendant = instance:IsDescendantOf(ancestor)
			if currentIsDescendant then
				listener(instance, true)
			end
			return instance.AncestryChanged:Connect(function(_: Instance, _: Instance?)
				if currentIsDescendant ~= instance:IsDescendantOf(ancestor) then
					currentIsDescendant = instance:IsDescendantOf(ancestor)
					listener(instance, currentIsDescendant)
				end
			end)
		end)
	end
end

--[[
	Takes ownership of the emitted values by cleaning them up when a new value is emitted.
]]
local function tidy(stream: Stream<CleanupTask>): Stream<CleanupTask>
	return function(listener: (CleanupTask) -> ()): CleanupTask
		return listenTidy(stream, function(cleanupTask: CleanupTask)
			listener(cleanupTask)
			return cleanupTask
		end)
	end
end

local function _callMeMaybe(myNumber: number): Stream<number>
	return function(listener:(number) -> ())
		if math.random() > 0.5 then
			listener(myNumber)
		end
		return nil
	end
end

local function listenTidyPairs<K,V>(pairStream: Stream<K,V?>, tidyListener: (K,V) -> CleanupTask): CleanupTask
	local keyCleanups = {}
	return pairStream(function(key: K, value: V?)
		clean(keyCleanups[key])
		keyCleanups[key] = nil
		if value ~= nil then
			keyCleanups[key] = tidyListener(key, value)
		end
	end)
end

return {
	-- Helper stuff
	clean = clean,
 getCleanupFunc = getCleanupFunc,
	NO_OP = NO_OP,
	never = never,
	-- Listening
	listen = listen,
	listenTidy = listenTidy,
	-- Stream constructors/transformers
	from = from,
	of = of,
	map = map,
	mapTo = mapTo,
	tap = tap,
	filter = filter,
	delayed = delayed,
	merge = merge,
	pipe = pipe,
	pipe0 = pipe0,
	pipe1 = pipe1,
	pipe2 = pipe2,
	pipe3 = pipe3,
	pipe4 = pipe4,
	firstOfAny = firstOfAny,
	skipUnchanged = skipUnchanged,
	combineLatest = combineLatest,
	combine1 = combine1,
	combine2 = combine2,
	combine3 = combine3,
	combine4 = combine4,
	switchAll = switchAll,
	switchMap = switchMap,
	-- Roblox-instance-related stream constructors/transformers
	nilOnce = nilOnce,
	replaceNil = replaceNil,
	blockNil = blockNil,
	attributeOf = attributeOf,
	toAttribute = toAttribute,
	hasProperty = hasProperty,
	propertyOf = propertyOf,
	toProperty = toProperty,
	fromSignal = fromSignal,
	fromSignalOnce = fromSignalOnce,
	fromValueBase = fromValueBase,
	-- LifeStream listeners/constructors/transformers
	listenTidyEach = listenTidyEach,
	eachPlayer = eachPlayer,
	eachChildOf = eachChildOf,
	eachChildNamedOf = eachChildNamedOf,
	firstChildOf = firstChildOf,
	toFirstChild = toFirstChild,
	eachTagged = eachTagged,
	tidy = tidy,
	listenTidyPairs = listenTidyPairs,
}