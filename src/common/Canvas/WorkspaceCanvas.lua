-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Canvas = require(script.Parent)
local Config = require(Common.Config)
local Signal = require(Common.Packages.GoodSignal)

-- PartCanvas
local WorkspaceCanvas = setmetatable({}, Canvas)
WorkspaceCanvas.__index = WorkspaceCanvas

local function createNonPhysicalPart(): Part
	local part = Instance.new("Part")
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CanTouch = false -- Do not trigger Touch events
	part.CanQuery = false -- Does not take part in e.g. GetPartsInPart

	return part
end

function WorkspaceCanvas.new(board)
	local self = setmetatable(Canvas.new(board), WorkspaceCanvas)

	local canvasPart = createNonPhysicalPart()
	canvasPart.CanQuery = true -- critical for buttons on surface gui
	canvasPart.Name = "Canvas"
	canvasPart.Transparency = 1
	canvasPart.Size = Vector3.new(board:SurfaceSize().X, board:SurfaceSize().Y, Config.Canvas.CanvasThickness)
	canvasPart.CFrame = board:SurfaceCFrame()

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Adornee = canvasPart
	surfaceGui.Parent = canvasPart

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = canvasPart

	local button = Instance.new("TextButton")
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Parent = surfaceGui

	self._destructor:Add(canvasPart)

	self.ClickedSignal = Signal.new()
	self._destructor:Add(function() self.ClickedSignal:DisconnectAll() end)

	self._destructor:Add(button.Activated:Connect(function()
		self.ClickedSignal:Fire()
	end))

	self._instance = canvasPart

	return self
end

function WorkspaceCanvas:Size()
	return Vector2.new(self._instance.Size.X, self._instance.Size.Y)
end

function WorkspaceCanvas:AspectRatio()
	return self:SurfaceSize().X / self.SurfaceSize().Y
end

function WorkspaceCanvas:GetCFrame()
	return self._instance.CFrame
end

function WorkspaceCanvas:_updateLinePart(linePart: Part, line)
	local function lerp(a, b, c)
		return a + (b - a) * c
	end

	local canvasSize = self:Size()

	linePart.Size = Vector3.new(
		(line:Length() + line.ThicknessYScale) * canvasSize.Y,
		line.ThicknessYScale * canvasSize.Y,
		Config.Canvas.ZThicknessStuds
	)

	linePart.Color = line.Color

	linePart.CFrame = self:GetCFrame()
		* CFrame.new(
			lerp(canvasSize.X / 2, -canvasSize.X / 2, line.Centre.X / self:AspectRatio()),
			lerp(canvasSize.Y / 2, -canvasSize.Y / 2, line.Centre.Y),
			canvasSize.Z / 2
				- Config.Canvas.ZThicknessStuds / 2
				- Config.Canvas.InitialZOffsetStuds
				- self.ZIndex * Config.Canvas.StudsPerZIndex
		)
		* CFrame.Angles(0, 0, line:RotationRadians())
end

local function curveNotFoundError(curveId)
	error("Canvas: could not find curve with ID " .. curveId)
end

local function lineNotFoundError(curveId, lineId)
	error("Canvas: could not find line with ID " .. lineId .. " in curve with ID " .. curveId)
end

function WorkspaceCanvas:_findCurve(curveId)
	return self._instance:FindFirstChild(curveId)
end

function WorkspaceCanvas:AddCurve(curveId: string)
	local curve = Instance.new("Folder")
	curve.Name = curveId
	return curve
end

function WorkspaceCanvas:AddLine(line, lineId, curveId)
	local canvasCurve = self:_findCurve(curveId)
	if canvasCurve == nil then
		curveNotFoundError(curveId)
	end

	local linePart = createLinePart()
	linePart.Name = lineId
	lineId.Parent = canvasCurve

	self:_updateLinePart(linePart, line)
end

function WorkspaceCanvas:UpdateLine(line, lineId, curveId)
	local canvasCurve = self:_findCurve(curveId)
	if canvasCurve == nil then
		curveNotFoundError(curveId)
	end

	local linePart = canvasCurve:FindFirstChild(lineId)
	if linePart == nil then
		lineNotFoundError(curveId, lineId)
	end

	self:_updateLinePart(linePart, line)
end

return WorkspaceCanvas
