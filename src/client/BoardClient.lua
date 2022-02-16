-- Services
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Import
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Board = require(Common.Board)
local WorkspaceCanvas = require(Common.Canvas.WorkspaceCanvas)
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

	destructor:Add(self.Remotes.InitDrawingTask.OnClientEvent:Connect(function(player: Player, taskType: string, taskId, drawingTask, pos: Vector2)
		drawingTask = setmetatable(drawingTask, DrawingTask[taskType])

		self.PlayerHistory[player]:Append(taskId, drawingTask)
		drawingTask:Init(self, pos)
	end))

	destructor:Add(self.Remotes.UpdateDrawingTask.OnClientEvent:Connect(function(player: Player, pos)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Update(self, pos)
	end))

	destructor:Add(self.Remotes.FinishDrawingTask.OnClientEvent:Connect(function(player: Player, pos)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Finish(self, pos)
	end))

	destructor:Add(self.Remotes.Undo.OnClientEvent:Connect(function(player: Player)
		--TODO not sure who alters PlayerHistory (here or inside drawing task)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Undo(self)
	end))

	destructor:Add(self.Remotes.Redo.OnClientEvent:Connect(function(player: Player)
		--TODO not sure who alters PlayerHistory (here or inside drawing task)
		local drawingTask = self.PlayerHistory[player]:GetCurrent()
		assert(drawingTask)
		drawingTask:Redo(self)
	end))

	return self
end

function BoardClient.InstanceBinder(instance)
	-- This will yield until the remotes have replicated from the server
	local boardRemotes = BoardRemotes.WaitForRemotes(instance)

	local board = BoardClient.new(instance, boardRemotes)

	local canvas = WorkspaceCanvas.new(board)
	board:SetCanvas(canvas)
	canvas._instance.Parent = board._instance

	canvas.ClickedSignal:Connect(function()

		canvas._instance.Archivable = false
		local clone = board._instance:Clone()
		canvas._instance.Archivable = true

		-- TODO: is this overkill?
		for _, tag in ipairs(CollectionService:GetTags(clone)) do
			CollectionService:RemoveTag(clone, tag)
		end

		canvas._instance.Parent = clone

		local camera = BoardClient.BoardViewportFrame.CurrentCamera
		camera.CFrame = Workspace.CurrentCamera.CFrame
		local startCFrame = camera.CFrame

		local cframeValue = Instance.new("CFrameValue")
		cframeValue.Value = canvas:GetCFrame()

		local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0)
		local targetCFrame = camera.CFrame
			* CFrame.new(0, 0, -canvas:Size().Y/2 / math.tan(math.rad(camera.FieldOfView/2)) / 0.8)
			* CFrame.Angles(0,math.pi, 0)
		local tween = TweenService:Create(cframeValue, tweenInfo, { Value = targetCFrame })

		local connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			camera.CFrame = canvas:GetCFrame() * cframeValue.Value:Inverse() * startCFrame
		end)

		tween.Completed:Connect(function()
			connection:Disconnect()
			cframeValue:Destroy()
		end)

		clone.Parent = BoardClient.BoardViewportFrame

		tween:Play()
	end)
end

function BoardClient.Init()
	BoardClient.TagConnection = CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(BoardClient.InstanceBinder)

	for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
		BoardClient.InstanceBinder(instance)
	end

	do
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "BoardViewGui"
		screenGui.IgnoreGuiInset = true

		local viewportFrame = Instance.new("ViewportFrame")
		viewportFrame.Size = UDim2.new(1,0,1,0)
		viewportFrame.Position = UDim2.new(0,0,0,0)
		viewportFrame.BackgroundTransparency = 1

		local camera = Instance.new("Camera")
		camera.Parent = viewportFrame

		viewportFrame.CurrentCamera = camera

		viewportFrame.Parent = screenGui

		screenGui.Parent = Players.LocalPlayer.PlayerGui

		BoardClient.BoardViewGui = screenGui
		BoardClient.BoardViewportFrame = viewportFrame
	end
end

return BoardClient