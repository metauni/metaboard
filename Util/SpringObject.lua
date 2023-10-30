--[=[
	@class SpringObject
]=]

local RunService = game:GetService("RunService")

local Spring = require(script.Parent.Spring)
local Maid = require(script.Parent.Maid)
local GoodSignal = require(script.Parent.GoodSignal)
local StepUtils = require(script.Parent.StepUtils)
local Blend = require(script.Parent.Blend)
local Rx = require(script.Parent.Rx)
local Promise = require(script.Parent.Promise)

local SpringObject = {}
SpringObject.ClassName = "SpringObject"
SpringObject.__index = SpringObject

--[=[
	Constructs a new SpringObject.
	@param target T
	@param speed number | Observable<number> | ValueObject<number> | NumberValue | any
	@param damper number | Observable<number> | NumberValue | any
	@return Spring<T>
]=]
function SpringObject.new(target, speed, damper)
	local self = setmetatable({
		_maid = Maid.new();
		_epsilon = 1e-6;
		Changed = GoodSignal.new();
	}, SpringObject)

--[=[
	Event fires when the spring value changes
	@prop Changed Signal<()> -- Fires whenever the spring initially changes state
	@within SpringObject
]=]
	self._maid:GiveTask(self.Changed)

	if target then
		self.Target = target
	else
		self:_getSpringForType(0)
	end

	if speed then
		self.Speed = speed
	end

	if damper then
		self.Damper = damper
	end

	return self
end

--[=[
	Returns whether an object is a SpringObject.
	@param value any
	@return boolean
]=]
function SpringObject.isSpringObject(value)
	return type(value) == "table" and getmetatable(value) == SpringObject
end

--[=[
	Observes the spring animating
	@return Observable<T>
]=]
function SpringObject:ObserveRenderStepped()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

--[=[
	Alias for [ObserveRenderStepped]

	@return Observable<T>
]=]
function SpringObject:Observe()
	return self:ObserveRenderStepped()
end

--[=[
	Observes the current target of the spring

	@return Observable<T>
]=]
function SpringObject:ObserveTarget()
	return Rx.observable(function(sub)
		local maid = Maid.new()

		local lastTarget = self.Target

		maid:GiveTask(self.Changed:Connect(function()
			local target = self.Target
			if lastTarget ~= target then
				lastTarget = target
				sub:Fire(target)
			end
		end))

		sub:Fire(lastTarget)

		return maid
	end)
end

function SpringObject:ObserveVelocityOnRenderStepped()
	return self:ObserveVelocityOnSignal(RunService.RenderStepped)
end

--[=[
	Promises that the spring is done, based upon the animating property
	Relatively expensive.

	@param signal RBXScriptSignal | nil
	@return Observable<T>
]=]
function SpringObject:PromiseFinished(signal)
	signal = signal or RunService.RenderStepped

	local maid = Maid.new()
	local promise = Promise.new()
	maid:GiveTask(promise)

	-- TODO: Mathematical solution?
	local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
		local animating = self._currentSpring:Animating(self._epsilon)
		if not animating then
			promise:Resolve(true)
		end
		return animating
	end)

	maid:GiveTask(stopAnimate)
	maid:GiveTask(self.Changed:Connect(startAnimate))
	startAnimate()

	self._maid[promise] = maid

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	maid:GiveTask(function()
		self._maid[promise] = nil
	end)

	return promise
end

function SpringObject:ObserveVelocityOnSignal(signal)
	return Rx.observable(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local animating = self._currentSpring:Animating(self._epsilon)
			if animating then
				sub:Fire(Spring.fromLinearIfNeeded(self._currentSpring.Velocity))
			else
				sub:Fire(Spring.fromLinearIfNeeded(0*self._currentSpring.Velocity))
			end
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Observes the spring animating
	@param signal RBXScriptSignal
	@return Observable<T>
]=]
function SpringObject:ObserveOnSignal(signal)
	return Rx.observable(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local animating, position = self._currentSpring:Animating(self._epsilon)
			sub:Fire(Spring.fromLinearIfNeeded(position))
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Returns true when we're animating
	@return boolean -- True if animating
]=]
function SpringObject:IsAnimating()
	return (self._currentSpring:Animating(self._epsilon))
end

--[=[
	Impulses the spring, increasing velocity by the amount given. This is useful to make something shake,
	like a Mac password box failing.

	@param velocity T -- The velocity to impulse with
	@return ()
]=]
function SpringObject:Impulse(velocity)
	self._currentSpring:Impulse(Spring.toLinearIfNeeded(velocity))
	self.Changed:Fire()
