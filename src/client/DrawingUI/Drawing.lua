-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local GuiPositioning = require(Common.GuiPositioning)
local Destructor = require(Common.Packages.Destructor)

-- Gui Objects
local BoardGui

local Drawing = {}
Drawing.__index = Drawing

function Drawing.Init(boardGui)

	BoardGui = boardGui
	
	Drawing._maid = Destructor.new()
	

	Drawing.InitCursor()
end

function Drawing.ConnectBoardInput(board)

	Drawing._maid:Add(BoardGui.Canvas.Button.MouseButton1Down:Connect(function(x,y)
		if not Drawing.WithinBounds(x, y, Drawing.EquippedTool.ThicknessYScale) then return end

		-- If the board is persistent and full, no new drawing tasks can be
		-- initiated by interacting with the board, but you can finish the
		-- current task in progress (i.e. we allow ToolMoved, ToolLift)
		if board.PersistId and board.IsFull then return end

		Drawing.UpdateCursor(x,y)
		Drawing.Cursor.Visible = true
		Drawing.ToolDown(board, x,y)
		Drawing.LastMousePixelPos = Vector2.new(x,y)
	end))

	Drawing._maid:Add(BoardGui.Canvas.Button.MouseMoved:Connect(function(x,y)
		if Drawing.MouseHeld then
			if not Drawing.WithinBounds(x, y, Drawing.EquippedTool.ThicknessYScale) then return end

			-- Simple palm rejection
			if UserInputService.TouchEnabled then
				local diff = Vector2.new(x,y) - Drawing.LastMousePixelPos
				if diff.Magnitude > Config.Drawing.MaxLineLengthTouch then return end
			end

			Drawing.ToolMoved(board, x, y)
		end

		Drawing.UpdateCursor(x,y)
		Drawing.LastMousePixelPos = Vector2.new(x,y)
	end))

	Drawing._maid:Add(BoardGui.Canvas.Button.MouseEnter:Connect(function(x,y)
		Drawing.UpdateCursor(x,y)
		Drawing.Cursor.Visible = true
	end))

	Drawing._maid:Add(BoardGui.Canvas.Button.MouseLeave:Connect(function(x,y)
		if Drawing.MouseHeld then
			Drawing.ToolLift(board, x, y)
		end
		Drawing.MouseHeld = false
		Drawing.Cursor.Visible = false
	end))

	Drawing._maid:Add(UserInputService.InputEnded:Connect(function(input, gp)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			or input.UserInputType ~= Enum.UserInputType.Touch
		then return end

		if Drawing.MouseHeld then
			-- input.Position is like an "AbsolutePosition"
			-- the origin that AbsolutePosition values are relative-to is (0,36)
			Drawing.ToolLift(board, input.Position.X, input.Position.Y + 36)
		end
		Drawing.MouseHeld = false
	end))
end

function Drawing.DisconnectBoardInput()
	Drawing._maid:Destroy()
end

function Drawing.WithinBounds(x, y, thicknessYScale)
	local leftBuffer = (x - BoardGui.Canvas.AbsolutePosition.X)/BoardGui.Canvas.AbsoluteSize.Y
	local rightBuffer = (BoardGui.Canvas.AbsolutePosition.X + BoardGui.Canvas.AbsoluteSize.X - x)/BoardGui.Canvas.AbsoluteSize.Y
	local upBuffer = (y - (BoardGui.Canvas.AbsolutePosition.Y + 36))/BoardGui.Canvas.AbsoluteSize.Y
	local downBuffer = ((BoardGui.Canvas.AbsolutePosition.Y + BoardGui.Canvas.AbsoluteSize.Y + 36) - y)/BoardGui.Canvas.AbsoluteSize.Y

	return
		leftBuffer >= thicknessYScale/2 and
		rightBuffer >= thicknessYScale/2 and
		upBuffer >= thicknessYScale/2 and
		downBuffer >= thicknessYScale/2
end

function Drawing.PixelPosToCanvasPos(x, y)
	local offset = BoardGui.IgnoreGuiInset and Vector2.new(0, 32) or Vector2.new(0,0)
	return (Vector2.new(x,y) - (BoardGui.Canvas.AbsolutePosition + offset)) / BoardGui.Canvas.AbsoluteSize.Y
