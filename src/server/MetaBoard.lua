local CollectionService = game:GetService("CollectionService")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local DrawingTask = require(Common.DrawingTask)
local Cache = require(Common.Cache)
local ServerDrawingTasks

local UndoCurveRemoteEvent = Common.Remotes.UndoCurve

local MetaBoard = {}
MetaBoard.__index = MetaBoard

function MetaBoard.Init()

	ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)

	-- maps boards to the subscribers of that board
	MetaBoard.SubscribersOf = {}

	local boards = CollectionService:GetTagged(Config.BoardTag)

	for _, board in ipairs(boards) do
		MetaBoard.InitBoard(board)
	end

	local function subscribeToBroadcasters(board)
		for _, child in ipairs(board:GetChildren()) do
			if child:IsA("ObjectValue") and child.Name == "SubscribedTo" and CollectionService:HasTag(child.Value, Config.BoardTag) then
				MetaBoard.Subscribe(board, child.Value)
			end
		end
	end

	for _, board in ipairs(boards) do
		subscribeToBroadcasters(board)
	end
	
	CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(board)
		MetaBoard.InitBoard(board)
		subscribeToBroadcasters(board)
	end)

	UndoCurveRemoteEvent.OnServerEvent:Connect(function(player, board, curveName)
		local curve = board.Canvas.Curves:FindFirstChild(curveName)
		if curve then
			Cache.Release(curve)
			curve.Parent = nil
		end
	end)

	-- (player -> (board -> task))
	MetaBoard.DrawingTasksTable = {}

	DrawingTask.InitRemoteEvent.OnServerEvent:Connect(function(player, board, taskKind, ...)
		local args = {...}
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		MetaBoard.DrawingTasksTable[player] = {}
		
		for _, subscriber in ipairs(subscriberFamily) do
			local drawingTask = ServerDrawingTasks.new(taskKind, player, subscriber)
			MetaBoard.DrawingTasksTable[player][subscriber] = drawingTask
			drawingTask.Init(drawingTask.State, ...)
		end
	end)

	DrawingTask.UpdateRemoteEvent.OnServerEvent:Connect(function(player, ...)
		for board, drawingTask in pairs(MetaBoard.DrawingTasksTable[player]) do
			drawingTask.Update(drawingTask.State, ...)
		end
	end)

	DrawingTask.FinishRemoteEvent.OnServerEvent:Connect(function(player, ...)
		for board, drawingTask in pairs(MetaBoard.DrawingTasksTable[player]) do
			drawingTask.Finish(drawingTask.State, ...)
		end
	end)

	print("MetaBoard Server initialized")
end

function MetaBoard.GetSurfaceCFrame(part, face)
	if face == "Front" then
		return part.CFrame * CFrame.Angles(0,0,0) * CFrame.new(0,0,-part.Size.Z/2)
	elseif face == "Left" then
		return part.CFrame * CFrame.Angles(0,math.pi/2,0) * CFrame.new(0,0,-part.Size.X/2)
	elseif face == "Back" then
		return part.CFrame * CFrame.Angles(0,math.pi,0) * CFrame.new(0,0,-part.Size.Z/2)
	elseif face == "Right" then
		return part.CFrame * CFrame.Angles(0,-math.pi/2,0) * CFrame.new(0,0,-part.Size.X/2)
	elseif face == "Top" then
		return part.CFrame * CFrame.Angles(math.pi/2,0,0) * CFrame.new(0,0,-part.Size.Y/2)
	elseif face == "Bottom" then
		return part.CFrame * CFrame.Angles(-math.pi/2,0,0) * CFrame.new(0,0,-part.Size.Y/2)
	end
end

function MetaBoard.GetSurfaceDimensions(part, face)
	if face == "Front" then
		return Vector2.new(part.Size.X,part.Size.Y)
	elseif face == "Left" then
		return Vector2.new(part.Size.Z,part.Size.Y)
	elseif face == "Back" then
		return Vector2.new(part.Size.X,part.Size.Y)
	elseif face == "Right" then
		return Vector2.new(part.Size.Z,part.Size.Y)
	elseif face == "Top" then
		return Vector2.new(part.Size.X,part.Size.Z) 
	elseif face == "Bottom" then
		return Vector2.new(part.Size.X,part.Size.Z) 
	end
end

