-- Services
local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)


-- local PersonalBoardTool = require(script.Parent.PersonalBoardTool)

BoardClient.TagConnection = CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(BoardClient.InstanceBinder)

for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
  BoardClient.InstanceBinder(instance)
end
