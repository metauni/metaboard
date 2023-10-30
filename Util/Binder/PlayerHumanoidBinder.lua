--[=[
	ADAPTED FROM NEVERMORE
		- Use observables to track player humanoid

	Binder that will automatically bind to each player's humanoid
	@class PlayerHumanoidBinder
]=]

local Players = game:GetService("Players")

local Binder = require(script.Parent)
local Maid = require(script.Parent.Parent.Maid)
-- local Rx = require(script.Parent.Parent.Rx)
local Rxi = require(script.Parent.Parent.Rxi)

local PlayerHumanoidBinder = setmetatable({}, Binder)
PlayerHumanoidBinder.ClassName = "PlayerHumanoidBinder"
PlayerHumanoidBinder.__index = PlayerHumanoidBinder

--[=[
	Returns a new PlayerHumanoidBinder
	@param tag string
	@param class BinderContructor
	@param ... any
	@return PlayerHumanoidBinder<T>
]=]
function PlayerHumanoidBinder.new(tag, class, ...)
	local self = setmetatable(Binder.new(tag, class, ...), PlayerHumanoidBinder)

	return self
end

--[=[
	Inits the binder. See [Binder.Init].
	Should be done via a [ServiceBag].

	@param ... any
]=]
function PlayerHumanoidBinder:Init(...)
	getmetatable(PlayerHumanoidBinder).Init(self, ...)

	if not self._shouldTag then
		self._shouldTag = Instance.new("BoolValue")
		self._shouldTag.Value = true
		self._maid:GiveTask(self._shouldTag)
	end
end

--[=[
	Sets whether tagging should be enabled
	@param shouldTag boolean
]=]
function PlayerHumanoidBinder:SetAutomaticTagging(shouldTag)
	assert(type(shouldTag) == "boolean", "Bad shouldTag")
	assert(self._shouldTag, "Missing self._shouldTag")

	self._shouldTag.Value = shouldTag
end

--[=[
	Starts the binder. See [Binder.Start].
	Should be done via a [ServiceBag].
]=]
function PlayerHumanoidBinder:Start()
	local results = { getmetatable(PlayerHumanoidBinder).Start(self) }

	self._maid:GiveTask(self._shouldTag.Changed:Connect(function()
		self:_bindTagging(true)
	end))
	self:_bindTagging()

	return unpack(results)
end

function PlayerHumanoidBinder:_bindTagging(doUnbinding)
	if self._shouldTag.Value then
		local maid = Maid.new()

		local playerMaid = Maid.new()
		maid:GiveTask(playerMaid)

		maid:GiveTask(Players.PlayerAdded:Connect(function(player)
			self:_handlePlayerAdded(playerMaid, player)
		end))
		maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
			playerMaid[player] = nil
		end))

		for _, player in pairs(Players:GetPlayers()) do
			self:_handlePlayerAdded(playerMaid, player)
		end

		self._maid._tagging = maid
	else
		self._maid._tagging = nil

		if doUnbinding then
			for _, player in pairs(Players:GetPlayers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
				if humanoid then
					self:Unbind(humanoid)
				end
			end
		end
	end
end

function PlayerHumanoidBinder:_handlePlayerAdded(playerMaid, player)
	local maid = Maid.new()

	maid:GiveTask(Rxi.propertyOf(player, "Character"):Pipe {
		Rxi.findFirstChildWithClassOf("Humanoid", "Humanoid")
	}:Subscribe(function(humanoid: Humanoid?)
		if humanoid then
			self:Bind(humanoid)
			-- Note it will unbind itself on remove
		end
	end))

	playerMaid[player] = maid
end


return PlayerHumanoidBinder