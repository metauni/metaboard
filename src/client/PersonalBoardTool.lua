local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Config = require(Common.Config)
local PersonalBoardRemoteEvent = Common.Remotes.PersonalBoard

local LocalPlayer = game:GetService("Players").LocalPlayer

local PersonalBoardTool = {}
PersonalBoardTool.__index = PersonalBoardTool

function PersonalBoardTool.Init(localCharacter)
	PersonalBoardTool.LocalCharacter = localCharacter
	
	PersonalBoardTool.Tool = Instance.new("Tool")
	PersonalBoardTool.Tool.CanBeDropped = false
	PersonalBoardTool.Tool.ManualActivationOnly = true
	PersonalBoardTool.Tool.RequiresHandle = false
	PersonalBoardTool.Tool.Name = "Personal Board"

	PersonalBoardTool.Tool.Equipped:Connect(function(mouse) 
		PersonalBoardTool.SpawnBoard() end)
	PersonalBoardTool.Tool.Unequipped:Connect(PersonalBoardTool.StoreBoard)

	PersonalBoardTool.Tool.Parent = LocalPlayer.Backpack

	--print("Personal Board Tool Initialised")
end

function PersonalBoardTool.SpawnBoard()
	local boardCFrame =
		PersonalBoardTool.LocalCharacter.HumanoidRootPart.CFrame
			* CFrame.new(Config.PersonalBoard.TorsoOffset)
			* CFrame.Angles(0, math.pi, 0)

	PersonalBoardRemoteEvent:FireServer("Spawn", boardCFrame)
end

function PersonalBoardTool.StoreBoard()
	PersonalBoardRemoteEvent:FireServer("Store")
end

return PersonalBoardTool