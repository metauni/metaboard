-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)
local Pen = require(Common.DrawingTool.Pen)
local Eraser = require(Common.DrawingTool.Eraser)

local Toolbar = {}
Toolbar.__index = Toolbar


function Toolbar.Init(toolbarGui, modalGui)

	-- Toolbar.PenA = Pen.new(penAColor, Config.Toolbar.Defaults.PenAThicknessYScale, "FreeHand")
	-- Toolbar.PenB = Pen.new(penBColor, Config.Toolbar.Defaults.PenBThicknessYScale, "FreeHand")
	-- Toolbar.Eraser = Eraser.new(Config.Toolbar.Defaults.EraserThicknessYScale)
	-- Toolbar.EquippedTool = Toolbar.PenA
	-- Toolbar.LastUsedPen = Toolbar.PenA

	for _, colorButton in ipairs(Toolbar.Colors:GetChildren()) do
		if colorButton:IsA("TextButton") then
			Toolbar.ConnectColorButton(colorButton)
		end
	end


	Toolbar.ConnectPenModeButton(toolbarGui.PenModeButton)
	Toolbar.ConnectSlider(toolbarGui.Pens.Slider.Rail, toolbarGui.Pens.Slider.Rail.Knob)
	Toolbar.ConnectPenButton(toolbarGui.Pens.PenAButton, Toolbar.PenA)
	Toolbar.ConnectPenButton(toolbarGui.Pens.PenBButton, Toolbar.PenB)
	Toolbar.ConnectEraserIconButton(toolbarGui.Erasers.EraserIconButton)
	Toolbar.ConnectEraserSizeButton(toolbarGui.Erasers.SmallButton, Config.Toolbar.EraserSmallThicknessYScale)
	Toolbar.ConnectEraserSizeButton(toolbarGui.Erasers.MediumButton, Config.Toolbar.EraserMediumThicknessYScale)
	Toolbar.ConnectEraserSizeButton(toolbarGui.Erasers.LargeButton, Config.Toolbar.EraserLargeThicknessYScale)
	Toolbar.ConnectUndoButton(toolbarGui.UndoButton)
	Toolbar.ConnectRedoButton(toolbarGui.RedoButton)
	Toolbar.ConnectCloseButton(toolbarGui.CloseButton)

	Toolbar.SyncSlider(Toolbar.EquippedTool)
	Toolbar.SyncPenButton(toolbarGui.Pens.PenAButton, Toolbar.PenA)
	Toolbar.SyncPenButton(toolbarGui.Pens.PenBButton, Toolbar.PenB)
	Toolbar.SyncPenModeButton(toolbarGui.PenModeButton, Toolbar.LastUsedPen.Mode)

	Toolbar.ConnectClearButton(toolbarGui.ClearButton, modalGui.ConfirmClearModal)

	Toolbar.ApplyToolbarHoverEffects(toolbarGui)
end

function Toolbar.OnBoardOpen(board, toolState)

	Toolbar.ToolState = toolState

	toolState.EquippedTool:Update()

	Toolbar.SyncUndoButton(board.PlayerHistory[Players.LocalPlayer])
	Toolbar.SyncRedoButton(board.PlayerHistory[Players.LocalPlayer])
end

function Toolbar.ConnectPenSignals(pen, penButton, penModeButton)
	pen.UpdateSignal:Connect(function()
		Toolbar.SyncPenButton(penButton, pen)
		if pen == Toolbar.EquippedTool then
			Toolbar.SyncSlider(pen)
			Toolbar.SyncPenModeButton(penModeButton)
			Toolbar.HighlightJustColor(Toolbar.EquippedTool.Color)
			Toolbar.HighlightJustEraserSizeButton(nil)
			Toolbar.HighlightJustPenButton(penButton)
		end
	end)
end

function Toolbar.ConnectEraserSignals(eraser)
	eraser.EquipSignal:Connect(function()
		Toolbar.HighlightJustEraserSizeButton(eraser.ThicknessYScale)
		Toolbar.HighlightJustColor()
		Toolbar.HighlightJustPenButton()
	end)
end

