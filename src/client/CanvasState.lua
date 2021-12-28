local VRService = game:GetService("VRService")

local CollectionService = game:GetService("CollectionService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local GuiPositioning = require(Common.GuiPositioning)
local Cache = require(Common.Cache)
local BoardGui
local Canvas
local Curves
local Buttons
local Drawing


local CanvasState = {

	-- the board that is currently displayed on the canvas
	EquippedBoard = nil,

	EquippedBoardDescendantAddedConnection = nil,
	EquippedBoardDescendantRemovingConnection = nil,

	SurfaceGuiConnections = {}
}

function CanvasState.Init(boardGui)
	BoardGui = boardGui
	Canvas = boardGui.Canvas
	Curves = boardGui.Curves
	
	Buttons = require(script.Parent.Buttons)
	Drawing = require(script.Parent.Drawing)

	
	

	BoardGui.Enabled = false

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

	--print("CanvasState initialized")

end

function CanvasState.ConnectOpenBoardButton(board, button)
	CanvasState.SurfaceGuiConnections[board] =
		board.Canvas.SurfaceGui.Button.Activated:Connect(function()
			if CanvasState.EquippedBoard ~= nil then return end
			CanvasState.OpenBoard(board)
		end)
end

function CanvasState.ConnectWorldBoardSync()

	CanvasState.EquippedBoardDescendantAddedConnection =
		CanvasState.EquippedBoard.Canvas.Curves.DescendantAdded:Connect(function(descendant)
			-- The structure of the descendants of board.Canvas.Curves
			-- looks like this

			-- Curves
			-- 	- "1234#1": A curve folder (the first curve drawn by userId 1234)
			--		- "BoxHandleAdornment": The main part of a line
			--			- "CylinderHandleAdornment": Rounds of the ends of the line
			--			- "CylinderHandleAdornment": Rounds of the ends of the line
			--		- "BoxHandleAdornment": The main part of a line
			--			- "CylinderHandleAdornment": Rounds of the ends of the line
			--			- "CylinderHandleAdornment": Rounds of the ends of the line
			--		- more lines...
			--  - "1234#2": A curve folder (the second curve drawn by userId 1234)
			-- 		- etc...

			-- This structure may vary, so modify this function to account for changes

			local isCurve = descendant.Parent == CanvasState.EquippedBoard.Canvas.Curves

			if isCurve then
				-- Ignore lines drawn by this player
				if descendant:GetAttribute("AuthorUserId") == LocalPlayer.UserId then return end

				local curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, descendant.Name, descendant:GetAttribute("ZIndex"))
				curve.Parent = Curves
				return
			end

			-- This will return nil if this object isn't a worldLine
			local descendantLineInfo = LineInfo.ReadInfo(descendant)

			if descendantLineInfo then
				local worldCurve = descendant.Parent
				if worldCurve:GetAttribute("AuthorUserId") ~= LocalPlayer.UserId then
					local curve = Curves:FindFirstChild(worldCurve.Name)

					if curve == nil then
						curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, worldCurve.Name, worldCurve:GetAttribute("ZIndex"))
						curve.Parent = Curves
					end

					local lineFrame = CanvasState.CreateLineFrame(descendantLineInfo)
					LineInfo.StoreInfo(lineFrame, descendantLineInfo)
					CanvasState.AttachLine(lineFrame, curve)

					if worldCurve:GetAttribute("CurveType") == "Line" then
						descendant:GetAttributeChangedSignal("Stop"):Connect(function()
							local lineInfo = LineInfo.ReadInfo(descendant)
							CanvasState.UpdateLineFrame(lineFrame, LineInfo.ReadInfo(descendant))
							LineInfo.StoreInfo(lineFrame, lineInfo)
						end)
					end
				end
			end
		end)
	
	CanvasState.EquippedBoardDescendantRemovingConnection =
		CanvasState.EquippedBoard.Canvas.Curves.DescendantRemoving:Connect(function(descendant)
			local isCurve = descendant.Parent == CanvasState.EquippedBoard.Canvas.Curves

			if isCurve then
				local curve = Curves:FindFirstChild(descendant.Name)
				if curve then
					CanvasState.DiscardCurve(curve)
				end
				return
			end

			local descendantLineInfo = LineInfo.ReadInfo(descendant)

			if descendantLineInfo then
				local worldCurve = descendant.Parent

				local curve = Curves:FindFirstChild(worldCurve.Name)

				if curve then
					for _, lineFrame in ipairs(CanvasState.GetLinesContainer(curve):GetChildren()) do
						local lineInfo = LineInfo.ReadInfo(lineFrame)
						if 
							 descendantLineInfo.Start == lineInfo.Start and
							 descendantLineInfo.Stop == lineInfo.Stop and
							 descendantLineInfo.ThicknessYScale == lineInfo.ThicknessYScale
						then
							CanvasState.DiscardLineFrame(lineFrame)
							return
						end
					end
				end
			end
		end)
end

