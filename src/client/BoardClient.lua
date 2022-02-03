-- Services
local CollectionService = game:GetService("CollectionService")

-- Import
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local Canvas = require(Common.Canvas)
local BoardRemotes = require(Common.BoardRemotes)
local Destructor = require(Common.Packages.Destructor)
local DrawingTask = require(Common.DrawingTask)

-- BoardClient
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes, canvas)
	local self = setmetatable(Board.new(instance, boardRemotes, canvas), BoardClient)

	local destructor = Destructor.new()
	self._destructor = destructor

	destructor:GiveTask(self.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, taskType: string, taskId, drawingTask, pos: Vector2)
		drawingTask = setmetatable(drawingTask, DrawingTask[taskType])

		self.PlayerHistory[player]:Append(taskId, drawingTask)
		drawingTask:Init(self, pos)
	end))

	destructor:GiveTask(self.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, pos)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Update(self, pos)
	end))

	destructor:GiveTask(self.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player, pos)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Finish(self, pos)
	end))

	destructor:GiveTask(self.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
		--TODO not sure who alters PlayerHistory (here or inside drawing task)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Undo(self)
	end))
	
	destructor:GiveTask(self.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
		--TODO not sure who alters PlayerHistory (here or inside drawing task)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Redo(self)
	end))

end

CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(instance)
	-- This will yield until the remotes have replicated from the server
	local boardRemotes = BoardRemotes.WaitForRemotes(instance)

	local canvasPart = Canvas.CreateCanvasPart(instance)
	local canvas = Canvas.new(canvasPart)
	local board = BoardClient.new(instance, boardRemotes, canvas)

	canvas.TouchedSignal:Connect(function()
		canvasPart.Archivable = false
		local clone = board._instance:Clone()
		canvasPart.Archivable = true

		-- TODO: is this overkill?
		for _, tag in ipairs(CollectionService:GetTags(clone)) do
			CollectionService:RemoveTag(clone, tag)
		end

		canvasPart.Parent = clone
	end)
end)