function Toolbar.ConnectSlider(rail, knob)

	local function updateAt(xScale)
		if not Toolbar.EquippedTool.IsPen then
			Toolbar.EquippedTool = Toolbar.LastUsedPen
			Toolbar.EquippedTool:Update()
		end

		-- Put the Knob there
		knob.Position =  UDim2.new(xScale, 0, 0.5, 0)

		-- Cube it for more fine-tuned control at thin end
		local xScaleCubed = math.pow(xScale, 3)

		-- Configure the size of the currently equipped pen
		local thicknessYScale = (Config.Drawing.MaxThicknessYScale - Config.Drawing.MinThicknessYScale)*xScaleCubed + Config.Drawing.MinThicknessYScale
		Toolbar.EquippedTool:Update(thicknessYScale)
	end

	rail.MouseButton1Down:Connect(function(x,y)
		Toolbar.SliderActive = true
		local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
		Toolbar.KnobGrabOffset = 0
		updateAt(xScale)
	end)
	knob.MouseButton1Down:Connect(function(x,y)
		Toolbar.SliderActive = true
		local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
		Toolbar.KnobGrabOffset = xScale - knob.Position.X.Scale
	end)

	Toolbar.MouseMoved:Connect(function(x,y)
		if Toolbar.SliderActive then
			local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X - Toolbar.KnobGrabOffset, 0, 1)
			updateAt(xScale)
		end
	end)

	UserInputService.InputEnded:Connect(function (input, gameProcessedEvent)

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Toolbar.SliderActive = false
		end
	end)

	Toolbar.SliderActive = false
end

-- Sync the slider configuration to the given pen's thickness
function Toolbar.SyncSlider(pen)
	local xScaleCubed = (pen.ThicknessYScale - Config.Drawing.MinThicknessYScale)/(Config.Drawing.MaxThicknessYScale - Config.Drawing.MinThicknessYScale)
	local xScale = math.pow(xScaleCubed, 1/3)
	Toolbar.Pens.Slider.Rail.Knob.Position = UDim2.new(math.clamp(xScale,0,1), 0, 0.5, 0)
end

function Toolbar.HighlightJustPenButton(penButton)
	Toolbar.Pens.PenAButton.BackgroundTransparency = 1
	Toolbar.Pens.PenBButton.BackgroundTransparency = 1
	if penButton ~= nil then
		penButton.BackgroundTransparency = Config.Gui.HighlightTransparency
	end
end

function Toolbar.HighlightJustColor(color)
	for _, colorButton in ipairs(Toolbar.Colors:GetChildren()) do
		if colorButton:IsA("TextButton") then
			if colorButton.BackgroundColor3 == color then
				colorButton.Highlight.Visible = true
			else
				colorButton.Highlight.Visible = false
			end
		end

	end
end

function Toolbar.HighlightJustEraserSizeButton(thicknessYScale)
	for _, eraserSizeButton in ipairs(Toolbar.Erasers:GetChildren()) do
		if eraserSizeButton:IsA("TextButton") then
			if eraserSizeButton:GetAttribute("ThicknessYScale") == thicknessYScale then
				eraserSizeButton.BackgroundTransparency = Config.Gui.HighlightTransparency
			else
				eraserSizeButton.BackgroundTransparency = 1
			end
		end
	end
end

function Toolbar.SyncPenButton(penButton, pen)
	penButton.PenStroke.BackgroundColor3 = pen.Color
	penButton.PenStroke.Size = UDim2.new(0.8, 0, 0, Drawing.EquippedBoard.Canvas:YScaleToOffset(pen.ThicknessYScale))
end

function Toolbar.ConnectPenButton(penButton, pen)
	penButton.MouseEnter:Connect(function(x,y)
		penButton.BackgroundTransparency = Config.Gui.HighlightTransparency
	end)

	penButton.MouseLeave:Connect(function(x,y)
		if Toolbar.EquippedTool ~= pen then
			penButton.BackgroundTransparency = 1
		end
	end)

	penButton.Activated:Connect(function(input, clickCount)
		Toolbar.EquippedTool = pen
		pen:Update()
	end)
end

