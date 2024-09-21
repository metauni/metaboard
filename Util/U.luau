--!native
--!strict

local Stream = require(script.Parent.Stream)
local Value = require(script.Parent.Value)
local Map = require(script.Parent.Map)

local U = {}

export type CleanupTask = Stream.CleanupTask
export type Stream<T...> = Stream.Stream<T...>
export type LifeStream<T> = Stream.LifeStream<T>
export type Value<T> = Value.Value<T>
export type Map<K,V> = Map.Map<K,V>

export type Has<T> = 
	Stream<T> 
	| RBXScriptSignal<T> 
	| { Stream: (self: any) -> Stream<T> }
	| { Observe: (self: any) -> Stream<T> }
	| T

U.clean = Stream.clean

--[[
	Create a `Value` object `Value(initial)`, add it to the cleanup table,
	and return it
]]
function U.Value<T>(cleanup: {Stream.CleanupTask}, initial: T): Value<T>
	local valueObject = Value(initial)
	table.insert(cleanup, valueObject)
	return valueObject
end

--[[
	Create a `Map` object `Map(initial)`, add it to the cleanup table,
	and return it
]]
function U.Map<K,V>(cleanup: {CleanupTask}, initial: {[K]: V?})
	local mapObject = Map(initial)
	table.insert(cleanup, mapObject)
	return mapObject
end

-- Helper function for `mount`
local function toHandler(value: any): ((...any) -> ())?
	if typeof(value) == "function" then
		return value
	elseif typeof(value) == "Instance" and value:IsA("ValueBase") then
		return function(newValue: any)
			(value :: any).Value = newValue
		end
	elseif typeof(value) == "table" and typeof(value.SetValue) == "function" then
		return function(newValue: any)
			value:SetValue(newValue)
		end
	else
		return nil
	end
end

--[[
	Convert a Has<T> into a Stream<T>.
	- Leaves streams untouched (i.e. functions)
	- Converts a ValueBase instance into a stream of its latest value
	- Converts a RBXScriptSignal instances into a stream of fired values
	- Converts objects with .Stream() or :Stream() method into the returned stream
	- Converts objects with .Observe() or :Observe() method into stream of emitted values
	- Otherwise wraps the input `state` in a stream that emits the `state` once
]]
function U.toStream<T>(has: Has<T>): Stream<T>
	if typeof(has) == "function" then
		return has
	elseif typeof(has) == "Instance" and has:IsA("ValueBase") then
		return Stream.fromValueBase(has) :: any
	elseif typeof(has) == "RBXScriptSignal" then
		return Stream.fromSignal(has)
	elseif typeof(has) == "table" and typeof(has.Stream) == "function" then
		return has:Stream() -- works also if 0-arg, like state.Stream()
	elseif typeof(has) == "table" and typeof(has.Observe) == "function" then
		return function(listener)
			return has:Observe():Subscribe(listener)
		end
	else
		return Stream.of((has :: any) :: T)
	end
end

--[[
	Sometimes there's no-need to track the cleanup where a stream is listened to,
	because the source of the stream will be destroyed at the same time as the
	listener is cleaned up. `U.forever` does `U.toStream` and then transforms
	it into a stream that doesn't return a cleanup when listened to.
]]
function U.forever<T>(has: Has<T>): Stream<T>
	local stream = U.toStream(has)
	return function(listener)
		local _ignored = stream(listener)
		return nil
	end
end

local function mergeOverwrites(mountProps: {[any]: any}, merged: {[any]: any})
	for key, value in mountProps do
		if key ~= "overwrite" then
			if typeof(key) == "number" then
				table.insert(merged, value)
			else
				merged[key] = value
			end
		end
	end
	if mountProps.overwrite ~= nil then
		if typeof(mountProps.overwrite) ~= "table" then
			error(`[U.mount] Expected mountProps.overwrite to be a table, got a {typeof(mountProps.overwrite)} ({mountProps.overwrite})`)
		end
		mergeOverwrites(mountProps.overwrite, merged)
	end
end

