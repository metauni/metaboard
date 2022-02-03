-- Services
local CollectionService = game:GetService("CollectionService")

-- Import
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Canvas = require(Common.Canvas)
local BoardRemotes = require(Common.BoardRemotes)
local Maid = require(Common.Packages.Maid)
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

  local maid = Maid.new()
  self._maid = maid

  -- Respond to each remote event by repeating it to all of the clients, then
  -- performing the described change to the server's copy of the board

	maid:GiveTask(self.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player: Player, taskType: string, pos: Vector2, ...)
    self.Remotes.InitDrawingTask:FireClients(player, taskType, pos, ...)

		local drawingTask = DrawingTaskType[taskType].new(self, ...)

		self.PlayerHistory[player]:Append(drawingTask)
		drawingTask:Init(pos)
	end))

	maid:GiveTask(self.Remotes.UpdateDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
    self.Remotes.UpdateDrawingTask:FireClients(player, pos)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Update(pos)
	end))

	maid:GiveTask(self.Remotes.FinishDrawingTask.OnServerEvent:Connect(function(player: Player, pos)
    self.Remotes.FinishDrawingTask:FireClients(player, pos)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Finish(pos)
	end))

	maid:GiveTask(self.Remotes.Undo.OnServerEvent:Connect(function(player: Player)
    self.Remotes.Undo:FireClients(player)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Undo()
	end))

	maid:GiveTask(self.Remotes.Redo.OnServerEvent:Connect(function(player: Player)
    self.Remotes.Redo:FireClients(player)

    local drawingTask = self.PlayerHistory[player]:GetCurrent()
    assert(drawingTask)
		drawingTask:Redo()
	end))

end

CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(instance)
	local boardRemotes = BoardRemotes.WaitForRemotes(instance)

	local canvas = Canvas.new(Canvas.CreateCanvasPart(instance))
	local board = BoardServer.new(instance, boardRemotes, canvas)
end)