function Toolbar.ConnectColorButton(colorButton)
	colorButton.MouseEnter:Connect(function(x,y) colorButton.Highlight.Visible = true end)
	colorButton.MouseLeave:Connect(function(x,y)
		if not (Toolbar.EquippedTool.IsPen and Toolbar.EquippedTool.Color == colorButton.BackgroundColor3) then
			colorButton.Highlight.Visible = false
		end
	end)

	colorButton.Activated:Connect(function(input, clickCount)
		-- colorButton.Highlight.Visible = true
		if not Toolbar.EquippedTool.IsPen then
			-- Pressed color button while using Eraser

			-- switched to reserved pen and reserve the eraser
			Toolbar.EquippedTool = Toolbar.LastUsedPen
		end

		Toolbar.EquippedTool:Update(Toolbar.LastUsedPen.ThicknessYScale, colorButton.BackgroundColor3)
		-- Buttons.SyncPenButton(Drawing.EquippedTool.GuiButton, Drawing.EquippedTool)

		-- -- Unhighlight all erasers
		-- Buttons.HighlightJustEraserSizeButton()
		-- -- highlight the right color
		-- Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
		-- -- Highlight the equipped pen
		-- Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
	end)
end

function Toolbar.ConnectEraserIconButton(eraserIconButton)
	eraserIconButton.Activated:Connect(function(input, clickCount)
		if not Toolbar.EquippedTool.IsEraser then
			Toolbar.EquippedTool = Toolbar.Eraser

			-- -- Highlight just the eraser and unhighlight all colors and pens
			-- Buttons.HighlightJustEraserSizeButton(Drawing.EquippedTool.GuiButton)
			-- Buttons.HighlightJustColor()
			-- Buttons.HighlightJustPenButton()
		end
		Toolbar.EquippedTool:Update()
	end)
end

function Toolbar.ConnectEraserSizeButton(eraserSizeButton, eraserThicknessYScale)

	eraserSizeButton:SetAttribute("ThicknessYScale", eraserThicknessYScale)

	eraserSizeButton.MouseEnter:Connect(function(x,y) eraserSizeButton.BackgroundTransparency = Config.Gui.HighlightTransparency end)

	eraserSizeButton.MouseLeave:Connect(function(x,y)
		if not (Drawing.EquippedTool.IsEraser and Drawing.EquippedTool.ThicknessYScale == eraserThicknessYScale) then
			eraserSizeButton.BackgroundTransparency = 1
		end
	end)

	eraserSizeButton.Activated:Connect(function(input, clickCount)
		eraserSizeButton.BackgroundTransparency = Config.Gui.HighlightTransparency
		if not Drawing.EquippedTool.IsEraser then
			if Drawing.EquippedTool.IsPen then
				Drawing.LastUsedPen = Drawing.EquippedTool
			end

			Drawing.EquippedTool = Drawing.Eraser

		end

		Drawing.EquippedTool:Update(eraserThicknessYScale)

		-- -- Highlight just the eraser and unhighlight all colors and pens
		-- Buttons.HighlightJustEraserSizeButton(eraserSizeButton)
		-- Buttons.HighlightJustColor()
		-- Buttons.HighlightJustPenButton()
	end)

end

function Toolbar.SyncUndoButton(playerHistory)
	if playerHistory and playerHistory.MostRecent.Value then
		Toolbar.UndoButton.ImageTransparency = 0
		Toolbar.UndoButton.AutoButtonColor = true
	else
		Toolbar.UndoButton.ImageTransparency = 0.5
		Toolbar.UndoButton.AutoButtonColor = false
	end
end

function Toolbar.ConnectUndoButton(board, undoButton)
	local localPlayerHistory = board.PlayerHistory[Players.LocalPlayer]
	localPlayerHistory.UpdatedSignal:Connect(function()
		Toolbar.SyncUndoButton(localPlayerHistory)
	end)

	undoButton.Activated:Connect(function()
		-- We use this flag to indicate whether this button should be clickable
		if not undoButton.AutoButtonColor then return end

		Toolbar.EquippedBoard:Undo(Players.LocalPlayer)
		-- Buttons.EquippedBoard.Remotes.Undo:FireServer()

		-- -- if not CanvasState.HasWritePermission then return end

		-- if CanvasState.EquippedBoard:FindFirstChild("PersistId") and
		-- 	CanvasState.EquippedBoard.IsFull.Value then
		-- 	return
		-- end

		-- local playerHistory = BoardGui.History:FindFirstChild(LocalPlayer.UserId)
		-- local taskObjectValue = playerHistory.MostRecent.Value

		-- if taskObjectValue == nil then return end

		-- if taskObjectValue.Value then

		-- 	local taskType = taskObjectValue.Value:GetAttribute("TaskType")

		-- 	ClientDrawingTasks[taskType].Undo(taskObjectValue.Value)
		-- 	taskObjectValue.Value.Parent = Common.HistoryStorage
		-- else
		-- 	-- This currently happens, and shouldn't happen
		-- 	print("taskObjectValue not linked to client side value")
		-- end

		-- Remotes.Undo:FireServer(CanvasState.EquippedBoard)

		-- if playerHistory.MostRecent.Value.Parent == playerHistory then
		-- 	playerHistory.MostRecent.Value = nil
		-- else
		-- 	playerHistory.MostRecent.Value = playerHistory.MostRecent.Value.Parent
		-- end
		-- playerHistory.MostImminent.Value = taskObjectValue
		-- Buttons.SyncUndoButton(playerHistory)
		-- Buttons.SyncRedoButton(playerHistory)
	end)
