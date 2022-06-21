local VRService = game:GetService("VRService")
local RunService = game:GetService("RunService")

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
local ScreenSpace = require(Common.Packages.ScreenSpace)
local BoardGui
local Canvas
local Curves
local Buttons
local Drawing

local CanvasState = {
	-- the board that is currently displayed on the canvas
	EquippedBoard = nil,

	PersistStatusConnection = nil,

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
	BoardGui.ShadeSelector.Enabled = false

	local canvasCamera = Instance.new("Camera")
	canvasCamera.Name = "Camera"
	canvasCamera.Parent = Canvas
	canvasCamera.FieldOfView = 70
	Canvas.CurrentCamera = canvasCamera

	-- Almost invisible part that sits in front of the camera, the exact size of
	-- the canvas when the gui is up, so that the voice-indicator/mute-toggle doesn't capture
	-- interaction with the canvas.
	local muteButtonBlocker = Instance.new("Part")
	muteButtonBlocker.Name = "MuteButtonBlocker"
	-- If it's fully transparent it won't block anything
	muteButtonBlocker.Transparency = 0.95
	muteButtonBlocker.Anchored = true
	muteButtonBlocker.CanCollide = false
	muteButtonBlocker.CastShadow = false
	muteButtonBlocker.Parent = BoardGui
	CanvasState.MuteButtonBlocker = muteButtonBlocker

	for _, board in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
		local clickable = board:WaitForChild("Clickable")
		if clickable.Value == true then
			local canvas = board:WaitForChild("Canvas")
			CanvasState.ConnectOpenBoardButton(board, canvas.SurfaceGui.Button)
		end
	end

	CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(function(board)
		local canvas = board:WaitForChild("Canvas")
		local surfaceGui = canvas:WaitForChild("SurfaceGui")
		CanvasState.ConnectOpenBoardButton(board, surfaceGui:WaitForChild("Button"))
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
		local canWriteRF = adminEvents:WaitForChild("CanWrite")

		if canWriteRF then
			CanvasState.HasWritePermission = canWriteRF:InvokeServer()
		end

		-- Listen for updates to the permissions
		local permissionUpdateRE = adminEvents:WaitForChild("PermissionsUpdate")
		permissionUpdateRE.OnClientEvent:Connect(function()
			-- Request the new permission
			if canWriteRF then
				CanvasState.HasWritePermission = canWriteRF:InvokeServer()
			end
		end)
	end

	CanvasState.ConnectDrawingTaskEvents()
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
		if CanvasState.EquippedBoard == nil then return end

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
		
		History.ForgetFuture(playerHistory)
		History.RecordTaskToHistory(playerHistory, taskObject)
	end)

	DrawingTask.UpdateRemoteEvent.OnClientEvent:Connect(function(player, taskType, taskObjectId, ...)
		if CanvasState.EquippedBoard == nil then return end

		local taskObject = CanvasState.TaskObjectParent(taskType):FindFirstChild(taskObjectId)

		ClientDrawingTasks[taskType].Update(taskObject, ...)
	end)

	DrawingTask.FinishRemoteEvent.OnClientEvent:Connect(function(player, taskType, taskObjectId, ...)
		if CanvasState.EquippedBoard == nil then return end

		local taskObject = CanvasState.TaskObjectParent(taskType):FindFirstChild(taskObjectId)

		ClientDrawingTasks[taskType].Finish(taskObject, ...)

		local playerHistory = BoardGui.History:FindFirstChild(player.UserId)
		if playerHistory then
			History.ForgetOldestUntilSize(playerHistory, Config.History.MaximumSize,
				function(oldTaskObject) 
					-- BUG: This has crashed with drawingTask = nil
					local drawingTask = ClientDrawingTasks[oldTaskObject:GetAttribute("TaskType")]
					if drawingTask then
						drawingTask.Commit(oldTaskObject)
					end
				end)
		end
	end)

	Remotes.Undo.OnClientEvent:Connect(function(player)
		if CanvasState.EquippedBoard == nil then return end

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
		if CanvasState.EquippedBoard == nil then return end

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
		if CanvasState.EquippedBoard == nil then return end
		
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

	CanvasState.MuteButtonBlocker.Size = Vector3.new(board.Canvas.Size.X, board.Canvas.Size.Y, Config.Gui.MuteButtonBlockerThickness)
	
	local updateMuteButtonBlocker = function()
		local camera = workspace.CurrentCamera

		-- Put the blocker very close to the camera
		local depth = camera.NearPlaneZ + Config.Gui.MuteButtonNearPlaneZOffset
		local width = ScreenSpace.ScreenWidthToWorldWidth(Canvas.AbsoluteSize.X, -depth)
    local height = ScreenSpace.ScreenHeightToWorldHeight(Canvas.AbsoluteSize.Y, -depth)
		local shift = ScreenSpace.ScreenHeightToWorldHeight(camera.ViewportSize.Y/2 - (Canvas.AbsolutePosition.Y + Canvas.AbsoluteSize.Y/2 + 36), -depth)
    
    CanvasState.MuteButtonBlocker.Size = Vector3.new(width, height, CanvasState.MuteButtonBlocker.Size.Z)
    CanvasState.MuteButtonBlocker.CFrame
			= camera.CFrame * CFrame.new(Vector3.new(0, shift, 0))
				+ camera.CFrame.LookVector * (depth + CanvasState.MuteButtonBlocker.Size.Z / 2)
	end

	RunService:BindToRenderStep("UpdateMuteButtonBlocker", Enum.RenderPriority.Camera.Value+1, updateMuteButtonBlocker)
	CanvasState.MuteButtonBlocker.Parent = workspace

	local persistId = board:FindFirstChild("PersistId")
	BoardGui.PersistStatus.Visible = (persistId ~= nil)
	if persistId then
		-- Update the indicator for full or unsaved boards
		local checkDelay = 1
		local counter = 0
		CanvasState.PersistStatusConnection = RunService.Heartbeat:Connect(function(step)
			counter = counter + step
			if counter >= checkDelay then
				counter = counter - checkDelay
				
				local hasChanged = (board.ChangeUid.Value ~= "")
				local persistStatus = BoardGui.PersistStatus

				persistStatus.BackgroundColor3 = Color3.new(0, 0, 0)
				persistStatus.BackgroundTransparency = if hasChanged then 0.5 else 1
			end
		end)
	end

	BoardGui.Enabled = true
	BoardGui.ModalGui.Enabled = true
	BoardGui.ShadeSelector.Enabled = true

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

function CanvasState.CloseBoard(board)
	-- local camera = workspace.CurrentCamera
	-- camera.CameraType = Enum.CameraType.Custom
	-- resetCameraSubject()

	RunService:UnbindFromRenderStep("UpdateMuteButtonBlocker")
	CanvasState.MuteButtonBlocker.Parent = BoardGui

	BoardGui.Enabled = false
	BoardGui.ModalGui.Enabled = false
	BoardGui.ShadeSelector.Enabled = false

	Canvas.BoardClone:Destroy()

	Drawing.OnBoardClose(board)

	if CanvasState.PersistStatusConnection then
		CanvasState.PersistStatusConnection:Disconnect()
		CanvasState.PersistStatusConnection = nil
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
