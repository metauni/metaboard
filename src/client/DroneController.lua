-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Destructor = require(Common.Destructor)
local DroneEvents = Common.DroneEvents
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
local Themes =  require(ReplicatedStorage.Icon.Themes)

-- https://fonts.google.com/icons?icon.query=toy

return {

	Start = function()

		local function makeDroneIcon(character)

			local destructor = Destructor.new()

			local hostUserId = character:GetAttribute("DroneAttachedToHost")

			local hostName do
				
				local hostPlayer = Players:GetPlayerByUserId(hostUserId)

				if hostPlayer then
					
					hostName = hostPlayer.DisplayName
				end
			end
			
			local droneIcon
			droneIcon = Icon.new()
				:setImage("rbxassetid://11374971657")
				:setLabel("Drone")
				:setOrder(2)
				:set("dropdownSquareCorners", true)
				:set("dropdownMaxIconsBeforeScroll", 10)

			local dropdownIcons = {
				Icon.new()
					:setLabel("Host: "..(hostName or "?"))
					:lock()
					:set("iconBackgroundTransparency", 1),
				Icon.new()
					:setLabel("Detach")
					:bindEvent("selected", function(self)
						DroneEvents.DetachDrone:FireServer(Players.LocalPlayer.UserId)
						self:deselect()
					end),
				Icon.new()
					:setLabel("Reattach")
					:bindEvent("selected", function(self)
						DroneEvents.ReattachDrone:FireServer(Players.LocalPlayer.UserId)
						self:deselect()
					end),
				Icon.new()
					:setLabel("Unlink From Host")
					:bindEvent("selected", function(self)
						DroneEvents.UnlinkDrone:FireServer(Players.LocalPlayer.UserId)
						self:deselect()
						destructor:Destroy()
					end),
			}

			droneIcon:setDropdown(dropdownIcons)
			
			droneIcon:setTheme(Themes["BlueGradient"])

			destructor:Add(function()
				
				for _, icon in dropdownIcons do
					
					icon:destroy()
				end

				droneIcon:destroy()
			end)

			return destructor
		end

		local function makeHostIcon(character)

			local destructor = Destructor.new()
			
			local hostIcon = Icon.new()
				:setImage("rbxassetid://11374971657")
				:setLabel("Host")
				:setOrder(2)
				:set("dropdownSquareCorners", true)
				:set("dropdownMaxIconsBeforeScroll", 10)

			local dropdownIcons = {
				Icon.new()
					:setLabel("Unlink Drone")
					:bindEvent("selected", function(self)

						for _, child in ipairs(character:GetChildren()) do
							
							if child:IsA("IntValue") and child.Name == "AttachedDrone" then
								
								DroneEvents.UnlinkDrone:FireServer(child.Value)
							end
						end
							
						self:deselect()
					end),
			}

			hostIcon:setDropdown(dropdownIcons)
			
			hostIcon:setTheme(Themes["BlueGradient"])
		
			destructor:Add(function()
				
				for _, icon in dropdownIcons do
					
					icon:destroy()
				end
				
				hostIcon:destroy()
			end)

			return destructor
		end
		
		
		local function initCharacter(character: Model)
			
			local destructor = Destructor.new()
			local droneIconDestructor = Destructor.new()
			local hostIconDestructor = Destructor.new()

			destructor:Add(droneIconDestructor)
			destructor:Add(hostIconDestructor)

			if character:GetAttribute("DroneAttachedToHost") then
				
				droneIconDestructor = makeDroneIcon(character)
			end

			destructor:Add(character:GetAttributeChangedSignal("DroneAttachedToHost"):Connect(function()
				
				droneIconDestructor:Destroy()
				droneIconDestructor = makeDroneIcon(character)

			end))

			if character:FindFirstChild("AttachedDrone") then
				
				hostIconDestructor:Destroy()
				hostIconDestructor = makeHostIcon(character)
			end 
			
			destructor:Add(character.ChildAdded:Connect(function()
				
				if character:FindFirstChild("AttachedDrone") then
				
					hostIconDestructor:Destroy()
					hostIconDestructor = makeHostIcon(character)
				end 
			end))
			
			destructor:Add(character.ChildRemoved:Connect(function()
				
				if character:FindFirstChild("AttachedDrone") then
				
					hostIconDestructor:Destroy()
				end 
			end))
		
			return destructor
		end
		
		local iconStateDestructor = Destructor.new()
		
		if Players.LocalPlayer.Character then
			
			iconStateDestructor:Add(initCharacter(Players.LocalPlayer.Character))
		end
		
		Players.LocalPlayer.CharacterAdded:Connect(function(character)
			
			iconStateDestructor:Destroy()
			iconStateDestructor:Add(initCharacter(character))
		end)

		Common.DroneEvents.UnlinkDrone.OnClientEvent:Connect(function(droneUserId)
			
			if droneUserId == Players.LocalPlayer.UserId then
				
				iconStateDestructor:Destroy()
				iconStateDestructor:Add(initCharacter(Players.LocalPlayer.Character))
			end
		end)
	end,
}