end

function Drawing.ToolDown(board, x, y)

	Drawing.MouseHeld = true

	local canvasPos = Drawing.PixelPosToCanvasPos(x,y)

	local taskId = Config:GenerateUUID()
	local drawingTask = Drawing.EquippedTool:CreateDrawingTask(board, taskId)

	board.PlayerHistory[Players.LocalPlayer]:Append(taskId, drawingTask)

	board.Remotes.InitDrawingTask:FireServer(Players.LocalPlayer, drawingTask.TaskType, taskId, drawingTask, canvasPos)
	drawingTask:Init(canvasPos)


	-- if Drawing.EquippedTool.ToolType == "Eraser" then
	-- 	local eraseObjectId = Config.GenerateUUID()
	-- 	local eraseObject = Instance.new("Folder")
	-- 	eraseObject.Name = eraseObjectId
	-- 	eraseObject.Parent = BoardGui.Erases

	-- 	Drawing.CurrentTaskObject = eraseObject

	-- 	ClientDrawingTasks.Erase.Init(eraseObject, LocalPlayer.UserId, Drawing.EquippedTool.ThicknessYScale, canvasPos)

		
	-- 	History.ForgetFuture(playerHistory)
	-- 	History.RecordTaskToHistory(playerHistory, eraseObject)

	-- 	DrawingTask.InitRemoteEvent:FireServer(
	-- 		CanvasState.EquippedBoard,
	-- 		"Erase",
	-- 		eraseObjectId,
	-- 		LocalPlayer.UserId,
	-- 		Drawing.EquippedTool.ThicknessYScale,
	-- 		canvasPos
	-- 	)
	-- else
	-- 	if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
	-- 		return
	-- 	end

	-- 	if Drawing.EquippedTool.ToolType == "Pen" then
	-- 		local curveId = Config.GenerateUUID()
	-- 		local curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, curveId)
	-- 		Drawing.CurrentTaskObject = curve

	-- 		ClientDrawingTasks[Drawing.PenMode].Init(
	-- 			curve,
	-- 			LocalPlayer.UserId,
	-- 			Drawing.EquippedTool.ThicknessYScale,
	-- 			Drawing.EquippedTool.Color,
	-- 			CanvasState.EquippedBoard.CurrentZIndex.Value,
	-- 			canvasPos
	-- 		)

	-- 		History.ForgetFuture(playerHistory)
	-- 		History.RecordTaskToHistory(playerHistory, curve)

	-- 		DrawingTask.InitRemoteEvent:FireServer(
	-- 			CanvasState.EquippedBoard,
	-- 			Drawing.PenMode,
	-- 			curveId,
	-- 			LocalPlayer.UserId,
	-- 			Drawing.EquippedTool.ThicknessYScale,
	-- 			Drawing.EquippedTool.Color,
	-- 			CanvasState.EquippedBoard.CurrentZIndex.Value,
	-- 			canvasPos
	-- 		)
	-- 	end
	-- end

	-- Buttons.SyncUndoButton(playerHistory)
	-- Buttons.SyncRedoButton(playerHistory)

	Drawing.LastMousePixelPos = Vector2.new(x, y)
end

function Drawing.ToolMoved(board, x, y)
	local newCanvasPos = Drawing.PixelPosToCanvasPos(x, y)

	local drawingTask = board.PlayerHistory[Players.LocalPlayer]:GetCurrent()

	board.Remotes.UpdateDrawingTask:FireServer(newCanvasPos)
	drawingTask:Update(newCanvasPos)

	-- if Drawing.EquippedTool.ToolType == "Eraser" then
	-- 	ClientDrawingTasks.Erase.Update(Drawing.CurrentTaskObject, newCanvasPos)
	-- 	DrawingTask.UpdateRemoteEvent:FireServer(CanvasState.EquippedBoard, "Erase", Drawing.CurrentTaskObject.Name, newCanvasPos)
	-- else
	-- 	assert(Drawing.EquippedTool.ToolType == "Pen")

	-- 	if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
	-- 		Drawing.LastMousePixelPos = Vector2.new(x, y)
	-- 		return
	-- 	end

	-- 	ClientDrawingTasks[Drawing.PenMode].Update(Drawing.CurrentTaskObject, newCanvasPos)
	-- 	DrawingTask.UpdateRemoteEvent:FireServer(CanvasState.EquippedBoard, Drawing.PenMode, Drawing.CurrentTaskObject.Name, newCanvasPos)

	-- end

	Drawing.LastMousePixelPos = Vector2.new(x, y)
