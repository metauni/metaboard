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

		local droneIcon
		droneIcon = Icon.new()
			:setEnabled(false)
			:setImage("rbxassetid://11374971657")
			:setLabel("Drone")
			:set("dropdownSquareCorners", true)
			:setDropdown({
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
						droneIcon:setEnabled(false)
					end),
		})
		
		droneIcon:setTheme(Themes["BlueGradient"])
		
		local hostIcon = Icon.new()
			:setImage("rbxassetid://11374971657")
			:setLabel("Host")
			:set("dropdownSquareCorners", true)
			:setDropdown({
				Icon.new()
					:setLabel("Unlink Drone")
					:bindEvent("selected", function(self)
						
						local character = Players.LocalPlayer.Character
						
						if character then
							
							for _, child in ipairs(character:GetChildren()) do
								
								if child:IsA("IntValue") and child.Name == "AttachedDrone" then
									
									DroneEvents.UnlinkDrone:FireServer(child.Value)
								end
							end
						end
						self:deselect()
					end),
		})
		
		hostIcon:setTheme(Themes["BlueGradient"])
		
		local function initCharacter(character: Model)
			
			local destructor = Destructor.new()
		
			droneIcon:setEnabled(character:GetAttribute("DroneAttachedToHost") ~= nil)
			
			destructor:Add(character:GetAttributeChangedSignal("DroneAttachedToHost"):Connect(function()
				
				droneIcon:setEnabled(true)
			end))
		
			hostIcon:setEnabled(character:FindFirstChild("AttachedDrone") ~= nil)
			
			destructor:Add(character.ChildAdded:Connect(function()
				
				hostIcon:setEnabled(character:FindFirstChild("AttachedDrone") ~= nil) 
			end))
			
			destructor:Add(character.ChildRemoved:Connect(function()
				
				hostIcon:setEnabled(character:FindFirstChild("AttachedDrone") ~= nil) 
			end))

			destructor:Add(function()
				
				droneIcon:setEnabled(false)
			end)
		
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