--[[
	Very general purpose way of attaching behaviour and children to an instance.
	Key-value pairs in mountProps can have many forms, but generally the
	key determines what kind of behaviour, and the behaviour itself is derived
	from the value.

	- `[property: string] = state : Has<T>`
		- Updates the property of `instance` to the latest value from `state`

	- `state : Has<Instance>` (there is no key, i.e., the key is an integer)
		- Parent the emitted Instances to `instance`

	In the following cases, the key represents something that should be handled by the value.
	The value should be a function, or a stateful object to assign new values
	(see toHandler). We will refer to such values with CanHandle<T...> (not a formal type).

	- `[eventName: string] = value : CanHandle<T...>`
		where `instance[eventName]` is an R`BXScriptSignal<T...>`
		- Connects `toHandler(value)` to the signal.
	- `[signal: RBXScriptSignal<T...>] = value : CanHandle<T...>`
		- Connects `toHandler(value)` to the signal.
	- `["instance"] = value` : CanHandle<Instance>
		- Calls the `toHandler(value)` with the instance, and adds the returned cleanup task to the cleanup array.
		- If the `toHandler(value)` returns a cleanup task, it will be added to the cleanup array.

	Attach any extra CleanupTasks using the "cleanup" key.
	- `["cleanup"] = cleanupTask : CleanupTask`
		- Adds the cleanup task to the cleanup array.

	Some examples:
	- `[U.property "AbsoluteSize"] = state : Value<Vector2>
		- Passes current and future values of instance.AbsoluteSize to state:SetValue(_)
]]
function U.mount(instance: Instance, mountProps: {[any]: any}): CleanupTask?
	assert(typeof(instance) == "Instance", "[U.mount] Bad instance")

	local cleanup = {}
	local parent = nil

	if mountProps.overwrite ~= nil then
		if typeof(mountProps.overwrite) ~= "table" then
			error(`[U.mount] Expected mountProps.overwrite to be a table, got a {typeof(mountProps.overwrite)} ({mountProps.overwrite})`)
		end
		if next(mountProps.overwrite) ~= nil then
			mergeOverwrites(mountProps.overwrite, mountProps)
		end
		mountProps.overwrite = nil
	end
	
	for key: any, value in mountProps do
		
		if key == "Parent" then
			-- Delay parenting
			parent = value
			continue
		end

		-- Case: String key refers to a property or signal of `instance`
		if typeof(key) == "string" then

			-- Case: we are providing the instance to the users handler, possibly receiving a CleanupTask
			if key == "instance" then
				local handler = toHandler(value) :: ((...any) -> CleanupTask) | nil
				if handler == nil then
					error(`[U.mount] Expected handler for {instance}, got a {typeof(value)} ({value})`)
				else
					table.insert(cleanup, handler(instance))
				end

			-- Case: User is providing some cleanup
			elseif key == "cleanup" then
				table.insert(cleanup, value)

			else
				-- If the line below errors, then the key is not a valid property or signal of `instance`
				local keyVal = (instance :: any)[key]

				-- Case: we are connecting a handler to an event of the instance
				if typeof(keyVal) == "RBXScriptSignal" then
					local handler = toHandler(value)
					if handler == nil then
						error(`[U.mount] Expected handler for {instance}.{key}, got a {typeof(value)} ({value})`)
					end
					table.insert(cleanup, keyVal:Connect(toHandler(value)))
				
				-- Case: we are mounting `value` to `instance[key]`.
				else
					-- `value` should encapsulate some (possibly) stateful property,
					-- either a stream, ValueBase, or just a plain value
					
					if typeof(value) == "function" then
						-- assume it's a stream
						local stream: Stream<any> = U.toStream(value)
						table.insert(cleanup, stream(function(x: any)
							(instance :: any)[key] = x
						end))
					elseif typeof(value) == "Instance" and value:IsA("ValueBase") then
						(instance :: any)[key] = (value :: any).Value
						table.insert(cleanup, (value :: any).Changed:Connect(function(newValue)
							(instance :: any)[key] = newValue
						end))
					else
						(instance :: any)[key] = value
					end
				end
			end

		-- Case: Numeric key means value is/emits a child instance,
		-- or is a table of more props
		elseif typeof(key) == "number" then

			if typeof(value) == "function" then
				-- assume it's a (possibly nested) stream of instances (or instances wrapped in state)
				table.insert(cleanup, value(function(child: Instance?)
					if child then
						child.Parent = instance
					end
				end))

			elseif typeof(value) == "Instance" then
				-- Children are cleaned up on destroy. This also triggers them to cleanup
				-- whatever they have mounted.
				value.Parent = instance

			elseif typeof(value) == "table" then

				-- Assume it's more props just dumped into the table
				if getmetatable(value) ~= nil then
					error(`[U.mount] sub-mountProps table entry has a metatable, cannot mount. Table: {value}`)
				end
				table.insert(cleanup, U.mount(instance, value))

			else
				error(`Bad child {value} of type {value}`)
			end

		-- Case: It's a stream
		elseif typeof(key) == "function" then
			local handler = toHandler(value)
			if handler == nil then
				error(`[U.mount] Expected handler for stream returned by key-function, got a {typeof(value)} ({value})`)
			end
			table.insert(cleanup, key(handler))

		-- Case: key is a signal, value is a handler
		elseif typeof(key) == "RBXScriptSignal" 
				or typeof(key) == "table" and typeof((key).Connect) == "function" then
			local handler = toHandler(value)
			if handler == nil then
				error(`[U.mount] Expected handler for signal {key}, got a {typeof(value)} ({value})`)
			end
			table.insert(cleanup, key:Connect(handler))

		-- Case: We don't understand the key, just give it to the handler
		else
			local handler = toHandler(value)
			if handler == nil then
				error(`[U.mount] {typeof(value)} value ({value}) could not be converted to a handler for {typeof(key)} key`)
			else
				table.insert(cleanup, handler(key))
			end
		end
	end

	if parent then
		-- Now do delayed parenting
		if typeof(parent) == "Instance" then
			instance.Parent = parent
		else
			table.insert(cleanup, U.toStream(parent)(function(newParent)
				if typeof(newParent) == "Instance" or newParent == nil then
					instance.Parent = newParent
				else
					error(`[U.mount] Expected newParent to be an Instance or nil, got a {typeof(newParent)} ({newParent})`)
				end
			end))
		end
	end

	-- Lean cleanup
	if #cleanup == 0 then
		return nil
	elseif #cleanup == 1 then
		return cleanup[1]
	else
		return cleanup
	end
end

--[[
	Mount props to an instance for the lifetime of the instance.
]]
function U.bind(instance: Instance, props: {[any]: any}): ()

	for key, value in props do
		-- Connect instance signals without the uneccessary cleanup-logic that
		-- mount would do
		if typeof(key) == "string" then
			local keyVal = (instance :: any)[key]
			if typeof(keyVal) == "RBXScriptSignal" then
				-- This is the same as the mount logic, but we don't add anything to a cleanup table
				local handler = toHandler(value)
				if handler == nil then
					error(`[U.new] Expected handler for {instance}.{key}, got a {typeof(value)} ({value})`)
				end
				keyVal:Connect(toHandler(value))
				props[key] = nil -- this is okay according to lua docs
			end
		end
	end

	local cleanup = U.mount(instance, props)
	if cleanup ~= nil then
		instance.Destroying:Once(function()
			U.clean(cleanup)
			cleanup = nil
		end)
	end
end

local defaultProps = {
	ScreenGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = "Sibling"
	},

	BillboardGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = "Sibling"
	},

	SurfaceGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = "Sibling",

		SizingMode = "PixelsPerStud",
		PixelsPerStud = 50
	},

	Frame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	},

	ScrollingFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		ScrollBarImageColor3 = Color3.new(0, 0, 0)
	},

	TextLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		Font = "SourceSans",
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		AutoButtonColor = false,

		Font = "SourceSans",
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextBox = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		ClearTextOnFocus = false,

		Font = "SourceSans",
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	ImageLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	},

	ImageButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		AutoButtonColor = false
	},

	ViewportFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	},

	VideoFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	},

	UIListLayout = {
		SortOrder = Enum.SortOrder.LayoutOrder;
	},
}

--[[
	U.new(className) is approximately this function:
	```lua
	function(props)
		local instance = Instance.new(className)
		U.bind(instance, props)
		return instance
	end
	```
	The difference is that the props table is pre-processed before binding.
	If `props[key] == value` and `key` is a function, then we set
	`props[key] = nil` and `props[key(instance)] = value`. We call key(instance)
	the "real key". This allows the caller of `U.new` to make prop-keys that 
	depend on the instance, such as `instance:GetPropertyChangedSignal("Name")`.
]]
function U.new(className: string): (props: {[any]: any}) -> Instance
	return function(props)
		local instance = Instance.new(className)

		if defaultProps[className] then
			for key, value in defaultProps[className] do
				(instance :: any)[key] = value
			end
		end

		-- Turn function keys into "real keys"
		local usingInstance = nil
		for key, value in props do
			if typeof(key) == "function" then
				if usingInstance == nil then
					usingInstance = {}
				end
				local realKey = key(instance)
				if realKey == nil then
					error("Expected key-function to return non-nil key")
				end
				usingInstance[key(instance)] = value
				props[key] = nil -- this is okay according to lua docs
			end
		end

		if usingInstance ~= nil then
			for key, value in usingInstance do
				props[key] = value
			end
		end

		U.bind(instance, props)
		return instance
	end
end

--[[
	U.property(name)(instance) is `Stream.propertyOf(name, instance)`, i.e.
	as stream of the latest value of instance[name]
	Use `[U.property "<name>"] = handler` in the props table of `U.new`, `U.bind`,
	or `U.mount` to listen to a property of an instance, where `handler` is 
	convertible to a function of type `(value: any) -> ()` (see `toHandler`)
	Example:
	```lua
	local cleanup = {}
	local AbsoluteSize = U.Value(cleanup, Vector2.new(0,0))
	local button = U.new "TextLabel" {
		Text = U.concat {"AbsoluteSize=", AbsoluteSize},
		[U.property "AbsoluteSize"] = AbsoluteSize,
		[U.property "Text"] = function(text)
			print("Text is now: ", text)
		end),
	}
	```
]]
function U.property(name: string): (instance: Instance) -> Stream<any>
	return function(instance)
		return Stream.propertyOf(instance, name)
	end
end

--[[
	`U.attribute(name)(instance)` is `Stream.attributeOf(name, instance)`, i.e.
	as stream of the latest value of instance[name]
	Use `[U.property "<name>"] = handler` in the props table of `U.new`, `U.bind`,
	or `U.mount` to listen to a property of an instance, where `handler` is 
	convertible to a function of type `(value: any) -> ()` (see `toHandler`)
	Example:
	```lua
	local button = U.new "Part" {
		[U.attribute "Damage"] = function(damage)
			print("Damage is now: ", damage)
		end),
	}
	```
]]
function U.attribute(name: string): (instance: Instance) -> Stream<any>
	return function(instance)
		return Stream.attributeOf(instance, name)
	end
end

--[[
	Usage: `U.compute(a,b,c,d,...,fn)`, where `a,b,c,d,...` have type `Has<A>`,
	`Has<B>` ... etc, and `fn` is a function of type `(A,B,C,D,...) -> Z`.
	1. Converts the first n-1 args to streams with `U.toStream`.
	2. Combines their latest values with `combineLatest` and passes them to `fn`.
]]
function U.compute(...): Stream<any>
	local args = {...}
	local n = select("#", ...)
	local fn = args[n]

	if typeof(fn) ~= "function" then
		error(`[U.compute] Last argument must be a function, got a {typeof(fn)}`)
	end

	local streams = {}
	for i=1, n-1 do
		table.insert(streams, U.toStream(args[i]))
	end
	if n == 1 then
		-- Calls `fn` with no arguments when the stream is listened to.
		return Stream.map(fn)(Stream.of())
	elseif n == 2 then
		return Stream.map(fn)(streams[1])
	else
		return Stream.map(function(values)
			return fn(table.unpack(values))
		end)(Stream.combineLatest(streams, true))
	end
end

--[[
	Generalises `table.concat` to take an array of `Has<any>` arguments
	Using `U.compute`, the result is a stream of strings from `table.concat` applied to the
	latest emitted values of the input arguments.
	Usage: `U.concat({a,b,c,...}, sep, i, j)` where `a,b,c,...` have type `Has<any>`.
]]
function U.concat(t: {Has<any>}, sep: string?, i: number?, j: number?)
	local args = table.create(#t+1)
	table.move(t, 1, #t, 1, args)
	table.insert(args, function(...)
		return table.concat({...}, sep, i, j)
	end)
	return U.compute(table.unpack(args))
end

--[[
	Generalises `string.format` to take an array of `Has<any>` arguments
	Using `U.compute`, the result is a stream of strings from `string.format` applied to the
	latest emitted values of the input arguments.
	Usage: `U.format(fmt, a,b,c,...)` where `a,b,c,...` have type `Has<any>`.
]]
function U.format(fmt: string, ... : Has<any>)
	local args = {...}
	table.insert(args, function(...)
		return string.format(fmt, ...)
	end)
	return U.compute(table.unpack(args))
end

--[[
	Usage `U.compute1(a,fn)`.
	- Converts `a` to a `Stream<A>` with `U.toStream` and then maps `fn` over the combined stream
	of their latest values.
	- Useful in `mount` and `new`
	Example:
	```lua
	-- Here Name can be any `Has<string>`, such as a `StringValue` or a `Stream<string>` or a `string`.
	local Name = Instance.new("StringValue")
	U.new "TextLabel" {
		Text = U.compute1(Name, function(name: string)
			return `Hello {name}!`
		)
	}
	```
]]
function U.compute1<A,Z>(a : Has<A>, fn : (A) -> Z): Stream<Z>
	return Stream.map(fn)(U.toStream(a))
end

--[[
	Usage `U.compute2(a,b,fn)`.
	- Converts `a`, `b` into `Stream<A>`, `Stream<B>` with `U.toStream` and then maps `fn` over the combined stream
	of their latest values.
	- Useful in `mount` and `new`
	Example:
	```lua
	local IsHovering = U.Value(cleanup, false)
	local IsPressed = U.Value(cleanup, false)
	return new "TextButton" {
		Size = U.compute2(IsHovering, IsPressed, function(isHovering, isPressed)
			if isHovering and not isPressed then
				return UDim2.new(1,2,1,2)
			else
				return UDim2.new(1,0,1,0)
			end
		end),

		Text = U.compute1(IsPressed, function(isPressed)
			return isPressed and "Pressed" or "Not Pressed"
		end),

		MouseEnter = function() IsHovering.Value = true end,
		MouseLeave = function() IsHovering.Value = false end,
		MouseButton1Down = function() IsPressed.Value = true end,
		MouseButton1Up = function() IsPressed.Value = false end,
	}
	```
]]
function U.compute2<A,B,Z>(a : Has<A>, b : Has<B>, fn : (A,B) -> Z): Stream<Z>
	return Stream.combine2(U.toStream(a), U.toStream(b), fn)
end

--[[
	Usage `U.compute3(a,b,c,fn)`.
	- Converts `a`, `b`, `c` into `Stream<A>`, `Stream<B>`, `Stream<C>`
	with `U.toStream` and then maps `fn` over the combined stream of their latest values.
	- Useful in `mount` and `new`
	- See `U.compute2` for an example with two "Has" args.
]]
function U.compute3<A,B,C,Z>(a : Has<A>, b : Has<B>, c : Has<C>, fn : (A,B,C) -> Z): Stream<Z>
	return Stream.combine3(U.toStream(a), U.toStream(b), U.toStream(c), fn)
end

--[[
	Usage `U.compute4(a,b,c,d,fn)`.
	- Converts `a`, `b`, `c`, `d` into `Stream<A>`, `Stream<B>`, `Stream<C>`, `Stream<D>`
	with `U.toStream` and then maps `fn` over the combined stream of their latest values.
	- Useful in `mount` and `new`
	- See `U.compute2` for an example with two "Has" args.
]]
function U.compute4<A,B,C,D,Z>(a : Has<A>, b : Has<B>, c : Has<C>, d : Has<D>, fn : (A,B,C,D) -> Z): Stream<Z>
	return Stream.combine4(U.toStream(a), U.toStream(b), U.toStream(c), U.toStream(d), fn)
end

return U