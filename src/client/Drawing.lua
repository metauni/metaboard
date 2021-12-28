local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local GuiPositioning = require(Common.GuiPositioning)
local ClientDrawingTasks
local DrawingTool = require(Common.DrawingTool)
local CanvasState
local Pen = DrawingTool.Pen
local Eraser = DrawingTool.Eraser

local BoardGui
local Canvas

local Drawing = {
	-- mouse state
	---------------
	MouseHeld = false,
	-- pixel coordinates of mouse
	MousePixelPos = nil,

	-- the cursor that follows the mouse position
	Cursor = nil,

	-- drawing pen state
	---------------------
	PenA = nil,
	PenB = nil,

	-- Drawing Mode
	PenMode = nil,

	-- eraser state
	----------------
	Eraser = nil,
	
	EquippedTool = nil,
	
	ReservedTool = nil,

	-- Every line drawn by this player on a given board will be sequentially
	-- numbered by a curve index for undo-functionality. 
	-- CurveIndexOf[board] will be the current curve being drawn on the board
	-- by this player (or the last drawn curve if mouseHeld is false)
	-- (See Config.CurveNamer)
	CurveIndexOf = {},

	CurrentTask = nil
}
Drawing.__index = Drawing

function Drawing.Init(boardGui)
	BoardGui = boardGui

	Canvas = BoardGui.Canvas

	CanvasState = require(script.Parent.CanvasState)

	Drawing.PenA = Pen.new(Config.Defaults.PenAColor, Config.Defaults.PenAThicknessYScale, BoardGui.Toolbar.Pens.PenAButton)
	Drawing.PenB = Pen.new(Config.Defaults.PenBColor, Config.Defaults.PenBThicknessYScale, BoardGui.Toolbar.Pens.PenBButton)

	Drawing.PenMode = "FreeHand"

	ClientDrawingTasks = require(script.Parent.ClientDrawingTasks)

	Drawing.Eraser = Eraser.new(Config.EraserSmall, BoardGui.Toolbar.Erasers.SmallButton)

	Drawing.EquippedTool = Drawing.PenA
	Drawing.ReservedTool = Drawing.Eraser

	Drawing.CursorGui = Instance.new("ScreenGui")
	Drawing.CursorGui.Name = "CursorGui"
	Drawing.CursorGui.DisplayOrder = 2147483647
	Drawing.CursorGui.IgnoreGuiInset = true
	Drawing.CursorGui.ResetOnSpawn = false
	
	Drawing.CursorGui.Enabled = false
	Drawing.CursorGui.Parent = BoardGui

	Drawing.InitCursor(Drawing.CursorGui)

	Canvas.MouseButton1Down:Connect(function(x,y)
		Drawing.UpdateCursor(x,y)
		Drawing.Cursor.Visible = true
		Drawing.ToolDown(x,y)
	end)

	Canvas.MouseMoved:Connect(function(x,y)
		Drawing.UpdateCursor(x,y)
		Drawing.ToolMoved(x,y)
	end)

	Canvas.MouseEnter:Connect(function(x,y)
		Drawing.UpdateCursor(x,y)
		Drawing.Cursor.Visible = true
	end)
	
	Canvas.MouseLeave:Connect(function(x,y)
		if Drawing.MouseHeld then
			Drawing.ToolLift(x, y)
		end
		Drawing.MouseHeld = false
		Drawing.Cursor.Visible = false
	end)
	
	UserInputService.InputEnded:Connect(function(input, gp)
		if Drawing.MouseHeld then
			Drawing.ToolLift(input.Position.X, input.Position.Y + 36)
		end
		Drawing.MouseHeld = false
	end)

end

function Drawing.OnBoardOpen(board)
	if Drawing.CurveIndexOf[board] == nil then
		-- Search for curves already written by this user (possibly restored to a persistent board)
		local curveIndexMax = 0

		-- Note that we can't just search from curveIndex = 1 because curves
		-- may be erased, leaving us e.g. with a Curves folder only containing ID#4
		for _, curve in ipairs(board.Canvas.Curves:GetChildren()) do
			-- Names are PlayerID#curveIndex
			local curveIndex = tonumber(string.sub(curve.Name, string.find(curve.Name, "#")+1,string.len(curve.Name)))
			curveIndexMax = if curveIndex > curveIndexMax then curveIndex else curveIndexMax
		end
		
		Drawing.CurveIndexOf[board] = curveIndexMax -- Note it should be 0 if there are no lines
	end

	Drawing.CursorGui.Enabled = true
end

function Drawing.OnBoardClose(board)
	Drawing.CursorGui.Enabled = false
end

function Drawing.WithinBounds(x,y, thicknessYScale)
	local leftBuffer = (x - Canvas.AbsolutePosition.X)/Canvas.AbsoluteSize.Y
	local rightBuffer = (Canvas.AbsolutePosition.X + Canvas.AbsoluteSize.X - x)/Canvas.AbsoluteSize.Y
	local upBuffer = (y - (Canvas.AbsolutePosition.Y + 36))/Canvas.AbsoluteSize.Y
	local downBuffer = ((Canvas.AbsolutePosition.Y + Canvas.AbsoluteSize.Y + 36) - y)/Canvas.AbsoluteSize.Y

	return
		leftBuffer >= thicknessYScale/2 and
		rightBuffer >= thicknessYScale/2 and
		upBuffer >= thicknessYScale/2 and
		downBuffer >= thicknessYScale/2
