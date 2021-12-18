local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local PersonalBoardModel = Common.PersonalBoardModel
local MetaBoard = require(script.Parent.MetaBoard)


local PersonalBoardRemoteEvent = Common.Remotes.PersonalBoard


local PersonalBoardManager = {
	PersonalBoardOfPlayer = {}
}
PersonalBoardManager.__index = PersonalBoardManager

function PersonalBoardManager.Init()

	Players.PlayerAdded:Connect(function(player)
		local personalBoardModel = PersonalBoardModel:Clone()
		personalBoardModel.Name = player.Name.."PersonalBoard"

		PersonalBoardManager.PersonalBoardOfPlayer[player] = personalBoardModel.Board
		
		personalBoardModel.Parent = Common
	end)

	Players.PlayerRemoving:Connect(function(player)
		local personalBoard = PersonalBoardManager.PersonalBoardOfPlayer[player]
		personalBoard.EntireModel.Value:Destroy()
		PersonalBoardManager.PersonalBoardOfPlayer[player] = nil
	end)

	PersonalBoardRemoteEvent.OnServerEvent:Connect(function(player, action, ...)
		local personalBoard = PersonalBoardManager.PersonalBoardOfPlayer[player]

		assert(personalBoard ~= nil, "No personal board stored for "..player.Name)

		local args = {...}

		if action == "Spawn" then
			assert(#args == 1)
			local boardCFrame = args[1]
			personalBoard.EntireModel.Value:SetPrimaryPartCFrame(boardCFrame)
			personalBoard.EntireModel.Value.Parent = Workspace
			CollectionService:AddTag(personalBoard, Config.BoardTag)
		elseif action == "Store" then
			personalBoard.EntireModel.Value.Parent = Common
			CollectionService:RemoveTag(personalBoard, Config.BoardTag)
		end
	end)

end

return PersonalBoardManager