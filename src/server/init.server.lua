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

end

-- Services
local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local BoardServer = require(script.BoardServer)

-- local MetaBoard = require(script.Parent.MetaBoard)
-- local PersonalBoardManager = require(script.Parent.PersonalBoardManager)
-- local ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)
-- local Persistence = require(script.Parent.Persistence)

BoardServer.TagConnection = CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(BoardServer.InstanceBinder)
	
for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
	BoardServer.InstanceBinder(instance)
end

-- MetaBoard.Init()
-- PersonalBoardManager.Init()
-- ServerDrawingTasks.Init()

-- -- Delay loading persistent boards so as to avoid delaying server startup
-- task.delay( 5, Persistence.Init )