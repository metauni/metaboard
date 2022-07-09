-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Import
local Config = require(Common.Config)
local RunService = game:GetService("RunService")
local Board = require(Common.Board)
local Signal = require(Common.Packages.GoodSignal)

-- Helper Functions
local connectDrawingTaskEvents = require(Common.connectDrawingTaskEvents)
local makePart = require(script.makePart)

-- BoardClient
local BoardClient = setmetatable({}, Board)
BoardClient.__index = BoardClient

function BoardClient.new(instance: Model | Part, boardRemotes, persistId: string?, status: string)
	local self = setmetatable(Board.new(instance, boardRemotes, persistId, status), BoardClient)

	self._changedThisFrame = false

	self.ClickedSignal = Signal.new()
	self._destructor:Add(function() self.ClickedSignal:DisconnectAll() end)

	local surfacePart do
		surfacePart = makePart("SurfacePart")
		surfacePart.CanQuery = true -- critical for buttons on surface gui
		surfacePart.Transparency = 1
		surfacePart.Size = Vector3.new(self:SurfaceSize().X, self:SurfaceSize().Y, Config.Canvas.CanvasThickness)
		surfacePart.CFrame = self:SurfaceCFrame()
		surfacePart.Parent = instance
		self._surfacePart = surfacePart

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Adornee = surfacePart
		surfaceGui.Parent = surfacePart

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = surfacePart

		local button = Instance.new("TextButton")
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Parent = surfaceGui

		self._destructor:Add(button.Activated:Connect(function()
			self.ClickedSignal:Fire()
		end))
	end

	return self
end

function BoardClient:DataChanged()
	self._changedThisFrame = true
end

function BoardClient:ConnectToRemoteClientEvents()
	connectDrawingTaskEvents(self, self._destructor)

	self._destructor:Add(RunService.RenderStepped:Connect(function()
		if self._changedThisFrame then
			self.DataChangedSignal:Fire()
		end

		self._changedThisFrame = false
	end))
end

function BoardClient:SetToolState(toolState)
	self._toolState = toolState
end

function BoardClient:GetToolState()
	return self._toolState
end

return BoardClient