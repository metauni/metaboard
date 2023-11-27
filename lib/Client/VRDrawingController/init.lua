local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local root = script.Parent.Parent
local Maid = require(root.Util.Maid)
local ValueObject = require(root.Util.ValueObject)
local BoardClient = require(script.Parent.BoardClient)
local Erase = require(script.Parent.Parent.DrawingTask.Erase)
local Blend = require(script.Parent.Parent.Util.Blend)
local Rx = require(script.Parent.Parent.Util.Rx)
local FreeHand = require(root.DrawingTask.FreeHand)
local t = (require)(root.Parent.t)
local Config = require(root.Config)

local DEBUG = false

local NEARBY_BOARD_RADIUS = 50
local ACTIVE_PEN_DISTANCE = 0.06
local RIGHT_RUMBLE_SUPPORTED = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) and HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand)

local ControllerMaid = Maid.new()

type ToolState = { 
	PenWidth: number,
	PenColor: Color3,
	EraserWidth: number,
}

type ActiveDrawingTask = {
	Board: BoardClient.BoardClient,
	-- Not totally necessary but are caching this for hotpath reasons
	SurfaceSize: Vector2,
	SurfaceCFrame: CFrame,
	TaskId: string,
}

local ActiveDrawingTask = ValueObject.new(nil :: ActiveDrawingTask?)

local ClosestBoard = ValueObject.new(nil :: BoardClient.BoardClient?)
local EquippedTool = ValueObject.new("Pen" :: "Pen" | "Eraser")
local ToolState = ValueObject.new({
	PenWidth = 0.002,
	PenColor = Color3.fromHex("#f0f0f0"),
	EraserWidth = 0.05,
} :: ToolState)

local function makeNewDrawingTask()
	local equippedTool = EquippedTool.Value
	local toolState = ToolState.Value
	
	local taskId = Config.GenerateUUID()

	if equippedTool == "Pen" then
		return FreeHand.new(taskId, toolState.PenColor, toolState.PenWidth)
	elseif equippedTool == "Eraser" then
		return Erase.new(taskId, toolState.EraserWidth)
	end
	error(`Bad equippedTool {equippedTool}`)
end

local function inActiveRange(penTipCFrame: CFrame, surfaceCFrame: CFrame, surfaceSize: Vector2): boolean
	local normal = surfaceCFrame.LookVector:Dot(penTipCFrame.Position - surfaceCFrame.Position)
	local projPos = surfaceCFrame:ToObjectSpace(penTipCFrame)
	
	return 
		(- 5 * ACTIVE_PEN_DISTANCE <= normal) and
		(normal <= ACTIVE_PEN_DISTANCE) and
		math.abs(projPos.X) <= surfaceSize.X/2 and
		math.abs(projPos.Y) <= surfaceSize.Y/2
end

local function finishActiveDrawingTask(activeDrawingTask: ActiveDrawingTask): ()
	local taskId = activeDrawingTask.TaskId
	-- TODO: Does not handle case of destroyed board
	local board = activeDrawingTask.Board
	board:HandleLocalDrawingTaskEvent("FinishDrawingTask", taskId)
	ActiveDrawingTask.Value = nil
end

local function toolDown(canvasPos: Vector2, board: BoardClient.BoardClient): ()

	-- Must finish tool drawing task before starting a new one
	if ActiveDrawingTask.Value then
		finishActiveDrawingTask(ActiveDrawingTask.Value)
	end

	local drawingTask = makeNewDrawingTask()
	local surfaceCFrame = board:GetSurfaceCFrame()
	local surfaceSize = board:GetSurfaceSize()

	board:HandleLocalDrawingTaskEvent("InitDrawingTask", drawingTask.Id, drawingTask, canvasPos)
	ActiveDrawingTask.Value = {
		TaskId = drawingTask.Id,
		Board = board,
		SurfaceCFrame = surfaceCFrame,
		SurfaceSize = surfaceSize,
	}
end

local function toolMoved(canvasPos: Vector2, activeDrawingTask: ActiveDrawingTask)
	activeDrawingTask.Board:HandleLocalDrawingTaskEvent("UpdateDrawingTask", activeDrawingTask.TaskId, canvasPos)
end

local function toolUp(activeDrawingTask: ActiveDrawingTask)
	finishActiveDrawingTask(activeDrawingTask)
end

-- TODO: Seems to be a roblox bug making the rumble very weak
local function setRumble(penTipCFrame: CFrame, surfaceCFrame: CFrame?)
	if RIGHT_RUMBLE_SUPPORTED then
		if not surfaceCFrame then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			return
		end

		local normal = surfaceCFrame.LookVector.Unit:Dot(penTipCFrame.Position - surfaceCFrame.Position)
		local motorStrength = 0
		if normal >= 0 then
			motorStrength = 0
		else
			motorStrength = 0.1 + 0.8 * math.tanh(-normal * 30)
		end
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, motorStrength)
	end
end

local function stopRumble()
	if RIGHT_RUMBLE_SUPPORTED then
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
	end
end

