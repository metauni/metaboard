do
	-- Move folder/guis around if this is the package version of metaboard
	
	local metaBoardCommon = script.Parent:FindFirstChild("MetaBoardCommon")
	if metaBoardCommon then
		metaBoardCommon.Parent = game:GetService("ReplicatedStorage")
	end

	local metaBoardPlayer = script.Parent:FindFirstChild("MetaBoardPlayer")
	if metaBoardPlayer then
		metaBoardPlayer.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
	end

	local metaBoardGui = script.Parent:FindFirstChild("MetaBoardGui")
	if metaBoardGui then
		local StarterGui = game:GetService("StarterGui")
		-- Gui's need to be top level children of StarterGui in order for
		-- ResetOnSpawn=false to work properly
		for _, guiObject in ipairs(metaBoardGui:GetChildren()) do
			guiObject.Parent = StarterGui
		end
	end
end

local MetaBoard = require(script.Parent.MetaBoard)
local PersonalBoardManager = require(script.Parent.PersonalBoardManager)
local ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)
local Persistence = require(script.Parent.Persistence)
local HistoryBoard = require(script.Parent.HistoryBoard)

MetaBoard.Init()
PersonalBoardManager.Init()
ServerDrawingTasks.Init()

-- Persistent boards initialisation is triggered by the first player joining
local PersistenceInit = false

local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Remotes = Common.Remotes

Remotes.AnnouncePlayer.OnServerEvent:Connect(function(plr)
    if not PersistenceInit then
        Persistence.Init()
        HistoryBoard.Init()
        
        PersistenceInit = true
    end 
end)