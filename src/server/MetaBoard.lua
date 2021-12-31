local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
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
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		for _, subscriber in ipairs(subscriberFamily) do
			local curve = subscriber.Canvas.Curves:FindFirstChild(curveName)
			if curve then
				MetaBoard.DiscardCurve(curve)
			end
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
		
		if board.HasLoaded.Value then
			board.ChangeUid.Value = HttpService:GenerateGUID(false)
		end
	end)

	DrawingTask.UpdateRemoteEvent.OnServerEvent:Connect(function(player, ...)
		for board, drawingTask in pairs(MetaBoard.DrawingTasksTable[player]) do
			drawingTask.Update(drawingTask.State, ...)
			
			if board.HasLoaded.Value then
				board.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	DrawingTask.FinishRemoteEvent.OnServerEvent:Connect(function(player, ...)
		for board, drawingTask in pairs(MetaBoard.DrawingTasksTable[player]) do
			drawingTask.Finish(drawingTask.State, ...)
		end
	end)

	print("MetaBoard Server "..Config.Version.." initialized")
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

	local clickable = board:FindFirstChild("Clickable")
	if clickable == nil then
		clickable = Instance.new("BoolValue")
		clickable.Name = "Clickable"
		clickable.Value = true

		clickable.Parent = board
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

		if clickable.Value then
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
		end
			
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
	
	local changeUid = board:FindFirstChild("ChangeUid")
	if changeUid ~= nil then
		changeUid:Destroy()
	end
	changeUid = Instance.new("StringValue")
	changeUid.Value = ""
	changeUid.Name = "ChangeUid"
	changeUid.Parent = board
	
	local hasLoaded = board:FindFirstChild("HasLoaded")
	if hasLoaded ~= nil then
		hasLoaded:Destroy()
	end
	hasLoaded = Instance.new("BoolValue")
	hasLoaded.Value = false
	hasLoaded.Name = "HasLoaded"
	hasLoaded.Parent = board
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

function MetaBoard.UpdateWorldLine(worldLineType, line, canvas, lineInfo, zIndex)

	local function lerp(a, b, c)
		return a + (b - a) * c
	end

	local aspectRatio = canvas.Size.X / canvas.Size.Y
	local yStuds = canvas.Size.Y

	if worldLineType == "Parts" then
		line.Size =
			Vector3.new(
				(lineInfo.Length + lineInfo.ThicknessYScale) * yStuds,
				lineInfo.ThicknessYScale * yStuds,
				Config.WorldLine.ZThicknessStuds)

		line.Color = lineInfo.Color

		line.CFrame =
			canvas.CFrame *
			CFrame.new(
				lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Centre.X/aspectRatio), 
				lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Centre.Y),
				canvas.Size.Z/2 - lineInfo.ThicknessYScale * Config.WorldLine.ZThicknessStuds / 2 - zIndex * Config.WorldLine.StudsPerZIndex) *
			CFrame.Angles(0,0,lineInfo.RotationRadians)
	end

	if worldLineType == "RoundedParts" then
		line.Color = lineInfo.Color

		if lineInfo.ThicknessYScale * yStuds >= Config.WorldLine.RoundThresholdStuds then
			line.Size =
				Vector3.new(
					lineInfo.Length * yStuds,
					lineInfo.ThicknessYScale * yStuds,
					Config.WorldLine.ZThicknessStuds)
		else
			line.Size =
				Vector3.new(
					(lineInfo.Length + lineInfo.ThicknessYScale) * yStuds,
					lineInfo.ThicknessYScale * yStuds,
					Config.WorldLine.ZThicknessStuds)
		end

		line.CFrame =
			canvas.CFrame *
			CFrame.new(
				lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Centre.X/aspectRatio), 
				lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Centre.Y),
				canvas.Size.Z/2 - lineInfo.ThicknessYScale * Config.WorldLine.ZThicknessStuds / 2 - zIndex * Config.WorldLine.StudsPerZIndex) *
			CFrame.Angles(0,0,lineInfo.RotationRadians)

		if lineInfo.ThicknessYScale * yStuds >= Config.WorldLine.RoundThresholdStuds then
			line.StartCylinder.Color = lineInfo.Color

			line.StartCylinder.Size =
				Vector3.new(
					Config.WorldLine.ZThicknessStuds,
					lineInfo.ThicknessYScale * yStuds,
					lineInfo.ThicknessYScale * yStuds)

			line.StartCylinder.CFrame =
				canvas.CFrame *
				CFrame.new(
					lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Start.X/aspectRatio), 
					lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Start.Y),
					canvas.Size.Z/2 - lineInfo.ThicknessYScale * Config.WorldLine.ZThicknessStuds / 2 - zIndex * Config.WorldLine.StudsPerZIndex) *
				CFrame.Angles(0,math.pi/2,0)

			line.StopCylinder.Color = lineInfo.Color

			line.StopCylinder.Size =
				Vector3.new(
					Config.WorldLine.ZThicknessStuds,
					lineInfo.ThicknessYScale * yStuds,
					lineInfo.ThicknessYScale * yStuds)

			line.StopCylinder.CFrame =
				canvas.CFrame *
				CFrame.new(
					lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Stop.X/aspectRatio), 
					lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Stop.Y),
					canvas.Size.Z/2 - lineInfo.ThicknessYScale * Config.WorldLine.ZThicknessStuds / 2 - zIndex * Config.WorldLine.StudsPerZIndex) *
				CFrame.Angles(0,math.pi/2,0)
		end
	end

	if worldLineType == "HandleAdornments" then
		line.Size =
			Vector3.new(
				lineInfo.Length * yStuds,
				lineInfo.ThicknessYScale * yStuds,
				Config.WorldLine.ZThicknessStuds)

		line.Color3 = lineInfo.Color
		line.SizeRelativeOffset =
			Vector3.new(
				lerp(1,-1,lineInfo.Centre.X/aspectRatio),
				lerp(1,-1,lineInfo.Centre.Y),
				1 - (Config.WorldLine.ZThicknessStuds / canvas.Size.Z) - Config.WorldLine.StudsPerZIndex * zIndex)
		
		line.CFrame = CFrame.Angles(0,0,lineInfo.RotationRadians)

		local startHandle = line.StartHandle
		local stopHandle = line.StopHandle

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
	end

	return line
