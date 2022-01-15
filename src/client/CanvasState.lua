local VRService = game:GetService("VRService")

local CollectionService = game:GetService("CollectionService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local ClientDrawingTasks = require(script.Parent.ClientDrawingTasks)
local Remotes = Common.Remotes
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local GuiPositioning = require(Common.GuiPositioning)
local BoardGui
local Canvas
local Curves
local Buttons
local Drawing
local storedCameraOffset = nil

local CanvasState = {
	-- the board that is currently displayed on the canvas
	EquippedBoard = nil,

	IsFullConnection = nil,
	HasChangedConnection = nil,

	SurfaceGuiConnections = {},

	HasWritePermission = true,
}

function CanvasState.Init(boardGui)
	BoardGui = boardGui
	Canvas = boardGui.Canvas
	Curves = boardGui.Curves
	
	Buttons = require(script.Parent.Buttons)
	Drawing = require(script.Parent.Drawing)

	BoardGui.Enabled = false
	BoardGui.ModalGui.Enabled = false

	local canvasCamera = Instance.new("Camera")
	canvasCamera.Name = "Camera"
	canvasCamera.Parent = Canvas
	canvasCamera.FieldOfView = 70
	Canvas.CurrentCamera = canvasCamera

	for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
		local clickable = board:WaitForChild("Clickable")
		if clickable.Value == true then
			local canvas = board:WaitForChild("Canvas")
			CanvasState.ConnectOpenBoardButton(board, canvas.SurfaceGui.Button)
		end
	end

	CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(board)
		CanvasState.ConnectOpenBoardButton(board, board:WaitForChild("Canvas").SurfaceGui.Button)
	end)
	CollectionService:GetInstanceRemovedSignal(Config.BoardTag):Connect(function(board)
		if board == CanvasState.EquippedBoard then
			CanvasState.CloseBoard(board)
			if CanvasState.SurfaceGuiConnections[board] ~= nil then
				CanvasState.SurfaceGuiConnections[board]:Disconnect()
			end
		end
	end)

	-- If the Admin system is installed, the permission specified there
	-- overwrites the default "true" state of HasWritePermission
	local adminEvents = game:GetService("ReplicatedStorage"):FindFirstChild("MetaAdmin")
	if adminEvents then
		local canWriteRF = adminEvents:FindFirstChild("CanWrite")

		if canWriteRF then
			CanvasState.HasWritePermission = canWriteRF:InvokeServer()
		end

		-- Listen for updates to the permissions
		local permissionUpdateRE = adminEvents:FindFirstChild("PermissionsUpdate")
		permissionUpdateRE.OnClientEvent:Connect(function()
			-- Request the new permission
			if canWriteRF then
				CanvasState.HasWritePermission = canWriteRF:InvokeServer()
			end
		end)
	end

	CanvasState.ConnectDrawingTaskEvents()

	--print("CanvasState initialized")
end

function CanvasState.ConnectOpenBoardButton(board, button)
	CanvasState.SurfaceGuiConnections[board] =
		board.Canvas.SurfaceGui.Button.Activated:Connect(function()
			if CanvasState.EquippedBoard ~= nil then return end
			CanvasState.OpenBoard(board)
		end)
end

