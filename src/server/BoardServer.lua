-- Services
local CollectionService = game:GetService("CollectionService")

-- Import
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Canvas = require(Common.Canvas)
local BoardRemotes = require(Common.BoardRemotes)
local Destructor = require(Common.Packages.Destructor)
local DrawingTaskType = {
	FreeHand = require(Common.DrawingTask.FreeHand),
	StraightLine = require(Common.DrawingTask.StraightLine),
}

-- BoardServer
local BoardServer = setmetatable({}, Board)
BoardServer.__index = BoardServer

function BoardServer.new(instance: Model | Part, boardRemotes)
  -- A server board has no canvas, so we pass nil
  local self = setmetatable(Board.new(instance, boardRemotes, nil), BoardServer)

  local destructor = Destructor.new()
  self._destructor = destructor

  -- Respond to each remote event by repeating it to all of the clients, then
  -- performing the described change to the server's copy of the board

	destructor:Add(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, taskType: string, pos: Vector2, ...)
    self.Remotes.InitDrawingTask:FireClients(player, taskType, pos, ...)

		local drawingTask = DrawingTaskType[taskType].new(self, ...)

		self.PlayerHistory[player]:Append(drawingTask)
		drawingTask:Init(pos)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
    self.Remotes.UpdateDrawingTask:FireClients(player, pos)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Update(pos)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
    self.Remotes.FinishDrawingTask:FireClients(player, pos)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Finish(pos)
	end))

	destructor:Add(self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)
    self.Remotes.Undo:FireClients(player)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Undo()
	end))

	destructor:Add(self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)
    self.Remotes.Redo:FireClients(player)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Redo()
	end))

end

function BoardServer.InstanceBinder(instance)
	local boardRemotes = BoardRemotes.new(instance)
	local board = BoardServer.new(instance, boardRemotes)
end

function BoardServer.Init()
	BoardServer.TagConnection = CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(BoardServer.InstanceBinder)
	for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
		BoardServer.InstanceBinder(instance)
	end
end

return BoardServer