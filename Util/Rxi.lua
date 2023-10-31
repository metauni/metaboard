local Maid = require(script.Parent.Maid)
local Rx = require(script.Parent.Rx)
local Brio = require(script.Parent.Brio)

-- Rxi provides Rx primitives for producing live queries of instances.
--
-- In general, observables will emit nothing (that is, an empty tuple) when a
-- value is no longer observed.
local export = {}

local UNSET = newproxy()

-- Returns an observer that fires with no values, then completes.
local function nilobs()
	return Rx.observable(function(sub)
		sub:Fire()
		sub:Complete()
	end)
end

-- Returns an observable that emits the given instance, or nothing if it is not
-- an instance.
function export.of(instance: Instance): Rx.Observable
	if typeof(instance) ~= "Instance" then
		return nilobs()
	end
	return Rx.observable(function(sub)
		sub:Fire(instance)
		sub:Complete()
	end)
end

-- Stops the chain unless the value is not nil.
function export.notNil(): Rx.Transformer
	return Rx.where(function(value)
		return value ~= nil
	end)
end

-- Emits the value if it is of type *t*, or nothing otherwise.
function export.isTypeOf(t: string)
	return Rx.whereElse(function(value)
		return typeof(value) == t
	end)
end

-- Emits the value if it is an instance of class *c*, or nothing otherwise.
function export.isClass(c: string)
	return Rx.whereElse(function(value)
		return typeof(value) == "Instance" and value.ClassName == c
	end)
end

-- Emits the value if it is an instance inheriting class *c*, or nothing
-- otherwise.
function export.isClassOf(c: string)
	return Rx.whereElse(function(value)
		return typeof(value) == "Instance" and value:IsA(c)
	end)
end

-- Emits the value if it is an item of enum *e*, or nothing otherwise.
function export.isEnum(e: Enum)
	return Rx.whereElse(function(value)
		return typeof(value) == "EnumItem" and value.EnumType == e
	end)
end

-- Emits the value if it is an array where each element is of type *t*, or
-- nothing otherwise.
function export.isArrayOf(t: string)
	return Rx.whereElse(function(value)
		if type(value) ~= "table" then
			return false
		end
		for _, v in value do
			if typeof(v) ~= t then
				return false
			end
		end
		return true
	end)
end

-- Returns whether *instance* has *property*.
local function hasProperty(instance, property)
	return (pcall(instance.GetPropertyChangedSignal, instance, property))
end

-- Observes a property of a held instance (use Rxi.property to chain to observed instance)
function export.propertyOf(instance: Instance, property: string): Rx.Observable
	assert(typeof(instance) == "Instance", "Bad instance")
	return Rx.observable(function(sub)
		if not hasProperty(instance, property) then
			sub:Fire()
			sub:Complete()
			return
		end
		local conn = instance:GetPropertyChangedSignal(property):Connect(function()
			sub:Fire((instance::any)[property])
		end)
		sub:Fire((instance::any)[property])
		return conn
	end)
end

-- Observes from the first value the property named *property*. Emits nothing
-- while getting the property produces an error, or the first value is not an
-- Instance.
function export.property(property: string): Rx.Transformer
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance: Instance)
			if not instance then return nilobs() end
			return export.propertyOf(instance, property)
		end),
	}
end

-- Observes from the first value the attribute named *attribute*. Emits nothing
-- while the first value is not an Instance.
function export.attributeOf(instance: Instance, attribute: string): Rx.Observable
	return Rx.observable(function(sub)
		local conn = instance:GetAttributeChangedSignal(attribute):Connect(function()
			sub:Fire(instance:GetAttribute(attribute))
		end)
		sub:Fire(instance:GetAttribute(attribute))
		return conn
	end)
end

-- Observes from the first value the attribute named *attribute*. Emits nothing
-- while the first value is not an Instance.
function export.attribute(attribute: string): Rx.Transformer
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance: Instance)
			if not instance then return nilobs() end
			return export.attributeOf(instance, attribute)
		end),
	}
end

-- Observes from the first value the first child where the Name property equals
-- *name*. Emits nothing while no child is found, or the first value is not an
-- Instance.
function export.findFirstChild(name: string)
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current = UNSET
				local function updateCurrent(child)
					local next = instance:FindFirstChild(name)
					if next ~= current then
						current = next
						sub:Fire(current)
					end
				end
				maid.connAdded = instance.ChildAdded:Connect(function(child)
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
					updateCurrent()
				end)
				maid.connRemoved = instance.ChildRemoved:Connect(function(child)
					maid[child] = nil
					updateCurrent()
				end)
				for i, child in instance:GetChildren() do
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
				end
				updateCurrent()
				return maid
			end)
		end),
	}
end

-- Observes from the first value the first child where the Name property equals
-- *name* and ClassName equals *className*. Emits nothing while no child is
-- found, or the first value is not an Instance.
function export.findFirstChildWithClass(className: string, name: string)
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current = UNSET
				local function updateCurrent()
					local next
					for _, child in instance:GetChildren() do
						if child.ClassName == className and child.Name == name then
							next = child
							break
						end
					end
					if next ~= current then
						current = next
						sub:Fire(current)
					end
				end
				maid.connAdded = instance.ChildAdded:Connect(function(child)
					if child.ClassName ~= className then return end
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
					updateCurrent()
				end)
				maid.connRemoved = instance.ChildRemoved:Connect(function(child)
					if child.ClassName ~= className then return end
					maid[child] = nil
					updateCurrent()
				end)
				for i, child in instance:GetChildren() do
					if child.ClassName ~= className then continue end
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
				end
				updateCurrent()
				return maid
			end)
		end)
	}