local function getMouseCanvasPos(board: BoardClient.BoardClient): Vector2
	local mousePos = UserInputService:GetMouseLocation()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	return Vector2.new(mousePos.X/viewportSize.X * board:GetAspectRatio(), mousePos.Y/viewportSize.Y)
end

local function toPenCanvasPos(penTipCFrame: CFrame, surfaceCFrame: CFrame, surfaceSize: Vector2): Vector2
	-- local ray = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
	-- local raycastResult = workspace:Raycast(ray.Origin, ray.Direction)
	-- if raycastResult then
	-- 	return raycastResult.Position
	-- end

	local projPos = surfaceCFrame:ToObjectSpace(penTipCFrame)
	local sizeX = surfaceSize.X
	local sizeY = surfaceSize.Y
	local canvasX = (-projPos.X + 0.5*sizeX)/sizeY
	local canvasY = (-projPos.Y + 0.5*sizeY)/sizeY
	return Vector2.new(canvasX, canvasY)
end

local function getPenTipCFrame(penTool: Tool): CFrame
	return (penTool :: any).Handle.Attachment.WorldCFrame
end


local function watchPen(penTool: Tool): Maid.Task
	local cleanup: {any} = {}

	local attachment: Attachment = (penTool :: any).Handle.Attachment
	assert(attachment, "Bad Attachment")

	if VRService.VREnabled then

		local PenEquipped = ValueObject.new(penTool:IsDescendantOf(workspace))
		table.insert(cleanup, penTool.AncestryChanged:Connect(function()
			PenEquipped.Value = penTool:IsDescendantOf(workspace)
		end))
		
		local R2Triggerd = ValueObject.new(false)
		table.insert(cleanup, UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				R2Triggerd.Value = input.Position.Z >= 0.5
			end
		end))

		table.insert(cleanup, Rx.combineLatest({
			PenEquipped = PenEquipped:Observe(),
			R2Triggerd = R2Triggerd:Observe(),
		}):Subscribe(function(state)
			if not state.PenEquipped or not state.R2Triggerd then
				if ActiveDrawingTask.Value then
					finishActiveDrawingTask(ActiveDrawingTask.Value)
				end
			end
		end))

		table.insert(cleanup, UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Gamepad1 then
				return
			end
	
			if input.KeyCode == Enum.KeyCode.ButtonL2 then
				EquippedTool.Value = EquippedTool.Value == "Pen" and "Eraser" or "Pen"
			end

			local board = ClosestBoard.Value
			if not board or penTool.Parent ~= Players.LocalPlayer.Character then
				return
			end
			if input.KeyCode == Enum.KeyCode.ButtonY then
				board.Remotes.Undo:FireServer()
			end
			if input.KeyCode == Enum.KeyCode.ButtonX then
				board.Remotes.Redo:FireServer()
			end
		end))

		table.insert(cleanup, VRService.UserCFrameChanged:Connect(function(userCFrameType: Enum.UserCFrame, _cframe: CFrame)

			if not PenEquipped.Value or not R2Triggerd.Value then
				return
			end

			if userCFrameType == Enum.UserCFrame.RightHand then

				local penTipCFrame = getPenTipCFrame(penTool)
				if not penTipCFrame then
					return
				end

				local activeDrawingTask = ActiveDrawingTask.Value
				if activeDrawingTask then
					if inActiveRange(penTipCFrame, activeDrawingTask.SurfaceCFrame, activeDrawingTask.SurfaceSize) then
						local canvasPos = toPenCanvasPos(penTipCFrame, activeDrawingTask.SurfaceCFrame, activeDrawingTask.SurfaceSize)
						toolMoved(canvasPos, activeDrawingTask)
					else
						toolUp(activeDrawingTask)
					end
					setRumble(penTipCFrame, activeDrawingTask.SurfaceCFrame)
				else
					stopRumble()
					local board = ClosestBoard.Value
					if board then
						if inActiveRange(penTipCFrame, board:GetSurfaceCFrame(), board:GetSurfaceSize()) then
							local surfaceCFrame = board:GetSurfaceCFrame()
							local surfaceSize = board:GetSurfaceSize()
							local canvasPos = toPenCanvasPos(penTipCFrame, surfaceCFrame, surfaceSize)
							toolDown(canvasPos, board)
							setRumble(penTipCFrame, surfaceCFrame)
						else
							stopRumble()
						end
					end
				end
			end
		end))

		
	else

		table.insert(cleanup, UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
			
				local board = ClosestBoard.Value
				if not board then
					return
				end
				local canvasPos = getMouseCanvasPos(board)
				
				toolDown(canvasPos, board)
			end
		end))

		table.insert(cleanup, RunService.RenderStepped:Connect(function()
			local activeDrawingTask = ActiveDrawingTask.Value
			if activeDrawingTask then
				local canvasPos = getMouseCanvasPos(activeDrawingTask.Board)
				toolMoved(canvasPos, activeDrawingTask)
			end
		end))

		table.insert(cleanup, UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
				if ActiveDrawingTask.Value then
					toolUp(ActiveDrawingTask.Value)
				end
			end
		end))
	end

	return cleanup