end

--[=[
	Sets the actual target. If doNotAnimate is set, then animation will be skipped.

	@param value T -- The target to set
	@param doNotAnimate boolean? -- Whether or not to animate
	@return ()
]=]
function SpringObject:SetTarget(value, doNotAnimate)
	local observable = Blend.toPropertyObservable(value) or Rx.of(value)

	if doNotAnimate then
		local isFirst = true

		self._maid._targetSub = observable:Subscribe(function(unconverted)
			local converted = Spring.toLinearIfNeeded(unconverted)
			local spring = self:_getSpringForType(converted)
			spring.Target = converted

			if isFirst then
				spring.Position = converted
				spring.Velocity = 0*converted
			end

			self.Changed:Fire()
		end)
	else
		self._maid._targetSub = observable:Subscribe(function(unconverted)
			local converted = Spring.toLinearIfNeeded(unconverted)
			self:_getSpringForType(converted).Target = converted

			self.Changed:Fire()
		end)
	end
end

--[=[
	Instantly skips the spring forwards by that amount time
	@param delta number -- Time to skip forwards
	@return ()
]=]
function SpringObject:TimeSkip(delta)
	assert(type(delta) == "number", "Bad delta")

	self._currentSpring:TimeSkip(delta)
	self.Changed:Fire()
end

function SpringObject:__index(index)
	if index == "Value" or index == "Position" or index == "p" then
		return Spring.fromLinearIfNeeded(self._currentSpring.Value)
	elseif index == "Velocity" or index == "v" then
		return Spring.fromLinearIfNeeded(self._currentSpring.Velocity)
	elseif index == "Target" or index == "t" then
		return Spring.fromLinearIfNeeded(self._currentSpring.Target)
	elseif index == "Damper" or index == "d" then
		return self._currentSpring.Damper
	elseif index == "Speed" or index == "s" then
		return self._currentSpring.Speed
	elseif index == "Clock" then
		return self._currentSpring.Clock
	elseif index == "Epsilon" then
		return self._epsilon
	elseif SpringObject[index] then
		return SpringObject[index]
	else
		error(("%q is not a member of SpringObject"):format(tostring(index)))
	end
end

function SpringObject:__newindex(index, value)
	if index == "Value" or index == "Position" or index == "p" then
		local observable = Blend.toPropertyObservable(value) or Rx.of(value)

		self._maid._valueSub = observable:Subscribe(function(unconverted)
			local converted = Spring.toLinearIfNeeded(unconverted)
			self:_getSpringForType(converted).Value = converted
			self.Changed:Fire()
		end)
	elseif index == "Velocity" or index == "v" then
		local observable = Blend.toPropertyObservable(value) or Rx.of(value)

		self._maid._velocitySub = observable:Subscribe(function(unconverted)
			local converted = Spring.toLinearIfNeeded(unconverted)

			self:_getSpringForType(0*converted).Velocity = converted
			self.Changed:Fire()
		end)
	elseif index == "Target" or index == "t" then
		self:SetTarget(value)
	elseif index == "Damper" or index == "d" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid damper")

		self._maid._damperSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Damper = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Speed" or index == "s" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid speed")

		self._maid._speedSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Speed = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Epsilon" then
		assert(type(value) == "number", "Bad value")
		rawset(self, "_epsilon", value)
	elseif index == "Clock" then
		assert(type(value) == "function", "Bad clock value")
		self._currentSpring.Clock = value
		self.Changed:Fire()
	else
		error(("%q is not a member of SpringObject"):format(tostring(index)))
	end
end

function SpringObject:_getSpringForType(converted)
	if rawget(self, "_currentSpring") == nil then
		-- only happens on init
		rawset(self, "_currentSpring", Spring.new(converted))
		return self._currentSpring
	else
		local currentType = typeof(Spring.fromLinearIfNeeded(self._currentSpring.Value))
		if currentType == typeof(Spring.fromLinearIfNeeded(converted)) then
			return self._currentSpring
		else
			local oldDamper = self._currentSpring.d
			local oldSpeed = self._currentSpring.s

			self._currentSpring = Spring.new(converted)
			self._currentSpring.Speed = oldSpeed
			self._currentSpring.Damper = oldDamper
			return self._currentSpring
		end
	end
end

--[=[
	Cleans up the BaseObject and sets the metatable to nil
]=]
function SpringObject:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return SpringObject