function CanvasState.ConnectDrawingTaskEvents()

	DrawingTask.InitRemoteEvent.OnClientEvent:Connect(function(player, taskType, taskObjectId, ...)
		local taskObject
		if taskType == "Erase" then
			taskObject = Instance.new("Folder")
			taskObject.Name = taskObjectId
			taskObject.Parent = BoardGui.Erases
		else
			taskObject = CanvasState.CreateCurve(CanvasState.EquippedBoard, taskObjectId)
			taskObject.Parent = Curves
		end

		ClientDrawingTasks[taskType].Init(taskObject, ...)

		local playerHistory = BoardGui.History:FindFirstChild(player.UserId)
		if playerHistory == nil then
			playerHistory = History.Init(player)
			playerHistory.Parent = BoardGui.History
		end
		
		History.ForgetFuture(playerHistory, function(futureTaskObject) end)
		History.RecordTaskToHistory(playerHistory, taskObject)
	end)

	DrawingTask.UpdateRemoteEvent.OnClientEvent:Connect(function(taskType, taskObjectId, ...)
		local taskObject = CanvasState.TaskObjectParent(taskType):FindFirstChild(taskObjectId)

		ClientDrawingTasks[taskType].Update(taskObject, ...)
	end)

	DrawingTask.FinishRemoteEvent.OnClientEvent:Connect(function(taskType, taskObjectId, ...)
		local taskObject = CanvasState.TaskObjectParent(taskType):FindFirstChild(taskObjectId)

		ClientDrawingTasks[taskType].Finish(taskObject, ...)
	end)

	Remotes.Undo.OnClientEvent:Connect(function(player)
		local playerHistory = BoardGui.History:FindFirstChild(player.UserId)
		local taskObjectValue = playerHistory.MostRecent.Value

		if taskObjectValue == nil then return end

		if taskObjectValue.Value then
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")

			ClientDrawingTasks[taskType].Undo(taskObjectValue.Value)

			taskObjectValue.Value.Parent = Common.HistoryStorage
		else
			-- This might happen, but shouldn't happen
			print("taskObjectValue not linked to client side value")
		end

		if playerHistory.MostRecent.Value.Parent == playerHistory then
			playerHistory.MostRecent.Value = nil
		else
			playerHistory.MostRecent.Value = playerHistory.MostRecent.Value.Parent
		end
		playerHistory.MostImminent.Value = taskObjectValue
	end)

	Remotes.Redo.OnClientEvent:Connect(function(player)
		local playerHistory = BoardGui.History:FindFirstChild(player.UserId)
		local taskObjectValue = playerHistory.MostImminent.Value

		if taskObjectValue == nil then return end
		
		if taskObjectValue.Value then
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")

			ClientDrawingTasks[taskType].Redo(taskObjectValue.Value)

			taskObjectValue.Value.Parent = CanvasState.TaskObjectParent(taskType)
		else
			-- This might happen, but shouldn't happen
			print("taskObjectValue not linked to client side value")
		end

		playerHistory.MostImminent.Value = playerHistory.MostImminent.Value:FindFirstChildOfClass("ObjectValue")
		playerHistory.MostRecent.Value = taskObjectValue
	end)

	Remotes.Clear.OnClientEvent:Connect(function()
		Drawing.MouseHeld = false
		CanvasState.Clear()
	end)
end

