-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HapticService = game:GetService("HapticService")

-- Imports
local root = script.Parent.Parent
local Config = require(root.Config)
local DrawingTask = require(root.DrawingTask)
local Destructor = require(root.Destructor)
local Sift = require(root.Parent.Sift)

local Pen = require(script.Pen)
local Eraser = require(script.Eraser)

local isVibrationSupported = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
local rightRumbleSupported = false

if isVibrationSupported then
	rightRumbleSupported = HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand)
end


local VRInput = {}
VRInput.__index = VRInput

function VRInput.new(board, surfaceCanvas)
	
	local self = setmetatable({
		Board = board,
		SurfaceCanvas = surfaceCanvas,
		EquippedTool = Pen,
		EraserSize = 0.05,
		ActiveStroke = false,
		PenActiveDistance = 0.06,
		_destructor = Destructor.new(),
		ToolHeld = false,
	}, VRInput)
	
	self:_connect()

	return self
end

function VRInput:_distanceToBoard(pos)
	local boardLookVector = self.Board.SurfaceCFrame.LookVector
	local vector = pos - self.Board.SurfaceCFrame.Position
	local normalDistance = boardLookVector:Dot(vector)
	return normalDistance
end

function VRInput:_inRange(pos)
	local boardRightVector = self.Board.SurfaceCFrame.RightVector
	local vector = pos - self.Board.SurfaceCFrame.Position
	local strafeDistance = boardRightVector:Dot(vector)
	
	local normalDistance = self:_distanceToBoard(pos)
	
	return (- 5 * self.PenActiveDistance <= normalDistance) and (normalDistance <= self.PenActiveDistance)
	and math.abs(strafeDistance) <= self.Board.SurfaceSize.X/2 + 5
end

function VRInput:_toScalar(position)
	local projPos = self.Board.SurfaceCFrame:ToObjectSpace(CFrame.new(position))
	local sizeX = self.Board.SurfaceSize.X
	local sizeY = self.Board.SurfaceSize.Y
	local relX = (-projPos.X + 0.5*sizeX)/sizeY
	local relY = (-projPos.Y + 0.5*sizeY)/sizeY
	return Vector2.new(relX,relY)
end

function VRInput:_toolDown(penPos)

	-- Must finish tool drawing task before starting a new one
	if self.ToolHeld then
		self:_toolUp()
	end

	local drawingTask = self.EquippedTool.newDrawingTask(self)

	local canvasPos = self:_toScalar(penPos)

	self.Board.Remotes.InitDrawingTask:FireServer(drawingTask, canvasPos)

	local initialisedDrawingTask = DrawingTask.Init(drawingTask, self.Board, canvasPos)

	self.ToolHeld = true

	self.CurrentUnverifiedDrawingTaskId = initialisedDrawingTask.Id
	self.SurfaceCanvas.UnverifiedDrawingTasks[initialisedDrawingTask.Id] = initialisedDrawingTask
end

function VRInput:_toolMoved(penPos)

	if not self.ToolHeld then return end

	local canvasPos = self:_toScalar(penPos)

	local drawingTask = self.SurfaceCanvas.UnverifiedDrawingTasks[self.CurrentUnverifiedDrawingTaskId]

	self.Board.Remotes.UpdateDrawingTask:FireServer(canvasPos)

	local updatedDrawingTask = DrawingTask.Update(drawingTask, self.Board, canvasPos)

	self.SurfaceCanvas.UnverifiedDrawingTasks[updatedDrawingTask.Id] = updatedDrawingTask
end

function VRInput:_toolUp()

	if not self.ToolHeld then return end

	local drawingTask = self.SurfaceCanvas.UnverifiedDrawingTasks[self.CurrentUnverifiedDrawingTaskId]

	local finishedDrawingTask = Sift.Dictionary.set(DrawingTask.Finish(drawingTask, self.Board), "Finished", true)

	self.Board.Remotes.FinishDrawingTask:FireServer()

	self.CurrentUnverifiedDrawingTaskId = nil

	self.ToolHeld = false

	self.SurfaceCanvas.UnverifiedDrawingTasks[finishedDrawingTask.Id] = finishedDrawingTask
end

function VRInput:_connect()

	self._destructor:Add(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
		
		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			self.EquippedTool = Eraser
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonY then
			self.Board.Remotes.Undo:FireServer()
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonX then
			self.Board.Remotes.Redo:FireServer()
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			
			local boardTool = Players.LocalPlayer.Character:FindFirstChild(Config.VR.PenToolName)
			if boardTool == nil then
				print("[metaboard] Cannot find VR tool")
				return
			end
			
			-- We connect to listen to VR pen movements as soon as the trigger is depressed
			-- even if it is too far from the board to draw.
			if self:_inRange(boardTool.Handle.Attachment.WorldPosition) then
				self.ActiveStroke = true
				self:_toolDown(boardTool.Handle.Attachment.WorldPosition)
			end

			self.SurfaceCanvas:render()
			
			self.TriggerActiveConnection = RunService.RenderStepped:Connect(function()
				local penPos = boardTool.Handle.Attachment.WorldPosition
				
				if self:_inRange(penPos) then
					if self.ActiveStroke then
						self:_toolMoved(penPos)
					else
						
						self.ActiveStroke = true
						self:_toolDown(penPos)
					end
					
					-- Rumble increases with distance *through* the board
					local distance = self:_distanceToBoard(penPos)
					if rightRumbleSupported then
						local motorStrength = 0
						if distance >= 0 then
							motorStrength = 0.1
						else
							motorStrength = 0.1 + 0.8 * math.tanh(-distance * 30)
						end
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, motorStrength)
					end
				else
					if self.ActiveStroke then
						self:_toolUp()
						
						self.ActiveStroke = false
						
						if rightRumbleSupported then
							HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
						end
					end
				end

				self.SurfaceCanvas:render()
			end)
		end
		
	end))
	
	self._destructor:Add(UserInputService.InputEnded:Connect(function(input)

		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
		
		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			self.EquippedTool = Pen
		end
		
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			if self.TriggerActiveConnection then
				self.TriggerActiveConnection:Disconnect()
				self.TriggerActiveConnection = nil
			end

			self:_toolUp()
			self.ActiveStroke = false
			
			if rightRumbleSupported then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			end
		end
		
		self.SurfaceCanvas:render()
	end))
	
	self._destructor:Add(function ()
		if self.TriggerActiveConnection then
			self.TriggerActiveConnection:Disconnect()
			self.TriggerActiveConnection = nil
		end
	end)

	self._destructor:Add(function()
		
		if self.ToolHeld then
			self.Board.Remotes.FinishDrawingTask:FireServer()
		end

		if self.SurfaceCanvas then
			
			self.SurfaceCanvas.UnverifiedDrawingTasks = {}
		end
	end)
end

function VRInput:Destroy()
	self._destructor:Destroy()
end

return VRInput