end

function Drawing.ToolDown(x,y)

	Drawing.MouseHeld = true
	Drawing.CurveIndexOf[CanvasState.EquippedBoard] += 1

	local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x,y))

	if Drawing.EquippedTool.ToolType == "Eraser" then
		Drawing.CurrentTask = ClientDrawingTasks.new("Erase")
		Drawing.CurrentTask.Init(Drawing.CurrentTask.State, newCanvasPos)
	else
		if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
			return
		end

		if Drawing.EquippedTool.ToolType == "Pen" then
			Drawing.CurrentTask = ClientDrawingTasks.new(Drawing.PenMode)
			Drawing.CurrentTask.Init(Drawing.CurrentTask.State, newCanvasPos)
		end
	end

	Drawing.MousePixelPos = Vector2.new(x, y)
end

function Drawing.ToolMoved(x,y)
	if Drawing.MouseHeld then

		local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x, y))
		
		if Drawing.EquippedTool.ToolType == "Eraser" then
			Drawing.CurrentTask.Update(Drawing.CurrentTask.State, newCanvasPos)
		else
			assert(Drawing.EquippedTool.ToolType == "Pen")

			if not Drawing.WithinBounds(x,y, Drawing.EquippedTool.ThicknessYScale) then
				Drawing.MousePixelPos = Vector2.new(x, y)
				return
			end

			Drawing.CurrentTask.Update(Drawing.CurrentTask.State, newCanvasPos)

		end

		Drawing.MousePixelPos = Vector2.new(x, y)
	end
end

function Drawing.ToolLift(x,y)

	local newCanvasPos = CanvasState.GetScalePositionOnCanvas(Vector2.new(x, y))
	Drawing.MouseHeld = false
	Drawing.MousePixelPos = Vector2.new(x,y)
	
	Drawing.CurrentTask.Finish(Drawing.CurrentTask.State, newCanvasPos)
end


-- Draw/update the cursor for a player's tool on the Gui
function Drawing.InitCursor(cursorGui)
	Drawing.Cursor = Instance.new("Frame")
	Drawing.Cursor.Name = LocalPlayer.Name.."Cursor"
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

	Drawing.Cursor.Parent = cursorGui
end

function Drawing.UpdateCursor(x,y)
	-- Reposition cursor to new position (should be given with Scale values)
	Drawing.Cursor.Position = GuiPositioning.PositionFromPixel(x, y, Drawing.CursorGui.IgnoreGuiInset)
	
	-- Configure Drawing.Cursor appearance based on tool type
	if Drawing.EquippedTool.ToolType == "Pen" then
		Drawing.Cursor.Size =
			UDim2.new(0, Drawing.EquippedTool.ThicknessYScale * Canvas.AbsoluteSize.Y,
								0, Drawing.EquippedTool.ThicknessYScale * Canvas.AbsoluteSize.Y)
		Drawing.Cursor.BackgroundColor3 = Drawing.EquippedTool.Color
		Drawing.Cursor.BackgroundTransparency = 0.5
	elseif Drawing.EquippedTool.ToolType == "Eraser" then
		Drawing.Cursor.Size = UDim2.new(0, Drawing.EquippedTool.ThicknessYScale * Canvas.AbsoluteSize.Y,
														0, Drawing.EquippedTool.ThicknessYScale * Canvas.AbsoluteSize.Y)
		Drawing.Cursor.BackgroundColor3 = Color3.new(1, 1, 1)
		Drawing.Cursor.BackgroundTransparency = 0.5
	end
end

-- Perform the Douglas-Peucker algorithm on a polyline given as an array
-- of points. Instead of returning a new polyline, this function sets
-- all of the removed points to nil
function Drawing.DouglasPeucker(points, startIndex, stopIndex, epsilon)
	
	if stopIndex - startIndex + 1 <= 2 then return end

	local startPoint = points[startIndex]
	local stopPoint = points[stopIndex]

	local maxPerp = nil
	local maxPerpIndex = nil
	
	for i = startIndex+1, stopIndex-1 do
		-- Get the length of the perpendicular vector between points[i] and the line through startPoint and stopPoint
		local perp = math.abs((points[i] - startPoint).Unit:Cross((startPoint-stopPoint).Unit) * ((points[i] - startPoint).Magnitude))
		if maxPerp == nil or perp > maxPerp then
			maxPerp = perp
			maxPerpIndex = i
		end
	end

	if maxPerp > epsilon then
		Drawing.DouglasPeucker(points, startIndex, maxPerpIndex, epsilon)
		Drawing.DouglasPeucker(points, maxPerpIndex, stopIndex, epsilon)
	else
		for i = startIndex+1, stopIndex-1 do
			points[i] = nil
		end
	end
end


return Drawing