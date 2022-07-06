-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local VRService = game:GetService("VRService")
local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
--local BoardClient = require(script.BoardClient)
--local BoardRemotes = require(Common.BoardRemotes)
local nearestBoard = require(script.Parent.nearestBoards)

local State = {
    EraserMode = false,
    PrevMousePos = nil,
    MousePos = nil,
    ButtonHeld = nil,
    DrawingConnection = nil
}

local vibrationSupported = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
local rightRumbleSupported
if vibrationSupported then
    rightRumbleSupported = HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand)
end

print("VR.client.lua")

UserInputService.InputBegan:Connect(function(input, gp)
	if not VRService.VREnabled then return end
	print("in here")
	
    --local Character = Players.LocalPlayer.Character

--     local boards = CollectionService:GetTagged(Config.BoardTag)
--    -- local lBoard = nearestBoard(boards, localPlayer.Character.PrimaryPart.Position, 1)[1]
--     --if lBoard == nil then
--    --     print("[metaboard] Could not find board")
--    --     return
--     --end

--     --local lBoardPart = if lBoard:IsA("Part") then lBoard else lBoard.PrimaryPart

-- 	local boardTool = Character:FindFirstChild("VRpen")	
-- 	if boardTool == nil then
--         print("[metaboard] Could not find board tool")
--         return
--     end
	
	if input.UserInputType == Enum.UserInputType.Gamepad1 then
		-- Hold the right trigger to write
		print("Got VR input")
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			print("Got button R2")
			State.MousePos = nil

			if State.DrawingConnection then State.DrawingConnection:Disconnect() end

			State.DrawingConnection = RunService.Heartbeat:Connect(function(step)
				-- See if the pen is close to the personal board
				local touching = game.Workspace:GetPartsInPart(lBoard.BoardHitbox)
				local foundTouching = false

				for i, v in pairs(touching) do
					if v == boardTool.Handle then
						foundTouching = true
						State.ButtonHeld = true

						local penPos = boardTool.Handle.Attachment.WorldPosition
						local penTrans = lBoardPart.CFrame:ToObjectSpace(CFrame.new(penPos))
						local sizeX = lBoardPart.Size.X
						local sizeY = lBoardPart.Size.Y
						local relX = (penTrans.X + 0.5*sizeX)/sizeX
						local relY = (penTrans.Y + 0.5*sizeY)/sizeY

						if State.MousePos == nil then
							--lBoard.CurveIndex += 1
							State.MousePos = Vector2.new(relX, relY)
							State.PrevMousePos = State.MousePos
						else
							State.PrevMousePos = State.MousePos
							State.MousePos = Vector2.new(relX, relY)
						end
						
						if State.EraserMode then
							--State.Erase(lBoard, State.RelativeToAbsolute(State.MousePos), State.EraserThickness/2)
						else
							--lBoard:DrawLine(State.ThisPlayer.Name.."#"..lBoard.CurveIndex, State.PrevMousePos,  State.MousePos, State.RelativeToAbsolute(State.PrevMousePos), State.RelativeToAbsolute(State.MousePos), State.PenThickness, State.PenColor)
							print("Drawing at "..State.MousePos)
							-- Before sending to the server, draw our own copy locally
							-- LocalBoardDrawLine(personalBoard.Board, lBoard, lBoard.CurveIndex, State.PrevMousePos, State.MousePos, State.PenThickness, State.PenThickness / State.GetCanvasAbsSize().Y, State.PenColor)
						
							--WBDrawEvent:FireServer(lBoard.Name, State.ThisPlayer.Name, lBoard.CurveIndex, State.PrevMousePos, State.MousePos, State.PenThickness, State.PenThickness / State.GetCanvasAbsSize().Y, State.PenColor)
						end
					end
				end

				-- The user lifted the pen off the board, reset to new curve
				if foundTouching then
					if rightRumbleSupported then
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, .2)
					end
				else
					State.MousePos = nil

					if rightRumbleSupported then
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
					end
				end

				wait(0.01)
			end)
		end

		-- Press the left trigger to undo
		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			--if lBoard.CurveIndex == 0 then return end
            print("Undoing")
			--lBoard:DeleteCurve(State.ThisPlayer.Name.."#"..lBoard.CurveIndex)
			--WBUndoEvent:FireServer(lBoard.Name, State.ThisPlayer.Name, lBoard.CurveIndex)
			--lBoard.CurveIndex -= 1
		end
	end
end)

-- DEBUG should match with global config
local Z_OFFSET_PER_CURVE = 0.001

function LocalBoardGetCurve(lBoard, playerName, curveIndex)
	local curve = lBoard.CurvesFolder:FindFirstChild(playerName.."#"..curveIndex)
	if not curve then
		curve = Instance.new("Folder")
		curve.Name = playerName.."#"..curveIndex
		curve.Parent = lBoard.CurvesFolder
	end
	return curve
end

function LocalBoardRelativeToAbsolute(surfacePart, coords, curveIndex)
	return surfacePart.CFrame * CFrame.new(
		-surfacePart.Size.X/2 + coords.X * surfacePart.Size.X, 
		-surfacePart.Size.Y/2 + coords.Y * surfacePart.Size.Y,
		-surfacePart.Size.Z/2 - Z_OFFSET_PER_CURVE * curveIndex)
end

-- For drawing the player's own curves, drawn in VR mode, so as to eliminate
-- the round trip to the server
LocalBoardDrawLine = function(surfacePart, lBoard, curveIndex, relStart, relStop, absThickness, relYThickness, color)
	local worldLineVec = (relStop-relStart)*Vector2.new(surfacePart.Size.X, surfacePart.Size.Y)
	local worldRotation = math.atan2(worldLineVec.Y, worldLineVec.X)

	local worldThickness = relYThickness * surfacePart.Size.Y

	local worldLine = Instance.new("Part")
	worldLine.Size = Vector3.new(worldLineVec.Magnitude+worldThickness, worldThickness, 0.01)
	worldLine.CFrame = LocalBoardRelativeToAbsolute(surfacePart, (relStop+relStart)/2, curveIndex) * CFrame.Angles(0,0,worldRotation)
	worldLine.Color = color

	worldLine.Anchored = true
	worldLine.CanCollide = false
	worldLine.CastShadow = false

	worldLine:SetAttribute("RelStart", relStart)
	worldLine:SetAttribute("RelStop", relStop)
	worldLine:SetAttribute("RelYThickness", relYThickness)
	worldLine:SetAttribute("AbsThickness", absThickness)

	local curve = LocalBoardGetCurve(lBoard, Players.LocalPlayer.Name, curveIndex)
	worldLine.Parent = curve
end

UserInputService.InputEnded:Connect(function(input, gp)
	if not VRService.VREnabled then return end
	
	if input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			State.ButtonHeld = false

			if State.DrawingConnection then
				State.DrawingConnection:Disconnect()
			end

			if rightRumbleSupported then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			end
		end
	end
end)