local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local History = require(Common.History)
local Remotes = Common.Remotes
local LineInfo = require(Common.LineInfo)
local DrawingTask = require(Common.DrawingTask)
local ServerDrawingTasks, Persistence

local MetaBoard = {}
MetaBoard.__index = MetaBoard

function MetaBoard.Init()

	ServerDrawingTasks = require(script.Parent.ServerDrawingTasks)
	Persistence = require(script.Parent.Persistence)

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

	Remotes.WatchingBoard.OnServerEvent:Connect(function(player, board, isWatching)
		local watcherValue = board.Watchers:FindFirstChild(player.UserId)
		if isWatching then
			if watcherValue == nil then
				watcherValue = Instance.new("ObjectValue")
				watcherValue.Name = player.UserId
				watcherValue.Value = player
				watcherValue.Parent = board.Watchers
			end
		else
			if watcherValue then
				watcherValue:Destroy()
			end
		end
	end)

	DrawingTask.InitRemoteEvent.OnServerEvent:Connect(function(player, board, taskType, taskObjectId, ...)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)

		for _, subscriber in ipairs(subscriberFamily) do
			local persistId = subscriber:FindFirstChild("PersistId")
			if persistId and not subscriber.HasLoaded.Value then continue end
			if subscriber.IsFull.Value then continue end

			local taskObject = Instance.new("Folder")
			taskObject.Name = taskObjectId
			taskObject.Parent = MetaBoard.TaskObjectParent(subscriber, taskType)

			ServerDrawingTasks[taskType].Init(subscriber, taskObject, ...)

			local playerHistory = subscriber.Canvas.History:FindFirstChild(player.UserId)
			if playerHistory == nil then
				playerHistory = History.Init(player)
				playerHistory.Parent = subscriber.Canvas.History
			end
			
			History.ForgetFuture(playerHistory)
			History.RecordTaskToHistory(playerHistory, taskObject)

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					DrawingTask.InitRemoteEvent:FireClient(watcherValue.Value, player, taskType, taskObjectId, ...)
				end
			end

			if persistId and subscriber.HasLoaded.Value then
				-- Mark this persistent board as changed
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	DrawingTask.UpdateRemoteEvent.OnServerEvent:Connect(function(player, board, taskType, taskObjectId, ...)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		for _, subscriber in ipairs(subscriberFamily) do
			local taskObject = MetaBoard.TaskObjectParent(subscriber, taskType):FindFirstChild(taskObjectId)
			if taskObject == nil then continue end

			ServerDrawingTasks[taskType].Update(subscriber, taskObject, ...)

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					DrawingTask.UpdateRemoteEvent:FireClient(watcherValue.Value, player, taskType, taskObjectId, ...)
				end
			end

			if subscriber:FindFirstChild("PersistId") and subscriber.HasLoaded.Value then
				-- Mark this persistent board as changed
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	DrawingTask.FinishRemoteEvent.OnServerEvent:Connect(function(player, board, taskType, taskObjectId, ...)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)		
		for _, subscriber in ipairs(subscriberFamily) do
			local taskObject = MetaBoard.TaskObjectParent(subscriber, taskType):FindFirstChild(taskObjectId)
			if taskObject == nil then continue end
			
			ServerDrawingTasks[taskType].Finish(subscriber, taskObject, ...)

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					DrawingTask.FinishRemoteEvent:FireClient(watcherValue.Value, player, taskType, taskObjectId, ...)
				end
			end

			local playerHistory = subscriber.Canvas.History:FindFirstChild(player.UserId)
			if playerHistory then
				History.ForgetOldestUntilSize(playerHistory, Config.History.MaximumSize,
					function(oldTaskObject) ServerDrawingTasks[oldTaskObject:GetAttribute("TaskType")].Commit(subscriber, oldTaskObject)
				end)
			end

			if subscriber:FindFirstChild("PersistId") and subscriber.HasLoaded.Value then
				-- Mark this persistent board as changed
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	local historyStorage = Instance.new("Folder")
	historyStorage.Name = "HistoryStorage"
	historyStorage.Parent = Common

	Remotes.Undo.OnServerEvent:Connect(function(player, board)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		for _, subscriber in ipairs(subscriberFamily) do
			if subscriber:FindFirstChild("PersistId") then
				if not subscriber.HasLoaded.Value then continue end
			end

			if subscriber.IsFull.Value then continue end

			local playerHistory = subscriber.Canvas.History:FindFirstChild(player.UserId)
			local taskObjectValue = playerHistory.MostRecent.Value

			if taskObjectValue == nil then continue end

			local taskType = taskObjectValue.Value:GetAttribute("TaskType")

			ServerDrawingTasks[taskType].Undo(subscriber, taskObjectValue.Value)

			taskObjectValue.Value.Parent = historyStorage

			if playerHistory.MostRecent.Value.Parent == playerHistory then
				playerHistory.MostRecent.Value = nil
			else
				playerHistory.MostRecent.Value = playerHistory.MostRecent.Value.Parent
			end
			playerHistory.MostImminent.Value = taskObjectValue

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					Remotes.Undo:FireClient(watcherValue.Value, player)
				end
			end

			if subscriber:FindFirstChild("PersistId") and subscriber.HasLoaded.Value then
				-- Mark this persistent board as changed
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	Remotes.Redo.OnServerEvent:Connect(function(player, board)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		for _, subscriber in ipairs(subscriberFamily) do
			if subscriber:FindFirstChild("PersistId") then
				if not subscriber.HasLoaded.Value then continue end
			end

			if subscriber.IsFull.Value then continue end

			local playerHistory = subscriber.Canvas.History:FindFirstChild(player.UserId)
			local taskObjectValue = playerHistory.MostImminent.Value

			if taskObjectValue == nil then continue end

			local taskType = taskObjectValue.Value:GetAttribute("TaskType")

			ServerDrawingTasks[taskType].Redo(subscriber, taskObjectValue.Value)

			taskObjectValue.Value.Parent = MetaBoard.TaskObjectParent(subscriber, taskType)

			playerHistory.MostImminent.Value = playerHistory.MostImminent.Value:FindFirstChildOfClass("ObjectValue")
			playerHistory.MostRecent.Value = taskObjectValue

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					Remotes.Redo:FireClient(watcherValue.Value, player)
				end
			end

			if subscriber:FindFirstChild("PersistId") and subscriber.HasLoaded.Value then
				-- Mark this persistent board as changed
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
			end
		end
	end)

	Remotes.Clear.OnServerEvent:Connect(function(player, board)
		local subscriberFamily = MetaBoard.GatherSubscriberFamily(board)
		
		for _, subscriber in ipairs(subscriberFamily) do
			local persistId = subscriber:FindFirstChild("PersistId")
			if persistId and not subscriber.HasLoaded.Value then continue end

			if persistId then
				subscriber.ClearCount.Value = subscriber.ClearCount.Value + 1

				-- Store this as a historical version of the board
				local boardKey = Persistence.KeyForBoard(subscriber)
				boardKey = boardKey .. ":" .. subscriber.ClearCount.Value
				Persistence.Store(subscriber, boardKey)
			end

			for _, watcherValue in ipairs(subscriber.Watchers:GetChildren()) do
				if watcherValue.Value ~= player then
					Remotes.Clear:FireClient(watcherValue.Value)
				end
			end

			subscriber.Canvas.Curves:ClearAllChildren()
			subscriber.Canvas.Erases:ClearAllChildren()
			subscriber.Canvas.History:ClearAllChildren()

			subscriber.CurrentZIndex.Value = 0

			if persistId then
				subscriber.ChangeUid.Value = HttpService:GenerateGUID(false)
				subscriber.IsFull.Value = false
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
			local playerHistory = board.Canvas.History:FindFirstChild(player.UserId)
			if playerHistory then
				History.ForgetPastAndFuture(playerHistory, function(oldTaskObject)
					ServerDrawingTasks[oldTaskObject:GetAttribute("TaskType")].Commit(board, oldTaskObject)
				end)
				playerHistory:Destroy()
			end
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

		local surfacePart
		if board:IsA("Model") then
			assert(board.PrimaryPart, "Metaboard model must have PrimaryPart")
			surfacePart = board.PrimaryPart
		else
			surfacePart = board
		end

		local dimensions = MetaBoard.GetSurfaceDimensions(surfacePart, face.Value)
		canvas.Size = Vector3.new(dimensions.X, dimensions.Y, Config.WorldBoard.CanvasThickness)
		canvas.CFrame = MetaBoard.GetSurfaceCFrame(surfacePart, face.Value) * CFrame.new(0,0,-canvas.Size.Z/2)
		canvas.Transparency = 1

		local weldConstraint = Instance.new("WeldConstraint")
		weldConstraint.Part0 = surfacePart
		weldConstraint.Part1 = canvas
		weldConstraint.Parent = board

		local curves = Instance.new("Folder")
		curves.Name = "Curves"
		curves.Parent = canvas

		local erases = Instance.new("Folder")
		erases.Name = "Erases"
		erases.Parent = canvas

		local history = Instance.new("Folder")
		history.Name = "History"
		history.Parent = canvas

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

	local watchers = board:FindFirstChild("Watchers")

	if watchers == nil then
		watchers = Instance.new("Folder")
		watchers.Name = "Watchers"
		watchers.Parent = board
	end
	
	local changeUid = board:FindFirstChild("ChangeUid")
	if changeUid ~= nil then
		changeUid:Destroy()
	end
	changeUid = Instance.new("StringValue")
	changeUid.Value = ""
	changeUid.Name = "ChangeUid"
	changeUid.Parent = board
	
	-- Meaningful only for persistent boards
	local hasLoaded = board:FindFirstChild("HasLoaded")
	if hasLoaded ~= nil then
		hasLoaded:Destroy()
	end
	hasLoaded = Instance.new("BoolValue")
	hasLoaded.Value = false
	hasLoaded.Name = "HasLoaded"
	hasLoaded.Parent = board

	local isFull = board:FindFirstChild("IsFull")
	if isFull ~= nil then
		isFull:Destroy()
	end
	isFull = Instance.new("BoolValue")
	isFull.Value = false
	isFull.Name = "IsFull"
	isFull.Parent = board

	-- Persistent boards track how many times they have been cleared
	if board:FindFirstChild("PersistId") then
		local clearCount = board:FindFirstChild("ClearCount")
		if clearCount ~= nil then
			clearCount:Destroy()
		end

		clearCount = Instance.new("IntValue")
		clearCount.Value = 0
		clearCount.Name = "ClearCount"
		clearCount.Parent = board
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

function MetaBoard.UpdateWorldLine(worldLineType, worldLine, canvas, lineInfo, zIndex)

	local function lerp(a, b, c)
		return a + (b - a) * c
	end

	local aspectRatio = canvas.Size.X / canvas.Size.Y
	local yStuds = canvas.Size.Y

	if worldLineType == "Parts" then
		worldLine.Size =
			Vector3.new(
				(lineInfo.Length + lineInfo.ThicknessYScale) * yStuds,
				lineInfo.ThicknessYScale * yStuds,
				Config.WorldBoard.ZThicknessStuds)

		worldLine.Color = lineInfo.Color

		worldLine.CFrame =
			canvas.CFrame *
			CFrame.new(
				lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Centre.X/aspectRatio), 
				lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Centre.Y),
				canvas.Size.Z/2 - Config.WorldBoard.ZThicknessStuds / 2 - Config.WorldBoard.InitialZOffsetStuds - zIndex * Config.WorldBoard.StudsPerZIndex) *
			CFrame.Angles(0,0,lineInfo.RotationRadians)
	end

	if worldLineType == "RoundedParts" then
		worldLine.Color = lineInfo.Color
		
		if lineInfo.ThicknessYScale * yStuds >= Config.WorldBoard.RoundThresholdStuds then
			worldLine.Size =
				Vector3.new(
					lineInfo.Length * yStuds,
					lineInfo.ThicknessYScale * yStuds,
					Config.WorldBoard.ZThicknessStuds)
		else
			worldLine.Size =
				Vector3.new(
					(lineInfo.Length + lineInfo.ThicknessYScale) * yStuds,
					lineInfo.ThicknessYScale * yStuds,
					Config.WorldBoard.ZThicknessStuds)
		end

		worldLine.CFrame =
			canvas.CFrame *
			CFrame.new(
				lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Centre.X/aspectRatio), 
				lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Centre.Y),
				canvas.Size.Z/2 - Config.WorldBoard.ZThicknessStuds / 2 - Config.WorldBoard.InitialZOffsetStuds - zIndex * Config.WorldBoard.StudsPerZIndex) *
			CFrame.Angles(0,0,lineInfo.RotationRadians)

    if lineInfo.ThicknessYScale * yStuds >= Config.WorldBoard.RoundThresholdStuds then
      worldLine.StartCylinder.Color = lineInfo.Color

      worldLine.StartCylinder.Size =
        Vector3.new(
          Config.WorldBoard.ZThicknessStuds,
          lineInfo.ThicknessYScale * yStuds,
          lineInfo.ThicknessYScale * yStuds)

      worldLine.StartCylinder.CFrame =
        canvas.CFrame *
        CFrame.new(
          lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Start.X/aspectRatio), 
          lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Start.Y),
          canvas.Size.Z/2 - Config.WorldBoard.ZThicknessStuds / 2 - Config.WorldBoard.InitialZOffsetStuds - zIndex * Config.WorldBoard.StudsPerZIndex) *
          CFrame.Angles(0,math.pi/2,0)

      worldLine.StopCylinder.Color = lineInfo.Color

      worldLine.StopCylinder.Size =
        Vector3.new(
          Config.WorldBoard.ZThicknessStuds,
          lineInfo.ThicknessYScale * yStuds,
          lineInfo.ThicknessYScale * yStuds)

      worldLine.StopCylinder.CFrame =
        canvas.CFrame *
        CFrame.new(
          lerp(canvas.Size.X/2,-canvas.Size.X/2,lineInfo.Stop.X/aspectRatio), 
          lerp(canvas.Size.Y/2,-canvas.Size.Y/2,lineInfo.Stop.Y),
          canvas.Size.Z/2 - Config.WorldBoard.ZThicknessStuds / 2 - Config.WorldBoard.InitialZOffsetStuds - zIndex * Config.WorldBoard.StudsPerZIndex) *
          CFrame.Angles(0,math.pi/2,0)
		end
	end

	if worldLineType == "HandleAdornments" then
		worldLine.Size =
			Vector3.new(
				lineInfo.Length * yStuds,
				lineInfo.ThicknessYScale * yStuds,
				Config.WorldBoard.ZThicknessStuds)

		worldLine.Color3 = lineInfo.Color
		worldLine.SizeRelativeOffset =
			Vector3.new(
				lerp(1,-1,lineInfo.Centre.X/aspectRatio),
				lerp(1,-1,lineInfo.Centre.Y),
				1 - (Config.WorldBoard.ZThicknessStuds / canvas.Size.Z) - Config.WorldBoard.InitialZOffsetStuds - Config.WorldBoard.StudsPerZIndex * zIndex)
		
		worldLine.CFrame = CFrame.Angles(0,0,lineInfo.RotationRadians)

		local startHandle = worldLine.StartHandle
		local stopHandle = worldLine.StopHandle

		startHandle.SizeRelativeOffset =
			Vector3.new(
				lerp(1,-1,lineInfo.Start.X/aspectRatio),
				lerp(1,-1,lineInfo.Start.Y),
				1 - (Config.WorldBoard.ZThicknessStuds / canvas.Size.Z) - Config.WorldBoard.InitialZOffsetStuds - Config.WorldBoard.StudsPerZIndex * zIndex)
		startHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
		startHandle.Height = Config.WorldBoard.ZThicknessStuds
		startHandle.Color3 = lineInfo.Color

		stopHandle.SizeRelativeOffset =
			Vector3.new(
				lerp(1,-1,lineInfo.Stop.X/aspectRatio),
				lerp(1,-1,lineInfo.Stop.Y),
				1 - (Config.WorldBoard.ZThicknessStuds / canvas.Size.Z) - Config.WorldBoard.InitialZOffsetStuds - Config.WorldBoard.StudsPerZIndex * zIndex)
		stopHandle.Radius = lineInfo.ThicknessYScale / 2 * yStuds
		stopHandle.Height = Config.WorldBoard.ZThicknessStuds
		stopHandle.Color3 = lineInfo.Color
	end

	LineInfo.StoreInfo(worldLine, lineInfo)

	return worldLine