end

function Toolbar.SyncRedoButton(playerHistory)
	if playerHistory and playerHistory.MostImminent.Value then
		Toolbar.RedoButton.ImageTransparency = 0
		Toolbar.RedoButton.AutoButtonColor = true
	else
		Toolbar.RedoButton.ImageTransparency = 0.5
		Toolbar.RedoButton.AutoButtonColor = false
	end
end

function Toolbar.ConnectRedoButton(board, redoButton)

	local localPlayerHistory = board.PlayerHistory[Players.LocalPlayer]
	localPlayerHistory.UpdatedSignal:Connect(function()
		Toolbar.SyncRedoButton(localPlayerHistory)
	end)

	redoButton.Activated:Connect(function()
		-- We use this flag to indicate whether this button should be clickable
		if not redoButton.AutoButtonColor then return end

		-- if not CanvasState.HasWritePermission then return end

		-- local playerHistory = BoardGui.History:FindFirstChild(LocalPlayer.UserId)
		-- local taskObjectValue = playerHistory.MostImminent.Value

		-- -- Ignore if there's no actual recorded drawing task
		-- if taskObjectValue == nil then return end

		-- if taskObjectValue.Value then
		-- 	local taskType = taskObjectValue.Value:GetAttribute("TaskType")

		-- 	ClientDrawingTasks[taskType].Redo(taskObjectValue.Value)
		-- 	if taskType == "Erase" then
		-- 		taskObjectValue.Value.Parent = BoardGui.Erases
		-- 	else
		-- 		taskObjectValue.Value.Parent = BoardGui.Curves
		-- 	end
		-- else
		-- 	-- This currently happens, and shouldn't happen
		-- 	print("taskObjectValue not linked to client side value")
		-- end

		-- Remotes.Redo:FireServer(CanvasState.EquippedBoard)

		-- local nextImminentTaskObjectValue = playerHistory.MostImminent.Value:FindFirstChildOfClass("ObjectValue")
		-- if nextImminentTaskObjectValue == nil then
		-- 	playerHistory.MostImminent.Value = nil
		-- else
		-- 	playerHistory.MostImminent.Value = nextImminentTaskObjectValue
		-- end
		-- playerHistory.MostRecent.Value = taskObjectValue
		-- Buttons.SyncUndoButton(playerHistory)
		-- Buttons.SyncRedoButton(playerHistory)
	end)
end

function Toolbar.ConnectCloseButton(closeButton)
	closeButton.Activated:Connect(function()
		CanvasState.CloseBoard(CanvasState.EquippedBoard)
	end)
end

function Toolbar.ConnectPenModeButton(penModeButton)
	penModeButton.Activated:Connect(function()
		-- if Drawing.PenMode == "FreeHand" then
		-- 	Buttons.SyncPenModeButton(penModeButton, "StraightLine")
		-- 	Drawing.PenMode = "StraightLine"
		-- else
		-- 	Buttons.SyncPenModeButton(penModeButton, "FreeHand")
		-- 	Drawing.PenMode = "FreeHand"
		-- end

		if not Drawing.EquippedTool.IsPen then
			-- Pressed pen mode button while using Eraser
			Drawing.EquippedTool = Drawing.LastUsedPen
		end

		Drawing.EquippedTool:ToggleMode()
		Drawing.EquippedTool:Update()
	end)
end

function Toolbar.SyncPenModeButton(penModeButton, mode)
	if mode == "FreeHand" then
		penModeButton.Image = "rbxassetid://8260808744"
	elseif mode == "StraightLine" then
		penModeButton.Image = "rbxassetid://8260809648"
	end
