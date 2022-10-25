-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Destructor = require(Common.Destructor)

local Drone = {}
Drone.__index = Drone


local function attachDroneToHost(drone, droneCharacter: Model, hostCharacter: Model)

	local destructor = Destructor.new()

	local hideDescendant = function(descendant)

		if descendant:IsA("BasePart") then
			
			local originalTransparency = descendant.Transparency
			
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			
			destructor:Add(function()
					
				descendant.Transparency = originalTransparency
				descendant.CanCollide = true
				descendant.CanQuery = true
				descendant.CanTouch = true
				descendant.Massless = false
			end)
		end

		if descendant:IsA("Decal") then

			local originalTransparency = descendant.Transparency
			
			descendant.Transparency = 1

			destructor:Add(function()
				
				descendant.Transparency = originalTransparency
			end)
		end
	end
	
	for _, descendant in ipairs(droneCharacter:GetDescendants()) do
		
		hideDescendant(descendant)
	end

	destructor:Add(droneCharacter.DescendantAdded:Connect(hideDescendant))

	droneCharacter:WaitForChild("Humanoid").PlatformStand = true

	destructor:Add(function()

		droneCharacter:WaitForChild("Humanoid").PlatformStand = false
	end)

	droneCharacter:PivotTo(hostCharacter:GetPivot())

	local weldConstraint = Instance.new("WeldConstraint")
	
	weldConstraint.Part0 = droneCharacter:WaitForChild("HumanoidRootPart")
	weldConstraint.Part1 = hostCharacter:WaitForChild("HumanoidRootPart")

	weldConstraint.Parent = droneCharacter

	destructor:Add(weldConstraint)

	droneCharacter:SetAttribute("DroneAttachedToHost", drone.Player.UserId)
	
	destructor:Add(function()
		
		droneCharacter:SetAttribute("DroneAttachedToHost", nil)
	end)

	local droneStringValue = Instance.new("IntValue")
	droneStringValue.Name = "AttachedDrone"
	droneStringValue.Value = drone.Player.UserId
	droneStringValue.Parent = hostCharacter

	destructor:Add(droneStringValue)

	return destructor
end


function Drone.new(player: Player, hostUserId: number)

	local self = setmetatable({

		Player = player,
		HostUserId = hostUserId,
	}, Drone)
	
	self._destructor = Destructor.new()

	local function initHostPlayer(host)

		local hostDestructor = Destructor.new()
		local attachDestructor = Destructor.new()
		
		hostDestructor:Add(attachDestructor)
		self._destructor:Add(hostDestructor)

		local function tryAttach()
			
			if self.Player.Character and host.Character then
			
				attachDestructor:Add(attachDroneToHost(self, self.Player.Character, host.Character))
			end
		end

		local function destroyAttach()
			
			attachDestructor:Destroy()
		end

		tryAttach()
		
		hostDestructor:Add(host.CharacterAdded:Connect(tryAttach))
		
		hostDestructor:Add(self.Player.CharacterAdded:Connect(tryAttach))

		hostDestructor:Add(host.CharacterRemoving:Connect(destroyAttach))
		
		hostDestructor:Add(self.Player.CharacterRemoving:Connect(destroyAttach))

		hostDestructor:Add(Players.PlayerRemoving:Connect(function(removingPlayer)
			
			if removingPlayer == host then
				
				hostDestructor:Destroy()
			end
		end))
	end

	local host = Players:GetPlayerByUserId(hostUserId)

	if host then
		
		initHostPlayer(host)
	end

	self._destructor:Add(Players.PlayerAdded:Connect(function(addedPlayer)
		
		if addedPlayer.UserId == hostUserId then

			initHostPlayer(addedPlayer)
		end
	end))

	local connection
	connection = Players.PlayerRemoving:Connect(function(removingPlayer)
		
		if removingPlayer == player then
			
			connection:Disconnect()
			self._destructor:Destroy()
		end
	end)

	return self
end

function Drone:Destroy()
	
	self._destructor:Destroy()
end

return Drone