end

-- Observes from the first value the first child where the Name property equals
-- *name* and ClassName inherits *className*. Emits nothing while no child is
-- found, or the first value is not an Instance.
function export.findFirstChildWithClassOf(className: string, name: string)
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current = UNSET
				local function updateCurrent()
					local next
					for _, child in instance:GetChildren() do
						if child:IsA(className) and child.Name == name then
							next = child
							break
						end
					end
					if next ~= current then
						current = next
						sub:Fire(current)
					end
				end
				maid.connAdded = instance.ChildAdded:Connect(function(child)
					if not child:IsA(className) then return end
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
					updateCurrent()
				end)
				maid.connRemoved = instance.ChildRemoved:Connect(function(child)
					if not child:IsA(className) then return end
					maid[child] = nil
					updateCurrent()
				end)
				for i, child in instance:GetChildren() do
					if not child:IsA(className) then continue end
					maid[child] = child:GetPropertyChangedSignal("Name"):Connect(function()
						updateCurrent()
					end)
				end
				updateCurrent()
				return maid
			end)
		end)
	}
end

-- Observes from the first value the first child where the ClassName property
-- equals *className*. Emits nothing while no child is found, or the first value
-- is not an Instance.
function export.findFirstChildOfClass(className: string)
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current = UNSET
				local function updateCurrent()
					local next = instance:FindFirstChildOfClass(className)
					if next ~= current then
						current = next
						sub:Fire(current)
					end
				end
				maid.connAdded = instance.ChildAdded:Connect(updateCurrent)
				maid.connRemoved = instance.ChildRemoved:Connect(updateCurrent)
				updateCurrent()
				return maid
			end)
		end),
	}
end

-- Observes from the first value the first child where the ClassName property
-- inherits from *className*. Emits nothing while no child is found, or the
-- first value is not an Instance.
function export.findFirstChildWhichIsA(className: string)
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current = UNSET
				local function updateCurrent()
					local next = instance:FindFirstChildWhichIsA(className)
					if next ~= current then
						current = next
						sub:Fire(current)
					end
				end
				maid.connAdded = instance.ChildAdded:Connect(updateCurrent)
				maid.connRemoved = instance.ChildRemoved:Connect(updateCurrent)
				updateCurrent()
				return maid
			end)
		end),
	}
end

-- Observes the children of the first value. Emits nothing while the first value
-- is not an Instance.
function export.children()
	return Rx.pipe{
		export.isTypeOf("Instance"),
		Rx.switchMap(function(instance)
			if not instance then return nilobs() end
			return Rx.observable(function(sub)
				local maid = Maid.new()
				local current
				local function updateCurrent()
					current = instance:GetChildren()
					sub:Fire(current)
				end
				maid.connAdded = instance.ChildAdded:Connect(updateCurrent)
				maid.connRemoved = instance.ChildRemoved:Connect(updateCurrent)
				updateCurrent()
				return maid
			end)
		end),
	}
end

--------------------------------------------------------------------------------
-- metauni ADDITIONS
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

function export.tagged(tag: string): Rx.Observable
	return Rx.concat({
		Rx.from(CollectionService:GetTagged(tag)),
		Rx.fromSignal(CollectionService:GetInstanceAddedSignal(tag)),
	})
end

function export.untagged(tag: string): Rx.Observable
	return Rx.fromSignal(CollectionService:GetInstanceRemovedSignal(tag))
end

function export.playerLifetime(): Rx.Observable
	return Rx.concat {
		Rx.from(Players:GetPlayers()):Pipe{
			Rx.map(function(player: Player)
				return player, true
			end)
		},
		Rx.merge {
			Rx.fromSignal(Players.PlayerAdded):Pipe {
				Rx.map(function(player: Player)
					return player, true
				end)
			},
			Rx.fromSignal(Players.PlayerRemoving):Pipe {
				Rx.map(function(player: Player)
					return player, false
				end)
			},
		}
	}
end

--[=[
	Observes the children with a specific name.

	@param parent Instance
	@param className string
	@param name string
	@return Observable<Brio<Instance>>
]=]
function export.childrenOfNameBrio(parent, className, name)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(className) == "string", "Bad className")
	assert(type(name) == "string", "Bad name")

	return Rx.observable(function(sub)
		local topMaid = Maid.new()

		local function handleChild(child)
			if not child:IsA(className) then
				return
			end

			local maid = Maid.new()

			local function handleNameChanged()
				if child.Name == name then
					local brio = Brio.new(child)
					maid._brio = brio

					sub:Fire(brio)
				else
					maid._brio = nil
				end
			end

			topMaid[child] = maid

			maid:GiveTask(child:GetPropertyChangedSignal("Name"):Connect(handleNameChanged))
			handleNameChanged()
		end

		topMaid:GiveTask(parent.ChildAdded:Connect(handleChild))
		topMaid:GiveTask(parent.ChildRemoved:Connect(function(child)
			topMaid[child] = nil
		end))

		for _, child in pairs(parent:GetChildren()) do
			handleChild(child)
		end

		return topMaid
	end)
end

return table.freeze(export)
