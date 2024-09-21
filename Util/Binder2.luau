local GoodSignal = require(script.Parent.GoodSignal)
local Stream = require(script.Parent.Stream)

export type Signal<T...> = GoodSignal.Signal<T...>
export type Stream<T...> = Stream.Stream<T...>

export type Binder<T> = {
	Map: {[Instance]: T},
	Tag: string,
	Constructor: (Instance) -> T,
	Changed: Signal<Instance,T?>,

	Get: (self: Binder<T>, instance: Instance) -> T?,
	Bind: (self: Binder<T>, instance: Instance) -> T,
	Delete: (self: Binder<T>, instance: Instance) -> (),
	StreamPairs: (self: Binder<T>) -> Stream<Instance,T?>,
	Destroy: (self: Binder<T>) -> (),
}

local Binder = {}
Binder.__index = Binder
Binder.ClassName = "Binder"

function Binder.Get<T>(self: Binder<T>, instance: Instance): T?
	return self.Map[instance]
end

function Binder.Bind<T>(self: Binder<T>, instance: Instance): T
	instance:AddTag(self.Tag)

	-- won't be created already if in deferred mode
	local existing = self.Map[instance]
	if existing then
		return existing
	end

	local object = self.Constructor(instance)

	self.Map[instance] = object
	task.defer(function()
		self.Changed:Fire(instance, object)
	end)
	return object
end

function Binder.Delete<T>(self: Binder<T>, instance: Instance)
	instance:RemoveTag(self.Tag)

	-- won't be destroyed already if in deferred mode
	local existing = self.Map[instance]
	if existing ~= nil then
		self.Map[instance] = nil
		task.defer(function()
			self.Changed:Fire(instance, nil)
		end)
	end
end

function Binder.StreamPairs<T>(self: Binder<T>): Stream<Instance,T?>
	return (self :: any)._stream
end

function Binder.ListenTidyPairs<T>(self: Binder<T>, tidyListener: (Instance, T) -> Stream.CleanupTask): Stream.CleanupTask
	return Stream.listenTidyPairs((self :: any)._stream, tidyListener)
end

function Binder.Destroy<T>(self: Binder<T>)
	self.Changed:Destroy()
	Stream.clean((self :: any)._cleanupTagListener)
	table.clear(self)
	setmetatable(self, nil)
end

table.freeze(Binder)

return function<T>(tag: string, ancestor: Instance?, constructor: (Instance) -> T): Binder<T>
	local self = {
		Map = {},
		Tag = tag,
		Constructor = constructor,
		Changed = GoodSignal.new(),
	}

	self._stream = function(listener)
		for instance, object in self.Map do
			listener(instance, object)
		end
		return self.Changed:Connect(listener)
	end :: Stream<Instance,T?>

	self._cleanupTagListener = Stream.eachTagged(tag, ancestor)(function(instance, isTagged)
		local existing = self.Map[instance]
		if existing == nil and isTagged then
			local object = constructor(instance)
			self.Map[instance] = object
			self.Changed:Fire(instance, object)
		elseif existing ~= nil and not isTagged then
			self.Map[instance] = nil
			Stream.clean(existing)
			self.Changed:Fire(instance, nil)
		end
	end)

	return setmetatable(self, Binder) :: any
end