end

function Drawing.ToolLift(board, x, y)
	local newCanvasPos = Drawing.PixelPosToCanvasPos(x, y)

	local drawingTask = board.PlayerHistory[Players.LocalPlayer]:GetCurrent()

	board.Remotes.FinishDrawingTask:FireServer(newCanvasPos)
	drawingTask:Finish(newCanvasPos)
	
	-- if Drawing.EquippedTool == "Eraser" then
	-- 	ClientDrawingTasks.Erase.Finish(Drawing.CurrentTaskObject)
	-- 	DrawingTask.FinishRemoteEvent:FireServer(CanvasState.EquippedBoard, "Erase", Drawing.CurrentTaskObject.Name)
	-- elseif Drawing.EquippedTool.ToolType == "Pen" then
	-- 	ClientDrawingTasks[Drawing.PenMode].Finish(Drawing.CurrentTaskObject)
	-- 	DrawingTask.FinishRemoteEvent:FireServer(CanvasState.EquippedBoard, Drawing.PenMode, Drawing.CurrentTaskObject.Name)
	-- end

	-- local playerHistory = BoardGui.History:FindFirstChild(LocalPlayer.UserId)
	-- if playerHistory then
	-- 	History.ForgetOldestUntilSize(playerHistory, Config.History.MaximumSize,
	-- 		function(oldTaskObject) ClientDrawingTasks[oldTaskObject:GetAttribute("TaskType")].Commit(oldTaskObject)
	-- 	end)
	-- end
end

-- Draw/update the cursor for a player's tool on the Gui
function Drawing.InitCursor()
	Drawing.Cursor = Instance.new("Frame")
	Drawing.Cursor.Name = Players.LocalPlayer.Name.."Cursor"
	Drawing.Cursor.Rotation = 0
	Drawing.Cursor.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Drawing.Cursor.AnchorPoint = Vector2.new(0.5,0.5)
	
	-- Make cursor circular
	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0.5,0)
	UICorner.Parent = Drawing.Cursor

	-- Add outline
	local UIStroke = Instance.new("UIStroke")
	UIStroke.Thickness = 1
	UIStroke.Color = Color3.new(0,0,0)
	UIStroke.Parent = Drawing.Cursor

	Drawing.Cursor.Parent = BoardGui
end

function Drawing.UpdateCursor(x,y)
	-- Reposition cursor to new position
	Drawing.Cursor.Position = GuiPositioning.PositionFromPixel(x, y, Drawing.CursorGui.IgnoreGuiInset)

	-- Configure Drawing.Cursor appearance based on tool type
	if Drawing.EquippedTool.IsPen then
		Drawing.Cursor.Size =
			UDim2.new(0, Drawing.EquippedTool.ThicknessYScale, 0, Drawing.EquippedTool.ThicknessYScale)
			* BoardGui.Canvas.AbsoluteSize.Y
		Drawing.Cursor.BackgroundColor3 = Drawing.EquippedTool.Color
		Drawing.Cursor.BackgroundTransparency = 0.5

	elseif Drawing.EquippedTool.ToolType.IsEraser then
		Drawing.Cursor.Size =
			UDim2.new(0, Drawing.EquippedTool.ThicknessYScale, 0, Drawing.EquippedTool.ThicknessYScale)
			* BoardGui.Canvas.AbsoluteSize.Y
		Drawing.Cursor.BackgroundColor3 = Color3.new(1, 1, 1)
		Drawing.Cursor.BackgroundTransparency = 0.5
	end
end

return Drawing