end

function MetaBoard.CreateWorldLine(worldLineType, canvas, lineInfo, zIndex)
	local function newSmoothNonPhysicalPart()
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


	if worldLineType == "Parts" then
		local line = newSmoothNonPhysicalPart()
		line.Name = "Line"
		MetaBoard.UpdateWorldLine(worldLineType, line, canvas, lineInfo, zIndex)
		return line
	end

	if worldLineType == "RoundedParts" then
		local line = newSmoothNonPhysicalPart()
		line.Name = "Line"

		if lineInfo.ThicknessYScale * canvas.Size.Y >= Config.WorldBoard.StudsPerZIndex then
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
		local boxHandle = Instance.new("BoxHandleAdornment")

		local startHandle = Instance.new("CylinderHandleAdornment")
		startHandle.Name = "StartHandle"
		
		local stopHandle = Instance.new("CylinderHandleAdornment")
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

function MetaBoard.HideWorldLine(worldLineType, worldLine)

	if worldLineType == "Parts" then
		worldLine.Transparency = 1
	elseif worldLineType == "RoundedParts" then
		worldLine.Transparency = 1
		if worldLine.StartCylinder then
			worldLine.StartCylinder.Transparency = 1
		end
		if worldLine.StopCylinder then
			worldLine.StopCylinder.Transparency = 1
		end
	elseif worldLineType == "HandleAdornments" then
		worldLine.Visible = false
		worldLine.StartHandle.Visible = false
		worldLine.StartHandle.Visible = false
	else
		error(worldLineType.." world line type not implemented")
	end

	worldLine:SetAttribute("Hidden", true)
end

function MetaBoard.ShowWorldLine(worldLineType, worldLine)

	if worldLineType == "Parts" then
		worldLine.Transparency = 0
	elseif worldLineType == "RoundedParts" then
		worldLine.Transparency = 0
		if worldLine.StartCylinder then
			worldLine.StartCylinder.Transparency = 0
		end
		if worldLine.StopCylinder then
			worldLine.StopCylinder.Transparency = 0
		end
	elseif worldLineType == "HandleAdornments" then
		worldLine.Visible = true
		worldLine.StartHandle.Visible = true
		worldLine.StartHandle.Visible = true
	else
		error(worldLineType.." world line type not implemented")
	end

	worldLine:SetAttribute("Hidden", nil)
end


function MetaBoard.TaskObjectParent(board, taskType)
	if taskType == "Erase" then
		return board.Canvas.Erases
	else
		return board.Canvas.Curves
	end
end

return MetaBoard