end

function Toolbar.ConnectClearButton(clearButton, confirmClearModal)
	clearButton.Activated:Connect(function()
		-- if not CanvasState.HasWritePermission then return end

		confirmClearModal.Visible = true
	end)

	confirmClearModal.ConfirmClearButton.Activated:Connect(function()
		-- if not CanvasState.HasWritePermission then return end

		confirmClearModal.Visible = false

		Toolbar.EquippedBoard:Clear()

		Toolbar.EquippedBoard.Remotes.Clear:FireServer(CanvasState.EquippedBoard)
	end)

	confirmClearModal.CancelButton.Activated:Connect(function()
		confirmClearModal.Visible = false
	end)
end

function Toolbar.ApplyToolbarHoverEffects(toolbar)
	if not UserInputService.MouseEnabled then
		return
	end

	local function CreateToolTip(position, text)
		local Label = Instance.new("TextLabel")
		Label.Name = "ToolTip"
		Label.AnchorPoint = Vector2.new(.5, 0)
		Label.BackgroundColor3 = Color3.fromRGB(64, 64, 64)
		Label.BackgroundTransparency = 0.1
		Label.BorderSizePixel = 0
		Label.Position = UDim2.fromOffset(position.X, position.Y)
		Label.AutomaticSize = Enum.AutomaticSize.X
		Label.Size = UDim2.fromScale(0, .03)
		Label.ZIndex = 2
		Label.Font = Enum.Font.SourceSansSemibold
		Label.Text = text
		Label.TextColor3 = Color3.new(1, 1, 1)
		Label.TextScaled = true
		Label.TextSize = 20
		Label.TextWrapped = true
		Label.Visible = false

		local UICorner = Instance.new("UICorner")
		UICorner.CornerRadius = UDim.new(0.3, 0)
		UICorner.Parent = Label

		local UIPadding = Instance.new("UIPadding")
		UIPadding.Parent = Label
		UIPadding.PaddingLeft = UDim.new(0.1, 0)
		UIPadding.PaddingRight = UDim.new(0.1, 0)

		Label.Parent = toolbar.Parent

		return Label
	end

	local delayTime = 1
	local ToolTip = CreateToolTip(Vector2.new(), "Tool Tip")
	local ShowToolTip = TweenService:Create(
		ToolTip,
		TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delayTime),
		{ Visible = true }
	)

	local function InitiateHoverEffect(button, text)
		button.MouseEnter:Connect(function()
			local offset = toolbar.Parent.IgnoreGuiInset and Vector2.new(0, 36) or Vector2.new()
			local position = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X/2, button.AbsoluteSize.Y + 10) + offset

			ToolTip.Visible = false
			ToolTip.Position = UDim2.fromOffset(position.X, position.Y)
			ToolTip.Text = text

			ShowToolTip:Play()
		end)

		button.MouseLeave:Connect(function()
			ToolTip.Visible = false
			if ShowToolTip.PlaybackState == Enum.PlaybackState.Playing then
				ShowToolTip:Cancel()
			end
		end)
	end

	-- Pens
	local Pens = toolbar.Pens
	InitiateHoverEffect(Pens.Slider, "Thickness")
	InitiateHoverEffect(Pens.PenAButton, "Pen A")
	InitiateHoverEffect(Pens.PenBButton, "Pen B")

	-- Color buttons
	for _, object in ipairs(toolbar.Colors:GetChildren()) do
		if object:IsA("TextButton") then
			InitiateHoverEffect(object, object.Name)
		end
	end

	-- Erasers
	local Erasers = toolbar.Erasers
	InitiateHoverEffect(Erasers.EraserIconButton, "Eraser Mode")
	InitiateHoverEffect(Erasers.LargeButton, "Large")
	InitiateHoverEffect(Erasers.MediumButton, "Medium")
	InitiateHoverEffect(Erasers.SmallButton, "Small")

	-- Misc
	InitiateHoverEffect(toolbar.ClearButton, "Clear Board")
	InitiateHoverEffect(toolbar.CloseButton, "Close")
	InitiateHoverEffect(toolbar.PenModeButton, "Pen/Line Mode")
	InitiateHoverEffect(toolbar.RedoButton, "Redo")
	InitiateHoverEffect(toolbar.UndoButton, "Undo")
end

return Toolbar
