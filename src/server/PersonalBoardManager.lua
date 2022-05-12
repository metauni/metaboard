local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Config = require(Common.Config)
-- local PersonalBoardOriginal = Common.PersonalBoardModel
local MetaBoard = require(script.Parent.MetaBoard)
local PersonalBoardOriginal


local PersonalBoardRemoteEvent = Common.Remotes.PersonalBoard


local PersonalBoardManager = {
	-- player -> board
	Boards = {}
}
PersonalBoardManager.__index = PersonalBoardManager

function PersonalBoardManager.Init()

	local asset = InsertService:LoadAsset(Config.PersonalBoard.AssetId)
	PersonalBoardOriginal = asset:FindFirstChildWhichIsA("Model") or asset:FindFirstAncestorWhichIsA("BasePart")

	assert(PersonalBoardOriginal, "Personal Board Asset must be Model or BasePart")

	Players.PlayerAdded:Connect(PersonalBoardManager.OnPlayerAdded)
	for _, player in ipairs(Players:GetChildren()) do
		PersonalBoardManager.OnPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local personalBoard = PersonalBoardManager.Boards[player]

		if personalBoard then
			personalBoard:Destroy()
			PersonalBoardManager.Boards[player] = nil
		end
	end)

	PersonalBoardRemoteEvent.OnServerEvent:Connect(function(player, action, ...)
		local personalBoard = PersonalBoardManager.Boards[player]

		assert(personalBoard ~= nil, "No personal board stored for "..player.Name)

		local args = {...}

		if action == "Spawn" then
			assert(#args == 1)
			local boardCFrame = args[1]
			personalBoard.Parent = Workspace

			if personalBoard:IsA("Model") then
				personalBoard:SetPrimaryPartCFrame(boardCFrame)
			else
				personalBoard.CFrame = boardCFrame
			end
			CollectionService:AddTag(personalBoard, Config.BoardTag)
			CollectionService:AddTag(personalBoard, Config.BoardTagPersonal)
		elseif action == "Store" then
			personalBoard.Parent = Common
			CollectionService:RemoveTag(personalBoard, Config.BoardTag)
		end
	end)

end

function PersonalBoardManager.OnPlayerAdded(player)
	if PersonalBoardManager.Boards[player] == nil then
		local personalBoard = PersonalBoardOriginal:Clone()
		CollectionService:RemoveTag(personalBoard, Config.BoardTag)
		personalBoard.Name = player.Name.."PersonalBoard"
		
		PersonalBoardManager.Boards[player] = personalBoard
		personalBoard.Parent = Common
	end
end

return PersonalBoardManager