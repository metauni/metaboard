do
	-- Move folder/guis around if they have been packaged inside MetaBoardServer
	
	local metaBoardCommon = script.Parent:FindFirstChild("MetaBoardCommon")
	if metaBoardCommon then
		metaBoardCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local metaBoardPlayer = script.Parent:FindFirstChild("MetaBoardPlayer")
	if metaBoardPlayer then
		metaBoardPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

	local boardGui = script.Parent:FindFirstChild("BoardGui")
	if boardGui then
		boardGui.Parent = game:GetService("StarterGui")
	end
end

local MetaBoard = require(script.Parent.MetaBoard)
local PersonalBoardManager = require(script.Parent.PersonalBoardManager)
local ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)
local Persistence = require(script.Parent.Persistence)

MetaBoard.Init()
PersonalBoardManager.Init()
ServerDrawingTasks.Init()
Persistence.Init()