function CanvasState.OpenBoard(board)
	if board:FindFirstChild("PersistId") and not board.HasLoaded.Value then return end
	if VRService.VREnabled then return end

	CanvasState.EquippedBoard = board

	Remotes.WatchingBoard:FireServer(board, true)

	game.StarterGui:SetCore("TopbarEnabled", false)

	Drawing.OnBoardOpen(board)

	Canvas.UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y
	
	-- Turning off board.Canvas.Archivable allows us to clone the board without
	-- cloning the canvas or anything parented to the canvas (like the curves)
	board.Canvas.Archivable = false
	local boardClone = board:Clone()
	board.Canvas.Archivable = true

	boardClone.Name = "BoardClone"
	CollectionService:RemoveTag(boardClone, Config.BoardTag)
	Canvas.Camera.CFrame =
		-- start at the centre of the invisible canvas (looking away from the board)
		board.Canvas.CFrame
		-- move the camera towards board by half the thickness of the invisible canvas (to get to actual board surface)
		-- then move it away so that the board fits perfectly within the FOV.
		-- The horizontal FOV is aligned perfectly by the aspect ratio of BoardGui.Canvas
		-- Equation: tan(verticalFOVAngle/2) = boardHeight/2 / camDistance
		-- Reference: https://developer.roblox.com/en-us/api-reference/property/Camera/FieldOfView
		* CFrame.new(0,0, board.Canvas.Size.Z/2 - board.Canvas.Size.Y/2 / math.tan(math.rad(Canvas.Camera.FieldOfView/2)))
		-- Turn the camera around to look at the board
		* CFrame.Angles(0,math.pi, 0)
	boardClone.Parent = Canvas

	local persistId = board:FindFirstChild("PersistId")
	BoardGui.PersistStatus.Visible = (persistId ~= nil)
	if persistId then
		local fullColor = Color3.new(1, 0, 0)
		local normalColor = Color3.new(0, 0, 0)

		local function reactIsFull(full)
			if full then
				BoardGui.PersistStatus.BackgroundColor3 = fullColor
				BoardGui.PersistStatus.BackgroundTransparency = 0
			else
				BoardGui.PersistStatus.BackgroundColor3 = normalColor
				BoardGui.PersistStatus.BackgroundTransparency = 1
			end
		end

		reactIsFull(board.IsFull.Value)
		CanvasState.IsFullConnection = board.IsFull.Changed:Connect(reactIsFull)

		-- TODO maybe slow?
		local function reactHasChanged(changeUid)
			if changeUid == "" then
				BoardGui.PersistStatus.BackgroundTransparency = 1
			else
				BoardGui.PersistStatus.BackgroundTransparency = 0.5
			end
		end

		reactHasChanged(board.ChangeUid.Value)
		CanvasState.HasChangedConnection = board.ChangeUid.Changed:Connect(reactHasChanged)
	end

	BoardGui.Enabled = true
	BoardGui.ModalGui.Enabled = true

	-- Make the player's camera look from above
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local boardPos = board:GetPivot().Position
	local character = LocalPlayer.Character
	if character and character.Head then
		storedCameraOffset = camera.CFrame.Position - character.Head.Position
	end
	camera.CFrame = CFrame.lookAt(boardPos + Vector3.new(0,Config.Gui.CameraHeight,0), boardPos)

	-- Replicate all of the curves currently on the board
	for _, worldCurve in ipairs(board.Canvas.Curves:GetChildren()) do
		local curve = CanvasState.CreateCurve(board, worldCurve.Name)
		-- TODO decide whether CreateCurve should write the ZIndex or not
		CanvasState.SetZIndex(curve, worldCurve:GetAttribute("ZIndex"))
		for attribute, value in pairs(worldCurve:GetAttributes()) do
			curve:SetAttribute(attribute, value)
		end

		for _, worldLine in ipairs(worldCurve:GetChildren()) do
			local lineInfo = LineInfo.ReadInfo(worldLine)
			local lineFrame = CanvasState.CreateLineFrame(lineInfo)
			lineFrame.Name = worldLine.Name
			if worldLine:GetAttribute("Hidden") then
				lineFrame.Visible = false
			end
			CanvasState.AttachLine(lineFrame, curve)
		end
		curve.Parent = Curves
	end

	-- Replicate all of the erase objects currently in play
	for _, eraseObject in ipairs(board.Canvas.Erases:GetChildren()) do
		local cloneEraseObject = eraseObject:Clone()
		cloneEraseObject.Parent = BoardGui.Erases
	end

	-- Replicate history of every player
	for _, playerHistory in ipairs(board.Canvas.History:GetChildren()) do
		local clonePlayerHistory = playerHistory:Clone()
		clonePlayerHistory.Parent = BoardGui.History

		-- Clone all of the future tasks
		local taskObjectValue = clonePlayerHistory.MostImminent.Value
		while taskObjectValue do
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")
			if taskType == "Erase" then
				taskObjectValue.Value = taskObjectValue.Value:Clone()
			else
				local worldCurve = taskObjectValue.Value
				local curve = CanvasState.CreateCurve(board, worldCurve.Name)

				CanvasState.SetZIndex(curve, worldCurve:GetAttribute("ZIndex"))
				for attribute, value in pairs(worldCurve:GetAttributes()) do
					curve:SetAttribute(attribute, value)
				end

				for _, worldLine in ipairs(worldCurve:GetChildren()) do
					local lineInfo = LineInfo.ReadInfo(worldLine)
					local lineFrame = CanvasState.CreateLineFrame(lineInfo)
					lineFrame.Name = worldLine.Name
					if worldLine.Transparency == 1 then
						lineFrame.Visible = false
					end
					CanvasState.AttachLine(lineFrame, curve)
				end
				taskObjectValue.Value = curve
			end
			
			-- These are future tasks, so are not parented to anything for the client
			taskObjectValue.Value.Parent = Common.HistoryStorage

			-- Go to next one
			taskObjectValue = taskObjectValue:FindFirstChildOfClass("ObjectValue")
		end

		-- Relink all of the past tasks
		-- These are currently linked to workspace things, need to be linked
		-- to their replicated counterparts
		taskObjectValue = clonePlayerHistory.MostRecent.Value
		while taskObjectValue do
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")
			taskObjectValue.Value = CanvasState.TaskObjectParent(taskType):FindFirstChild(taskObjectValue.Value.Name)

			if taskObjectValue.Parent == clonePlayerHistory then
				taskObjectValue = nil
			else
				taskObjectValue = taskObjectValue.Parent
			end
		end

	end

	-- Sync the buttons with the state of the board and equipped tools
	Buttons.OnBoardOpen(board, BoardGui.History:FindFirstChild(LocalPlayer.UserId))
end

local function resetCameraSubject()
	local camera = workspace.CurrentCamera
	if not camera then return end
	if not LocalPlayer.Character then return end

	local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end

	local character = LocalPlayer.Character
	if storedCameraOffset and character.Head then
		camera.CFrame = CFrame.lookAt(character.Head.Position + storedCameraOffset, character.Head.Position)
	end
end