function CanvasState.OpenBoard(board)

	-- We do not open the BoardGui if we are in VR
	if VRService.VREnabled then return end
	
	CanvasState.EquippedBoard = board

	CanvasState.ConnectWorldBoardSync()

	game.StarterGui:SetCore("TopbarEnabled", false)

	Buttons.OnBoardOpen(board)
	Drawing.OnBoardOpen(board)

	Canvas.UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y

	Canvas.BackgroundColor3 = board.Color
	BoardGui.Enabled = true

	for _, worldCurve in ipairs(board.Canvas.Curves:GetChildren()) do
		local curve = CanvasState.CreateCurve(board, worldCurve.Name, worldCurve:GetAttribute("ZIndex"))
		for _, worldLine in ipairs(worldCurve:GetChildren()) do
			local lineInfo = LineInfo.ReadInfo(worldLine)
			local lineFrame = CanvasState.CreateLineFrame(lineInfo)
			LineInfo.StoreInfo(lineFrame, lineInfo)
			CanvasState.AttachLine(lineFrame, curve)
		end
		curve.Parent = Curves
	end

end

function CanvasState.CloseBoard(board)
	
	BoardGui.Enabled = false

	Drawing.OnBoardClose(board)

	CanvasState.EquippedBoardDescendantAddedConnection:Disconnect()
	CanvasState.EquippedBoardDescendantRemovingConnection:Disconnect()
	
	game.StarterGui:SetCore("TopbarEnabled", true)

	CanvasState.EquippedBoard = nil

	for _, curve in ipairs(Curves:GetChildren()) do
		CanvasState.DiscardCurve(curve)
	end
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

function CanvasState.CreateCurve(board, curveName, zIndex)
	local curveGui = Cache.Get("ScreenGui")
	curveGui.Name = curveName
	curveGui.IgnoreGuiInset = true
	curveGui.Parent = Curves

	curveGui.DisplayOrder = zIndex
	
	local canvasGhost = Cache.Get("Frame")
	canvasGhost.Name = "CanvasGhost"
	canvasGhost.AnchorPoint = Vector2.new(0.5,0)
	canvasGhost.Position = UDim2.new(0.5,0,0.125,0)
	canvasGhost.Rotation = 0
	canvasGhost.Size = UDim2.new(0.85,0,0.85,0)
	canvasGhost.SizeConstraint = Enum.SizeConstraint.RelativeXY
	canvasGhost.BackgroundTransparency = 1

	local UIAspectRatioConstraint = Cache.Get("UIAspectRatioConstraint")
	UIAspectRatioConstraint.AspectRatio = board.Canvas.Size.X / board.Canvas.Size.Y

	local coordinateFrame = Cache.Get("Frame")
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
	local lineFrame = Cache.Get("Frame")
	lineFrame.Name = "Line"

	CanvasState.UpdateLineFrame(lineFrame, lineInfo)
	
	-- Round the corners
	if lineInfo.ThicknessYScale * Canvas.AbsoluteSize.Y >= Config.UICornerThreshold then
		local UICorner = Cache.Get("UICorner")
		UICorner.CornerRadius = UDim.new(0.5,0)
		UICorner.Parent = lineFrame
	end

	return lineFrame
end

function CanvasState.UpdateLineFrame(lineFrame, lineInfo)
	if lineInfo.Start == lineInfo.Stop then
		lineFrame.Size = UDim2.new(lineInfo.ThicknessYScale, 0, lineInfo.ThicknessYScale, 0)
	else
		lineFrame.Size = UDim2.new(lineInfo.Length + lineInfo.ThicknessYScale, 0, lineInfo.ThicknessYScale, 0)
	end

	lineFrame.Position = UDim2.new(lineInfo.Centre.X, 0, lineInfo.Centre.Y, 0)
	lineFrame.SizeConstraint = Enum.SizeConstraint.RelativeXY
	lineFrame.Rotation = lineInfo.RotationDegrees
	lineFrame.AnchorPoint = Vector2.new(0.5,0.5)
	lineFrame.BackgroundColor3 = lineInfo.Color
	lineFrame.BackgroundTransparency = 0
	lineFrame.BorderSizePixel = 0
end

function CanvasState.Intersects(pos, radius, lineInfo)
	-- Vector from the start of the line to pos
	local u = pos - lineInfo.Start
	-- Vector from the start of the line to the end of the line
	local v = lineInfo.Stop - lineInfo.Start
	
	-- the magnitude (with sign) of the projection of u onto v
	local m = u:Dot(v.Unit)

	if m <= 0 or lineInfo.Start == lineInfo.Stop then
		-- The closest point on the line to pos is lineInfo.Start
		return u.Magnitude <= radius + lineInfo.ThicknessYScale/2
	elseif m >= v.Magnitude then
		-- The closest point on the line to pos is lineInfo.Stop
		return (pos - lineInfo.Stop).Magnitude <= radius + lineInfo.ThicknessYScale/2
	else
		-- The vector from pos to it's closest point on the line makes a perpendicular with the line
		return math.abs(u:Cross(v.Unit)) <= radius + lineInfo.ThicknessYScale/2
	end
end

function CanvasState.DiscardCurve(curve)
	for _, lineFrame in ipairs(curve.CanvasGhost.CoordinateFrame:GetChildren()) do
		CanvasState.DiscardLineFrame(lineFrame)
	end
	Cache.Release(curve.CanvasGhost.CoordinateFrame)
	Cache.Release(curve.CanvasGhost.UIAspectRatioConstraint)
	Cache.Release(curve.CanvasGhost)
	Cache.Release(curve)
end

function CanvasState.DiscardLineFrame(lineFrame)
	local UICorner = lineFrame:FindFirstChild("UICorner")
	if UICorner then
		Cache.Release(UICorner)
	end
	LineInfo.ClearInfo(lineFrame)
	Cache.Release(lineFrame)
end

return CanvasState