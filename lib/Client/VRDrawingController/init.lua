local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local root = script.Parent.Parent
local Client = require(script.Parent)
local Maid = require(root.Util.Maid)
local ValueObject = require(root.Util.ValueObject)
local BoardClient = require(script.Parent.BoardClient)
local Erase = require(script.Parent.Parent.DrawingTask.Erase)
local Rx = require(script.Parent.Parent.Util.Rx)
local FreeHand = require(root.DrawingTask.FreeHand)
local Config = require(root.Config)

local NEARBY_BOARD_RADIUS = 30
local ACTIVE_PEN_DISTANCE = 0.06
local RIGHT_RUMBLE_SUPPORTED = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) and HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand)

local maid = Maid.new()

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
	PenWidth = 0.001,
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

local function observeNearestBoards()
	return Rx.observable(function(sub)
		local cleanup = {}
		local function update()
			local boardSet = {}
			local leftHandCFrame = VRService:GetUserCFrame(Enum.UserCFrame.LeftHand)
			local rightHandCFrame = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
			for _, board in Client.BoardClientBinder:GetAllSet() do
				local boardPos = board:GetSurfaceCFrame().Position
				local close = false
				close = close or (boardPos - leftHandCFrame.Position).Magnitude <= NEARBY_BOARD_RADIUS
				close = close or (boardPos - rightHandCFrame.Position).Magnitude <= NEARBY_BOARD_RADIUS
				if close then
					boardSet[{board, boardPos}] = true
				end
			end
			sub:Fire(boardSet)
		end

		table.insert(cleanup, Client.BoardClientBinder:GetClassAddedSignal():Connect(update))
		table.insert(cleanup, Client.BoardClientBinder:GetClassRemovedSignal():Connect(update))
		table.insert(cleanup, task.spawn(function()
			while true do
				update()
				task.wait(2)
			end
		end))

		return cleanup
	end)
end

local function inActiveRange(pos: Vector3, surfaceCFrame: CFrame, surfaceSize: Vector2): boolean
	local vector = pos - surfaceCFrame.Position
	local strafeDistance = surfaceCFrame.RightVector:Dot(vector)
	local normalDistance = surfaceCFrame.LookVector:Dot(vector)
	
	return 
		(- 5 * ACTIVE_PEN_DISTANCE <= normalDistance) and
		(normalDistance <= ACTIVE_PEN_DISTANCE) and
		math.abs(strafeDistance) <= surfaceSize.X/2 + 5
end

local function toScalar(position: Vector3, surfaceCFrame: CFrame, surfaceSize: Vector2): Vector2
	local projPos = surfaceCFrame:ToObjectSpace(CFrame.new(position))
	local sizeX = surfaceSize.X
	local sizeY = surfaceSize.Y
	local relX = (-projPos.X + 0.5*sizeX)/sizeY
	local relY = (-projPos.Y + 0.5*sizeY)/sizeY
	return Vector2.new(relX,relY)
end

local function finishActiveDrawingTask(activeDrawingTask: ActiveDrawingTask): ()
	local taskId = activeDrawingTask.TaskId
	-- TODO: Does not handle case of destroyed board
	local board = activeDrawingTask.Board
	board:HandleLocalDrawingTaskEvent("FinishDrawingTask", taskId)
	ActiveDrawingTask.Value = nil
end

local function toolDown(pos: Vector3, board: BoardClient.BoardClient): ()

	-- Must finish tool drawing task before starting a new one
	if ActiveDrawingTask.Value then
		finishActiveDrawingTask(ActiveDrawingTask.Value)
	end

	local drawingTask = makeNewDrawingTask()
	local surfaceCFrame = board:GetSurfaceCFrame()
	local surfaceSize = board:GetSurfaceSize()

	local canvasPos = toScalar(pos, surfaceCFrame, surfaceSize)

	board:HandleLocalDrawingTaskEvent("InitDrawingTask", drawingTask.Id, drawingTask, canvasPos)
	ActiveDrawingTask.Value = {
		TaskId = drawingTask.Id,
		Board = board,
		SurfaceCFrame = surfaceCFrame,
		SurfaceSize = surfaceSize,
	}