function MetaBoard.InitBoard(board)
	
	local face = board:FindFirstChild("Face")
	if face == nil then
		face = Instance.new("StringValue")
		face.Name = "Face"
		face.Value = "Front"
		
		face.Parent = board
	end
	
	local canvasColor = board:FindFirstChild("CanvasColor")
	if canvasColor == nil then
		canvasColor = Instance.new("Color3Value")
		canvasColor.Name = "CanvasColor"
		canvasColor.Value = board.Color or Color3.new(1,1,1)

		canvasColor.Parent = board
	end
	
	local canvas = board:FindFirstChild("Canvas")

	if canvas == nil then
		canvas = Instance.new("Part")
		canvas.Name = "Canvas"
		canvas.Massless = true
		canvas.CanCollide = false
		canvas.CanTouch = false
		local dimensions = MetaBoard.GetSurfaceDimensions(board, face.Value)
		canvas.Size = Vector3.new(dimensions.X, dimensions.Y, Config.CanvasThickness)
		canvas.CFrame = MetaBoard.GetSurfaceCFrame(board, face.Value) * CFrame.new(0,0,-canvas.Size.Z/2)
		canvas.Transparency = 1

		local weldConstraint = Instance.new("WeldConstraint")
		weldConstraint.Part0 = board
		weldConstraint.Part1 = canvas
		weldConstraint.Parent = board

		local curves = Instance.new("Folder")
		curves.Name = "Curves"
		curves.Parent = canvas

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SurfaceGui"
		surfaceGui.Adornee = canvas
		surfaceGui.Parent = canvas

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = "ClickDetector"
		clickDetector.Parent = board

		local button = Instance.new("TextButton")
		button.Name = "Button"
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1,0,1,0)
		button.Parent = surfaceGui

		canvas.Parent = board
	end
	
	local currentZIndex = board:FindFirstChild("CurrentZIndex")

	if currentZIndex == nil then
		currentZIndex = Instance.new("NumberValue")
		currentZIndex.Value = 0
		currentZIndex.Name = "CurrentZIndex"
		currentZIndex.Parent = board
	end

	local subscribers = board:FindFirstChild("Subscribers")

	if subscribers == nil then
		subscribers = Instance.new("Folder")
		subscribers.Name = "Subscribers"
		subscribers.Parent = board
	end
end

function MetaBoard.Subscribe(subscriber, broadcaster)
	for _, subscriberValue in ipairs(broadcaster.Subscribers:GetChildren()) do
		if subscriberValue.Value == subscriber then return end
	end

	local newSubscriberValue = Instance.new("ObjectValue")
	newSubscriberValue.Name = "SubscriberValue"
	newSubscriberValue.Value = subscriber
	newSubscriberValue.Parent = broadcaster.Subscribers
end

function MetaBoard.GatherSubscriberFamily(board)
	local seen = {board = true}
	local subscriberFamily = {board}
	local function gather(_board)
		for _, subscriberValue in ipairs(_board.Subscribers:GetChildren()) do
			if not seen[subscriberValue.Value] then
				table.insert(subscriberFamily, subscriberValue.Value)
				seen[subscriberValue.Value] = true
				gather(subscriberValue.Value)
			end
		end
	end

	gather(board)
	return subscriberFamily
end

function MetaBoard.UpdateWorldLineHandle(lineHandle, canvas, lineInfo, zIndex)

	local function lerp(a, b, c)
		return a + (b - a) * c
	end

	-- TODO dealing with aspect ratio is gross, figure out square coordinates, similar to GUI

	local aspectRatio = canvas.Size.X / canvas.Size.Y
	local yStuds = canvas.Size.Y

	local boxHandle = lineHandle
	local startHandle = boxHandle.StartHandle
	local stopHandle = boxHandle.StopHandle

	boxHandle.SizeRelativeOffset =
		Vector3.new(
			lerp(1,-1,lineInfo.Centre.X/aspectRatio),
			lerp(1,-1,lineInfo.Centre.Y),
			1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
	boxHandle.Size =
		Vector3.new(
			lineInfo.Length * yStuds,
			lineInfo.ThicknessYScale * yStuds,
			Config.WorldLine.ZThicknessStuds)
	boxHandle.CFrame = CFrame.Angles(0,0,lineInfo.RotationRadians)
	boxHandle.Color3 = lineInfo.Color

	startHandle.SizeRelativeOffset =
		Vector3.new(
			lerp(1,-1,lineInfo.Start.X/aspectRatio),
			lerp(1,-1,lineInfo.Start.Y),
			1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
	startHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
	startHandle.Height = Config.WorldLine.ZThicknessStuds
	startHandle.Color3 = lineInfo.Color

	stopHandle.SizeRelativeOffset =
		Vector3.new(
			lerp(1,-1,lineInfo.Stop.X/aspectRatio),
			lerp(1,-1,lineInfo.Stop.Y),
			1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
	stopHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
	stopHandle.Height = Config.WorldLine.ZThicknessStuds
	stopHandle.Color3 = lineInfo.Color

	return boxHandle
end

function MetaBoard.CreateWorldLine(worldLineType, canvas, lineInfo, zIndex)

	if worldLineType == "HandleAdornments" then

		local boxHandle = Cache.Get("BoxHandleAdornment")

		local startHandle = Cache.Get("CylinderHandleAdornment")
		startHandle.Name = "StartHandle"
		
		local stopHandle = Cache.Get("CylinderHandleAdornment")
		stopHandle.Name = "StopHandle"

		startHandle.Parent = boxHandle
		stopHandle.Parent = boxHandle
		
		MetaBoard.UpdateWorldLineHandle(boxHandle, canvas, lineInfo, zIndex)
		
		startHandle.Adornee = canvas
		stopHandle.Adornee = canvas
		boxHandle.Adornee = canvas

		return boxHandle
	end

	error(worldLineType.." world line type not implemented")
end

function MetaBoard.DiscardLineHandle(lineHandle)
	for _, cylinderHandleAdornment in ipairs(lineHandle:GetChildren()) do
		Cache.Release(cylinderHandleAdornment)
		cylinderHandleAdornment.Parent = nil
	end

	Cache.Release(lineHandle)
	lineHandle.Parent = nil
end

return MetaBoard