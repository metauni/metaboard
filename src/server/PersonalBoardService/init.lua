-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local BoardModel = script.BoardModels.BlackBoardMini
local BoardServer = require(script.Parent.BoardServer)
local Destructor = require(Common.Destructor)

-- Globals
local _boardInfoOfPlayer = {}
local BoardStorage = nil
local WorkspaceFolder = nil

local function initPlayer(player)
	
	local instance = BoardModel:Clone()
	instance.Name = player.Name.."-personalboard"
	CollectionService:AddTag(instance, "metaboard_personal_board")
	instance.Parent = BoardStorage

	local destructor = Destructor.new()

	local board = BoardServer.new(instance)

	instance:SetAttribute("BoardServerInitialised", true)

	destructor:Add(instance)

	local handleBoardDataRequest = function(requestingPlayer)
		
		board.Watchers[requestingPlayer] = true

		return {
			
			Figures = board.Figures,
			DrawingTasks = board.DrawingTasks,
			PlayerHistories = board.PlayerHistories,
			NextFigureZIndex = board.NextFigureZIndex,
			EraseGrid = nil,
			ClearCount = nil
		}
	end

	board:ConnectRemotes(nil)
	board.Remotes.GetBoardData.OnServerInvoke = handleBoardDataRequest

	local function initTool(character)
			
		local tool = Instance.new("Tool")
		tool.Name = "Personal Board"
		tool.Parent = player.Backpack

		instance.Parent = BoardStorage

		tool.AncestryChanged:Connect(function()

			local backpack = player:FindFirstChild("Backpack")

			if backpack and tool.Parent then
				
				if tool.Parent == backpack then
					
					instance.Parent = BoardStorage
					
				else
					
					--TODO: Move curves and board to new cframe

					instance:PivotTo(character:GetPivot() * CFrame.new(0,2,-5) * CFrame.Angles(0, math.pi, 0))
					
					instance.Parent = WorkspaceFolder
				end
			end
		end)

		do
			local connection
			connection = player.CharacterRemoving:Connect(function()
				
				tool:Destroy()
				connection:Disconnect()
			end)
		end
	end
	
	if player.Character then
		
		initTool(player.Character)
	end

	destructor:Add(player.CharacterAdded:Connect(initTool))

	
	_boardInfoOfPlayer[player] = {
		
		Destroy = function()
			destructor:Destroy()
		end,
		Board = board,
		Instance = instance,
	}
end

return {

	Start = function()

		if not BoardStorage then
			
			BoardStorage = Instance.new("Folder")
			BoardStorage.Name = "PersonalBoardStorage"
			BoardStorage.Parent = ReplicatedStorage
		end

		if not WorkspaceFolder then
			
			WorkspaceFolder = Instance.new("Folder")
			WorkspaceFolder.Name = "PersonalBoards"
			WorkspaceFolder.Parent = workspace
		end
		
		for _, player in ipairs(Players:GetPlayers()) do
			
			initPlayer(player)
		end

		Players.PlayerRemoving:Connect(function(player)
			
			local info = _boardInfoOfPlayer[player]
			
			if info then
				
				info:Destroy()
			end

			_boardInfoOfPlayer[player] = nil
		end)

		Players.PlayerAdded:Connect(initPlayer)
	end
} 