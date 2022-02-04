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
local History = require(script.Parent.History)

MetaBoard.Init()
PersonalBoardManager.Init()
ServerDrawingTasks.Init()

-- Delay loading persistent boards so as to avoid delaying server startup
local function delayedStartup()
	Persistence.Init()
	History.Init()
end

task.delay( 5, delayedStartup )