function CanvasState.CloseBoard(board)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	resetCameraSubject()

	BoardGui.Enabled = false
	BoardGui.ModalGui.Enabled = false

	Canvas.BoardClone:Destroy()

	Drawing.OnBoardClose(board)

	if CanvasState.IsFullConnection then
		CanvasState.IsFullConnection:Disconnect()
		CanvasState.IsFullConnection = nil
	end

	if CanvasState.HasChangedConnection then
		CanvasState.HasChangedConnection:Disconnect()
		CanvasState.HasChangedConnection = nil
	end
	
	game.StarterGui:SetCore("TopbarEnabled", true)

	Remotes.WatchingBoard:FireServer(board, false)

	CanvasState.EquippedBoard = nil

	BoardGui.Curves:ClearAllChildren()
	BoardGui.Erases:ClearAllChildren()
	BoardGui.History:ClearAllChildren()
end

function CanvasState.GetCanvasPixelPosition()
	return Vector2.new(Canvas.AbsolutePosition.X, Canvas.AbsolutePosition.Y + 36)
end

function CanvasState.GetScalePositionOnCanvas(pixelPos)
	return (pixelPos - (Canvas.AbsolutePosition + Vector2.new(0,36)))/Canvas.AbsoluteSize.Y
end

function CanvasState.CanvasYScaleToOffset(yScaleValue)
	return yScaleValue * Canvas.AbsoluteSize.Y
end

function CanvasState.CreateCurve(board, curveName)
	local curveGui = Instance.new("ScreenGui")
	curveGui.Name = curveName
	curveGui.IgnoreGuiInset = true
	curveGui.Parent = Curves
	
	local canvasGhost = Instance.new("Frame")
	canvasGhost.Name = "CanvasGhost"
	canvasGhost.AnchorPoint = Vector2.new(0.5,0)
	canvasGhost.Position = UDim2.new(0.5,0,0.125,0)
	canvasGhost.Rotation = 0
	canvasGhost.Size = UDim2.new(0.85,0,0.85,0)
	canvasGhost.SizeConstraint = Enum.SizeConstraint.RelativeXY
	canvasGhost.BackgroundTransparency = 1

	local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y

	local coordinateFrame = Instance.new("Frame")
	coordinateFrame.Name = "CoordinateFrame"
	coordinateFrame.AnchorPoint = Vector2.new(0,0)
	coordinateFrame.Position = UDim2.new(0,0,0,0)
	coordinateFrame.Rotation = 0
	coordinateFrame.Size = UDim2.new(1,0,1,0)
	coordinateFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coordinateFrame.BackgroundTransparency = 1

	UIAspectRatioConstraint.Parent = canvasGhost
	coordinateFrame.Parent = canvasGhost
	canvasGhost.Parent = curveGui

	return curveGui
end

function CanvasState.SetZIndex(curve, zIndex)
	curve.DisplayOrder = zIndex
end

function CanvasState.GetLinesContainer(curve)
	return curve.CanvasGhost.CoordinateFrame
end

function CanvasState.AttachLine(line, curve)
	line.Parent = curve.CanvasGhost.CoordinateFrame
end

function CanvasState.GetParentCurve(line)
	return line.Parent.Parent.Parent
end

function CanvasState.CreateLineFrame(lineInfo)
	local lineFrame = Instance.new("Frame")

	CanvasState.UpdateLineFrame(lineFrame, lineInfo)
	
	-- Round the corners
	if lineInfo.ThicknessYScale * Canvas.AbsoluteSize.Y >= Config.Gui.UICornerThreshold then
		local UICorner = Instance.new("UICorner")
		UICorner.CornerRadius = UDim.new(0.5,0)
		UICorner.Parent = lineFrame
	end

	return lineFrame
end

function CanvasState.UpdateLineFrame(lineFrame, lineInfo)
	lineFrame.Size = UDim2.new(lineInfo.Length + lineInfo.ThicknessYScale, 0, lineInfo.ThicknessYScale, 0)

	lineFrame.Position = UDim2.new(lineInfo.Centre.X, 0, lineInfo.Centre.Y, 0)
	lineFrame.SizeConstraint = Enum.SizeConstraint.RelativeXY
	lineFrame.Rotation = lineInfo.RotationDegrees
	lineFrame.AnchorPoint = Vector2.new(0.5,0.5)
	lineFrame.BackgroundColor3 = lineInfo.Color
	lineFrame.BackgroundTransparency = 0
	lineFrame.BorderSizePixel = 0

	LineInfo.StoreInfo(lineFrame, lineInfo)
end

function CanvasState.Clear()

	BoardGui.Curves:ClearAllChildren()
	BoardGui.Erases:ClearAllChildren()
	BoardGui.History:ClearAllChildren()

	Buttons.SyncUndoButton(nil)
	Buttons.SyncRedoButton(nil)
end

function CanvasState.TaskObjectParent(taskType)
	if taskType == "Erase" then
		return BoardGui.Erases
	else
		return BoardGui.Curves
	end
end

return CanvasState