end

local function observeNearestBoards(boardClientBinder)
	return Rx.observable(function(sub)
		local cleanup = {}
		local function update()
			local boards = {}
			local character = Players.LocalPlayer.Character
			if not character or not character:FindFirstChild("HumanoidRootPart") then
				sub:Fire({})
				return
			end
			for board in boardClientBinder:GetAllSet() do
				local boardPos = board:GetSurfaceCFrame().Position
				if (boardPos - character:GetPivot().Position).Magnitude <= NEARBY_BOARD_RADIUS then
					table.insert(boards, {board, boardPos})
				end
			end
			sub:Fire(boards)
		end

		table.insert(cleanup, boardClientBinder:GetClassAddedSignal():Connect(update))
		table.insert(cleanup, boardClientBinder:GetClassRemovedSignal():Connect(update))
		table.insert(cleanup, task.spawn(function()
			while true do
				update()
				task.wait(2)
			end
		end))

		return cleanup
	end)
end

local function debugGui(penTool)

	local function toBoardName(board: BoardClient.BoardClient?)
		if board then
			local boardPart = board:GetPart()
			local persistId = --[[call]](function()
				local persistIdValue = boardPart:FindFirstChild("PersistId")
				if persistIdValue then
					return persistIdValue.Value
				else
					return ""
				end
			end)()
			
			return `{boardPart:GetFullName()} ({persistId})`
		else
			return ""
		end
	end

	return Blend.New "ScreenGui" {
		Blend.New "Frame" {

			AnchorPoint = Vector2.new(0,0.5),
			Position = UDim2.fromScale(0,0.5),
			Size = UDim2.fromOffset(400, 100),

			Blend.New "UIListLayout" {},

			Blend.New "TextLabel" {
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 50),

				Text = Blend.Computed(ClosestBoard, function(board)
					return `ClosestBoard: {toBoardName(board)}`
				end)
			},
			Blend.New "TextLabel" {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 50),

				TextXAlignment = Enum.TextXAlignment.Left,
				
				Text = Blend.Computed(ClosestBoard, Rx.fromSignal(RunService.RenderStepped), function(board, _)
					local penTipCFrame = getPenTipCFrame(penTool)
					if not board or not penTipCFrame then
						return ""
					end
					local distance = (board:GetSurfaceCFrame().Position - penTipCFrame.Position).Magnitude
					return `Distance: {distance}`
				end)
			},
			Blend.New "TextLabel" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 100),

				Text = Blend.Computed(ActiveDrawingTask, function(activeDrawingTask: ActiveDrawingTask)
					if not activeDrawingTask then
						return ""
					end
					local taskId = activeDrawingTask.TaskId
					local boardName = toBoardName(activeDrawingTask.Board)
					return `ActiveDrawingTask: {taskId}. Board: {boardName}`
				end),

				BackgroundColor3 = Blend.Computed(ActiveDrawingTask, function(activeDrawingTask: ActiveDrawingTask)
					return if activeDrawingTask then Color3.new(0, 0.8, 0) else Color3.new(1,1,1)
				end),
			},
		}
	}
end

return {
	
	StartWithBinder = function(boardClientBinder)

		if VRService.VREnabled then

			local penToolTemplate = ReplicatedStorage:FindFirstChild("Chalk")
			assert(t.instanceOf("Tool", {
				Handle = t.instanceOf("MeshPart", {
					Attachment = t.instanceOf("Attachment")
				})
			})(penToolTemplate))

			local penTool: Tool = penToolTemplate:Clone()
			penTool.CanBeDropped = false
			penTool.Parent = Players.LocalPlayer:WaitForChild("Backpack")
			
			ControllerMaid._watchPen = watchPen(penTool)

			--[[
				Every frame, find the closest board amongst the boards within NEARBY_BOARD_RADIUS
				which is a set of boards updated every 2 seconds
			]]
			ControllerMaid._closest = observeNearestBoards(boardClientBinder):Pipe {
				Rx.switchMap(function(boards)
					return Rx.observable(function(sub)
						return RunService.RenderStepped:Connect(function()
							local penTipCFrame = getPenTipCFrame(penTool)
							if not penTipCFrame then
								sub:Fire(nil)
								return
							end
							
							local closest, dist = nil, math.huge
							for _, item in boards do
								local board, boardPos = item[1], item[2]
								if not board:GetPart():IsDescendantOf(workspace) then
									continue
								end
								-- TODO: this is bad because it doesn't take into account SurfaceSize
								local boardDist = (boardPos - penTipCFrame.Position).Magnitude
								if boardDist < dist then
									closest, dist = board, boardDist
								end
							end
							sub:Fire(closest)
						end)
					end)
				end)
			}:Subscribe(function(closestBoard: BoardClient.BoardClient?)
				ClosestBoard.Value = closestBoard
			end)

			if DEBUG and Players.LocalPlayer.UserId == 2293079954 then
				ControllerMaid._debug = Blend.mount(Players.LocalPlayer.PlayerGui, {
					debugGui(penTool)
				})
			end
		end
	end
}