end

local function toolMoved(pos: Vector3, activeDrawingTask: ActiveDrawingTask)
	local canvasPos = toScalar(pos, activeDrawingTask.SurfaceCFrame, activeDrawingTask.SurfaceSize)

	activeDrawingTask.Board:HandleLocalDrawingTaskEvent("UpdateDrawingTask", activeDrawingTask.TaskId, canvasPos)
end

local function toolUp(activeDrawingTask: ActiveDrawingTask)
	finishActiveDrawingTask(activeDrawingTask)
end

local function setRumble(penTipPos: Vector3, surfaceCFrame: CFrame?)
	if RIGHT_RUMBLE_SUPPORTED then
		if not surfaceCFrame then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			return
		end

		local normal = surfaceCFrame.LookVector.Unit:Dot(penTipPos - surfaceCFrame.Position)
		local motorStrength = 0
		if normal >= 0 then
			motorStrength = 0.1
		else
			motorStrength = 0.1 + 0.8 * math.tanh(-normal * 30)
		end
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, motorStrength)
	end
end

local function watchPen(): Maid.Task
	local cleanup = {}

	table.insert(cleanup, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end

		local board = ClosestBoard.Value
		if not board then
			return
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			EquippedTool.Value = "Eraser"
		end
		if input.KeyCode == Enum.KeyCode.ButtonY then
			board.Remotes.Undo:FireServer()
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			board.Remotes.Redo:FireServer()
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			
			local penTipPos = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
			-- TODO: get the actual VR pen
			
			-- We connect to listen to VR pen movements as soon as the trigger is depressed
			-- even if it is too far from the board to draw.
			if inActiveRange(penTipPos, board:GetSurfaceCFrame(), board:GetSurfaceSize()) then
				toolDown(penTipPos, board)
			end
		end
	end))


	table.insert(cleanup, VRService.UserCFrameChanged:Connect(function(userCFrameType: Enum.UserCFrame, cframe: CFrame)
		if userCFrameType == Enum.UserCFrame.RightHand then
			-- toolMoved(cframe.Position)
			-- TODO: get the actual VR pen
			local penTipPos = cframe.Position
			local activeDrawingTask = ActiveDrawingTask.Value

			if activeDrawingTask then
				if inActiveRange(penTipPos, activeDrawingTask.SurfaceCFrame, activeDrawingTask.SurfaceSize) then
					toolMoved(penTipPos, activeDrawingTask)
					setRumble(penTipPos, activeDrawingTask.SurfaceCFrame)
				else
					toolUp(activeDrawingTask)
					setRumble(penTipPos, nil)
				end
			else
				local board = ClosestBoard.Value
				if board then
					if inActiveRange(penTipPos, board:GetSurfaceCFrame(), board:GetSurfaceSize()) then
						toolDown(penTipPos, board)
					end
					setRumble(penTipPos, board:GetSurfaceCFrame())
				else
					setRumble(penTipPos, nil)
				end
			end
		end
	end))

	return cleanup
end

return {
	
	Start = function(_self)
		if VRService.VREnabled then

			maid._watchPen = watchPen()

			--[[
				Every frame, find the closest board amongst the boards within NEARBY_BOARD_RADIUS
				which is a set of boards updated every 2 seconds
			]]
			maid._closest = observeNearestBoards():Pipe {
				Rx.switchMap(function(boardPosSet)
					return Rx.observable(function(sub)
						return RunService.RenderStepped:Connect(function()
							-- TODO: get actual VR pen
							local penTipPos = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
							local closest, dist = nil, math.huge
							for item in boardPosSet do
								local board, boardPos = item[1], item[2]
								-- TODO: this is bad because it doesn't take into account SurfaceSize
								local boardDist = (boardPos - penTipPos).Magnitude
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
		end
	end
}