end

function MetaBoard.CreateWorldLine(worldLineType, canvas, lineInfo, zIndex)
	local function newSmoothNonPhysicalPart()
		local part = Cache.Get("Part")
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


	if worldLineType == "Parts" then
		local line = newSmoothNonPhysicalPart()
		line.Name = "Line"
		MetaBoard.UpdateWorldLine(worldLineType, line, canvas, lineInfo, zIndex)
		return line
	end

	if worldLineType == "RoundedParts" then
		local line = newSmoothNonPhysicalPart()
		line.Name = "Line"

		if lineInfo.ThicknessYScale * canvas.Size.Y >= Config.WorldLine.RoundThresholdStuds then
			local startCylinder = newSmoothNonPhysicalPart()
			startCylinder.Shape = Enum.PartType.Cylinder
			startCylinder.Name = "StartCylinder"

			local stopCylinder = newSmoothNonPhysicalPart()
			stopCylinder.Shape = Enum.PartType.Cylinder
			stopCylinder.Name = "StopCylinder"

			startCylinder.Parent = line
			stopCylinder.Parent = line
		end

		MetaBoard.UpdateWorldLine(worldLineType, line, canvas, lineInfo, zIndex)
		return line
	end

	if worldLineType == "HandleAdornments" then
		local boxHandle = Cache.Get("BoxHandleAdornment")

		local startHandle = Cache.Get("CylinderHandleAdornment")
		startHandle.Name = "StartHandle"
		
		local stopHandle = Cache.Get("CylinderHandleAdornment")
		stopHandle.Name = "StopHandle"

		startHandle.Parent = boxHandle
		stopHandle.Parent = boxHandle
		
		MetaBoard.UpdateWorldLine(worldLineType, boxHandle, canvas, lineInfo, zIndex)
		
		startHandle.Adornee = canvas
		stopHandle.Adornee = canvas
		boxHandle.Adornee = canvas

		return boxHandle
	end

	error(worldLineType.." world line type not implemented")
end

function MetaBoard.DiscardLine(lineHandle)
	for _, cylinderHandleAdornment in ipairs(lineHandle:GetChildren()) do
		Cache.Release(cylinderHandleAdornment)
	end

	Cache.Release(lineHandle)
end

function MetaBoard.DiscardCurve(curve)
	for _, lineHandle in ipairs(curve:GetChildren()) do
		MetaBoard.DiscardLine(lineHandle)
	end
	Cache.Release(curve)
end

return MetaBoard
