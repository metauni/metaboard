-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

-- Imports
local Destructor = require(Common.Destructor)
local Drone = require(script.Drone)

-- Globals
local dataStore = DataStoreService:GetDataStore("DroneToHost")
local _droneToHostCache = {}
local NO_HOST = newproxy(true)
local Drones = {}

local function getHostUserIdAsync(droneUserId: number)

	-- For studio testing
	if droneUserId == -2 then
		
		return -1
	end
	
	local userIdStr = tostring(droneUserId)
	local hostUserIdStr

	if _droneToHostCache[userIdStr] then
		
		hostUserIdStr = _droneToHostCache[userIdStr]
		return hostUserIdStr ~= NO_HOST and tonumber(hostUserIdStr) or nil
	else

		while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync) <= 0 do
			
			task.wait()
		end
		
		hostUserIdStr = dataStore:GetAsync(userIdStr)
		_droneToHostCache[userIdStr] = hostUserIdStr or NO_HOST

		return hostUserIdStr and tonumber(hostUserIdStr) or nil
	end
end

local function followHost(drone: Player, hostUserId: number)

	local destructor = Destructor.new()

	destructor:Add(MessagingService:SubscribeAsync("DroneHostFound", function(message)

		local data = message.Data

		if data.HostUserId ~= hostUserId then
			
			return
		end
		
		local placeId = data.PlaceId
		local accessCode = data.AccessCode
		local jobId = data.JobId

		if jobId == game.JobId then
			
			return
		end

		local teleportOptions = Instance.new("TeleportOptions")

		if accessCode then
			
			teleportOptions.ReservedServerAccessCode = accessCode
		else

			teleportOptions.ServerInstanceId = jobId
		end
		

		TeleportService:TeleportAsync(placeId, {drone}, teleportOptions)
	end))
	
	-- Send Host requests every 5 seconds for 2 minutes, until either the host
	-- is found in another server, or joins this server.

	destructor:Add(task.spawn(function()
		
		while true do
	
			local host = Players:GetPlayerByUserId(hostUserId)
	
			if not host then
				
				MessagingService:PublishAsync("DroneHostRequest", { HostUserId = hostUserId })
			end

			task.wait(5)
		end
	end))

	destructor:Add(Players.PlayerRemoving:Connect(function(removingPlayer)
					
		if removingPlayer == drone then
			
			destructor:Destroy()
		end
	end))

	return destructor
end

local function bindPlayer(player)
			
	local hostUserId = getHostUserIdAsync(player.UserId)

	if hostUserId then

		if Drones[player.UserId] then
			
			Drones[player.UserId]:Destroy()
		end

		-- Handles attaching/detaching from host character
		Drones[player.UserId] = Drone.new(player, hostUserId)
		
		-- Finds and teleports to the host
		followHost(player, hostUserId)
	end
end

return {

	Start = function()

		if not RunService:IsStudio() then

			-- Respond to requests looking for a host, returning data to be able to
			-- teleport here
			
			MessagingService:SubscribeAsync("DroneHostRequest", function(message)

				local hostUserId = message.Data.HostUserId
		
				local host = Players:GetPlayerByUserId(hostUserId)

				if not host then
					
					-- Requested host isn't in this server
					return
				end

				local data = {
					HostUserId = hostUserId,
					PlaceId = game.PlaceId,
				}

				if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then

					local hostTeleportData = host:GetJoinData().TeleportData

					local accessCode = hostTeleportData.AccessCode

					if not accessCode then
						
						warn("[Drone] No Access Code in Host TeleportData")
						return
					end
					
					data.AccessCode = hostTeleportData.AccessCode
				else

					data.JobId = game.JobId
				end
	
				MessagingService:PublishAsync("DroneHostFound", data)
			end)
		end

		for _, player in ipairs(Players:GetPlayers()) do
			
			task.spawn(bindPlayer, player)
		end

		Players.PlayerAdded:Connect(bindPlayer)

		Common.DroneEvents.DetachDrone.OnServerEvent:Connect(function(player, droneUserId)

			if not droneUserId then

				warn("[DroneService] Tried to detach nil droneUserId")
			end
			
			if Drones[droneUserId] then

				Drones[droneUserId]:Destroy()
			end
		end)

		Common.DroneEvents.ReattachDrone.OnServerEvent:Connect(function(player, droneUserId)

			if not droneUserId then

				warn("[DroneService] Tried to Reattach nil droneUserId")
			end
			
			if Drones[droneUserId] then

				local drone = Drones[droneUserId]
				drone:Destroy()
				Drones[droneUserId] = Drone.new(drone.Player, drone.HostUserId)
			end
		end)

		Common.DroneEvents.UnlinkDrone.OnServerEvent:Connect(function(player, droneUserId)

			if not droneUserId then

				warn("[DroneService] Tried to Unlink nil droneUserId")
			end

			if Drones[droneUserId] then

				Drones[droneUserId]:Destroy()
			end

			Drones[droneUserId] = nil
			
			Common.DroneEvents.UnlinkDrone:FireAllClients(droneUserId)

			while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync) <= 0 do
			
				task.wait()
			end

			
			dataStore:RemoveAsync(droneUserId)
			_droneToHostCache[droneUserId] = NO_HOST
		end)
	end,

	Assign = function(dronePlayer, hostPlayer)
		
		assert(dronePlayer, "[Drone] No dronePlayer given")
		assert(hostPlayer, "[Drone] No hostPlayer given")
		assert(dronePlayer ~= hostPlayer, "[Drone] Drone and Host must be distinct")

		while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync) <= 0 do
			
			task.wait()
		end
		
		dataStore:SetAsync(tostring(dronePlayer.UserId), tostring(hostPlayer.UserId))
		_droneToHostCache[tostring(dronePlayer.UserId)] = tostring(hostPlayer.UserId)

		bindPlayer(dronePlayer)
	end,

	GetHostUserIdAsync = getHostUserIdAsync,
}