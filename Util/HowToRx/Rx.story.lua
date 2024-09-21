--[[
	This is an abbreviated implementation of the internals of Rx.
	Use this to construct a mental model of what an observable is.

	Run the examples by choosing an example at the bottom of this file,
	then click on this story file in Hoarcekat.
]]

type CleanupFn = () -> ()

type Subscriber<T> = {
	Fire: (self: Subscriber<T>, T) -> (),
	-- In Real Rx, there is also Fail and Complete here
}

type Observable<T> = {
	Subscribe: (self: Observable<T>, onFire: (T) -> ()) -> CleanupFn,
	-- Actually returns Observable<U> if that's what the last transformer returns
	Pipe: (self: Observable<T>, transformers: {Transformer}) -> any
}

-- It's really (Observable<T>) -> Observable<U> but luau doesn't like recursive types
type Transformer = (any) -> any

--[[ Example
	Suppose the following have types
		src: Observable<A>
		t1: Observable<A> -> Observable<B>
		t2: Observable<B> -> Observable<C>

	Then Pipe(src, {t1, t2}): Observable<C>, and its equivalent to t2(t1(src))
]]
local function Pipe<T, U>(source: Observable<T>, transformers: {Transformer}): Observable<U>
	local current = source
	for _, transformer in transformers do
		current = transformer(current)
	end
	return current
end

local function observable<T>(onSubscribe: (Subscriber<T>) -> CleanupFn?): Observable<T>
	return {
		Subscribe = function(self, onFire: (T) -> ())
			local cleanup = onSubscribe({
				Fire = function(_, value)
					onFire(value)
				end,
			})
			return cleanup or function() end
		end,
		Pipe = (Pipe :: any),
	}
end

local observeStuff: Observable<number> = observable(function(sub: Subscriber<number>)
	
	local thread = task.spawn(function()
		for i=1, 3 do
			sub:Fire(i)
		end
		task.wait(1)
		sub:Fire(4)
		task.wait(1)
		sub:Fire(5)
		task.wait(3)
		sub:Fire(6)
	end)

	return function()
		print("observeStuff cleanup")
		task.cancel(thread)
	end
end)

local function map<T, U>(project: (T) -> U): (Observable<T>) -> Observable<U>
	-- return a transformer
	return function(source: Observable<T>)
		-- return the transformed observable
		return observable(function(sub: Subscriber<U>)
			-- return the cleanup function
			return source:Subscribe(function(value: T)
				sub:Fire(project(value))
			end)
		end)
	end
end

local function switchMap<T,U>(project: (T) -> Observable<U>): (Observable<T>) -> Observable<U>
	return function(source: Observable<T>)
		return observable(function(sub: Subscriber<U>)
			local innerCleanup

			local outerCleanup = source:Subscribe(function(tValue: T)
				if innerCleanup then
					innerCleanup()
					innerCleanup = nil
				end
				innerCleanup = project(tValue):Subscribe(function(uValue: U)
					sub:Fire(uValue)
				end)
			end)
			return function()
				if innerCleanup then
					innerCleanup()
					innerCleanup = nil
				end
				outerCleanup()
			end
		end)
	end
end

local function example1()
	
	local cleanup = observeStuff:Pipe {
		map(function(value)
			return value * 2
		end),
		map(function(value)
			return value + 1
		end),
	}:Subscribe(function(value)
		print(value)
	end)
	
	print("After subscribe")
	
	return cleanup
end

local function example2()

	local function project(value)
		return observable(function(sub)
			local thread = task.spawn(function()
				for i = string.byte("a"), string.byte("h") do
					sub:Fire(string.char(i))
					task.wait(0.5)
				end
			end)
		
			return function()
				print("inner cleanup", value)
				task.cancel(thread)
			end
		end)
	end
	
	local cleanup = observeStuff:Pipe {
		switchMap(function(value)
			return project(value):Pipe {
				map(function(innerValue)
					return value..innerValue
				end)
			}
		end)
	}:Subscribe(print)

	return cleanup
end

-- Hoarcekat calls this function when you click on Rx
return function()
	
	-- This runs the example and then gives the cleanup function to Hoarcekat
	-- Pick one of them to uncomment

	-- return example1()
	-- return example2()
end
