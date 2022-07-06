-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HapticService = game:GetService("HapticService")
local VRService = game:GetService("VRService")

-- Imports
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local toolFunctions = require(script.toolFunctions)
local ToolQueue = require(script.Parent.ToolQueue)
local Pen = require(script.Pen)
local Eraser = require(script.Eraser)

local isVibrationSupported = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
local rightRumbleSupported = false

if isVibrationSupported then
	rightRumbleSupported = HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand)
end

local localPlayer = Players.LocalPlayer

local function toScalar(position, canvasCFrame, canvasSize)
	local projPos = canvasCFrame:ToObjectSpace(CFrame.new(position))
	local sizeX = canvasSize.X
	local sizeY = canvasSize.Y
	local relX = (-projPos.X + 0.5*sizeX)/sizeY
	local relY = (-projPos.Y + 0.5*sizeY)/sizeY
	return Vector2.new(relX,relY)
end

local function distanceToBoard(self, pos)
	local boardLookVector = self.props.CanvasCFrame.LookVector
	local vector = pos - self.props.CanvasCFrame.Position
	local normalDistance = boardLookVector:Dot(vector)
	return normalDistance
end

local function inRange(self, pos)
	local boardRightVector = self.props.CanvasCFrame.RightVector
	local vector = pos - self.props.CanvasCFrame.Position
	local strafeDistance = boardRightVector:Dot(vector)

	local normalDistance = distanceToBoard(self, pos)
	
	return (- 5 * self.PenActiveDistance <= normalDistance) and (normalDistance <= self.PenActiveDistance)
		and math.abs(strafeDistance) <= self.props.CanvasSize.X/2 + 5
end

return function (self)

	print(self.props.Board._instance.Name..": on")

	local connections = {}

	local toolQueue = ToolQueue(self)
	self.ToolHeld = false
	self.EquippedTool = Pen
	self.EraserSize = 0.02
	self.TriggerActiveConnection = nil
	self.ActiveStroke = false
	self.PenActiveDistance = 0.06

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if not VRService.VREnabled then return end
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end

		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			self.EquippedTool = Eraser
		end

		if input.KeyCode == Enum.KeyCode.ButtonY then
			self.props.Board.Remotes.Undo:FireServer()
		end

		if input.KeyCode == Enum.KeyCode.ButtonX then
			self.props.Board.Remotes.Redo:FireServer()
		end

		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			local boardTool = localPlayer.Character:FindFirstChild(Config.VR.PenToolName)
			if boardTool == nil then
				print("[metaboard] Cannot find VR tool")
				return
			end

			-- We connect to listen to VR pen movements as soon as the trigger is depressed
			-- even if it is too far from the board to draw.
			if inRange(self,boardTool.Handle.Attachment.WorldPosition) then
				toolQueue.Enqueue(function(state)
					return toolFunctions.ToolDown(self, state, toScalar(boardTool.Handle.Attachment.WorldPosition, 
									self.props.CanvasCFrame, self.props.CanvasSize))
				end)

				self.ActiveStroke = true
			end

			if self.TriggerActiveConnection then self.TriggerActiveConnection:Disconnect() end
			self.TriggerActiveConnection = RunService.RenderStepped:Connect(function()
				local penPos = boardTool.Handle.Attachment.WorldPosition

				if inRange(self,penPos) then
					if self.ActiveStroke then
						toolQueue.Enqueue(function(state)
							return toolFunctions.ToolMoved(self, state, toScalar(penPos, self.props.CanvasCFrame, self.props.CanvasSize))
						end)
					else
						toolQueue.Enqueue(function(state)
							return toolFunctions.ToolDown(self, state, toScalar(penPos, self.props.CanvasCFrame, self.props.CanvasSize))
						end)

						self.ActiveStroke = true
					end
				
					-- Rumble increases with distance *through* the board
					local distance = distanceToBoard(self,boardTool.Handle.Attachment.WorldPosition)
					if rightRumbleSupported then
						local motorStrength = 0
						if distance >= 0 then
							motorStrength = 0.2
						else
							motorStrength = 0.2 + 0.8 * math.tanh(-distance * 30)
						end
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, motorStrength)
					end
				else
					toolQueue.Enqueue(function(state)
						return toolFunctions.ToolUp(self, state)
					end)
					self.ActiveStroke = false
					if rightRumbleSupported then
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
					end
				end
			end)
		end

	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if not VRService.VREnabled then return end
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end

		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			self.EquippedTool = Pen
		end

		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			if self.TriggerActiveConnection then self.TriggerActiveConnection:Disconnect() end
			
			toolQueue.Enqueue(function(state)
				return toolFunctions.ToolUp(self, state)
			end)
			self.ActiveStroke = false

			if rightRumbleSupported then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			end
		end

	end))

	return {

		Destroy = function ()
			print(self.props.Board._instance.Name..": off")

			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			toolQueue.Destroy()

		end

	}

end