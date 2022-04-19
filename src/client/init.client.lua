-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local CollectionService = game:GetService("CollectionService")


-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)
local BoardRemotes = require(Common.BoardRemotes)
local PartCanvas = require(Common.Canvas.PartCanvas)

-- Helper functions
local boardLoader = require(script.boardLoader)


-- local PersonalBoardTool = require(script.Parent.PersonalBoardTool)

local Boards = {}

local function bindBoardInstance(instance)
  -- This will yield until the remotes have replicated from the server
  local boardRemotes = BoardRemotes.WaitForRemotes(instance)

  local board = BoardClient.new(instance, boardRemotes)

  board.ClickedSignal:Connect(function()
    if board._isClientLoaded then
      board:OpenUI()
    end
  end)

  table.insert(Boards, board)
end

BoardClient.TagConnection = CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(instance)
  if instance:IsDescendantOf(workspace) then
    bindBoardInstance(instance)
  end
end)

for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
  if instance:IsDescendantOf(workspace) then
    bindBoardInstance(instance)
  end
end

task.spawn(boardLoader, Boards)