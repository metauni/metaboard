local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Remotes = Common.Remotes
local Drawing = require(script.Parent.Drawing)
local LocalPlayer = game:GetService("Players").LocalPlayer
local ClientDrawingTasks = require(script.Parent.ClientDrawingTasks)
local BoardGui
local ModalGui
local CanvasState
local Curves
local Toolbar

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Buttons = {}
Buttons.__index = Buttons


function Buttons.Init(boardGui)

	BoardGui = boardGui
	Toolbar = boardGui.Toolbar
	Curves = boardGui.Curves
	CanvasState = require(script.Parent.CanvasState)
	ModalGui = boardGui.ModalGui

	for _, colorButton in ipairs(Toolbar.Colors:GetChildren()) do
		if colorButton:IsA("TextButton") then
			Buttons.ConnectColorButton(colorButton)
		end
	end

	
	Buttons.ConnectPenModeButton(Toolbar.PenModeButton)
	Buttons.ConnectSlider(Toolbar.Pens.Slider.Rail, Toolbar.Pens.Slider.Rail.Knob)
	Buttons.ConnectPenButton(Toolbar.Pens.PenAButton, Drawing.PenA)
	Buttons.ConnectPenButton(Toolbar.Pens.PenBButton, Drawing.PenB)
	Buttons.ConnectEraserIconButton(Toolbar.Erasers.EraserIconButton)
	Buttons.ConnectEraserSizeButton(Toolbar.Erasers.SmallButton, Config.Drawing.EraserSmallThicknessYScale)
	Buttons.ConnectEraserSizeButton(Toolbar.Erasers.MediumButton, Config.Drawing.EraserMediumThicknessYScale)
	Buttons.ConnectEraserSizeButton(Toolbar.Erasers.LargeButton, Config.Drawing.EraserLargeThicknessYScale)
	Buttons.ConnectUndoButton(Toolbar.UndoButton)
	Buttons.ConnectRedoButton(Toolbar.RedoButton)
	Buttons.ConnectCloseButton(Toolbar.CloseButton)
	
	Buttons.SyncSlider(Drawing.EquippedTool)
	Buttons.SyncPenButton(Toolbar.Pens.PenAButton, Drawing.PenA)
	Buttons.SyncPenButton(Toolbar.Pens.PenBButton, Drawing.PenB)
	Buttons.SyncPenModeButton(Toolbar.PenModeButton, Drawing.PenMode)

	Buttons.ConnectClearButton(Toolbar.ClearButton, ModalGui.ConfirmClearModal)

	Buttons.ApplyToolbarHoverEffects(Toolbar)

	--print("Buttons initialized")
end

function Buttons.OnBoardOpen(board, playerHistory)

	if Drawing.EquippedTool.ToolType == "Pen" then
		Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
		Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
	else
		assert(Drawing.EquippedTool.ToolType == "Eraser")
		Buttons.HighlightJustEraserButton(Drawing.EquippedTool.GuiButton)
	end

	Buttons.SyncUndoButton(playerHistory)
	Buttons.SyncRedoButton(playerHistory)
end

function Buttons.ConnectSlider(rail, knob)
	
	local function updateAt(xScale)
		-- slider inactive unless a Pen is selected
		if Drawing.EquippedTool.ToolType ~= "Pen" then
			-- switched to reserved pen and reserve the eraser
			local tmp = Drawing.EquippedTool
			Drawing.EquippedTool = Drawing.ReservedTool
			Drawing.ReservedTool = tmp

			-- Unhighlight all erasers
			Buttons.HighlightJustEraserButton()
			-- highlight the right color
			Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
			-- Highlight the equipped pen
			Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
		end

		-- Put the Knob there
		knob.Position =  UDim2.new(xScale, 0, 0.5, 0)

		-- Cube it for more fine-tuned control at thin end
		local xScaleCubed = math.pow(xScale, 3)

		-- Configure the size of the currently equipped pen
		local thicknessYScale = (Config.Drawing.MaxThicknessYScale - Config.Drawing.MinThicknessYScale)*xScaleCubed + Config.Drawing.MinThicknessYScale
		Drawing.EquippedTool:SetThicknessYScale(thicknessYScale)
		Buttons.SyncPenButton(Drawing.EquippedTool.GuiButton, Drawing.EquippedTool)
	end
	
	rail.MouseButton1Down:Connect(function(x,y)
		Buttons.SliderActive = true
		local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
		Buttons.KnobGrabOffset = 0
		updateAt(xScale)
	end)
	knob.MouseButton1Down:Connect(function(x,y)
		Buttons.SliderActive = true
		local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
		Buttons.KnobGrabOffset = xScale - knob.Position.X.Scale
	end)
	
	Toolbar.MouseMoved:Connect(function(x,y)
		if Buttons.SliderActive then
			local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X - Buttons.KnobGrabOffset, 0, 1)
			updateAt(xScale)
		end
	end)
	
	UserInputService.InputEnded:Connect(function (input, gameProcessedEvent)
	
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Buttons.SliderActive = false
		end
	end)

	Buttons.SliderActive = false
end

-- Sync the slider configuration to the given pen's thickness
function Buttons.SyncSlider(pen)
	local xScaleCubed = (pen.ThicknessYScale - Config.Drawing.MinThicknessYScale)/(Config.Drawing.MaxThicknessYScale - Config.Drawing.MinThicknessYScale)
	local xScale = math.pow(xScaleCubed, 1/3)
	Toolbar.Pens.Slider.Rail.Knob.Position = UDim2.new(math.clamp(xScale,0,1), 0, 0.5, 0)
end

function Buttons.HighlightJustPenButton(penButton)
	Toolbar.Pens.PenAButton.BackgroundTransparency = 1
	Toolbar.Pens.PenBButton.BackgroundTransparency = 1
	if penButton ~= nil then
		penButton.BackgroundTransparency = Config.Gui.HighlightTransparency
	end
end

function Buttons.HighlightJustColor(color)
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

function Buttons.HighlightJustEraserButton(eraserButton)
	for _, otherEraserButton in ipairs(Toolbar.Erasers:GetChildren()) do
		if otherEraserButton:IsA("TextButton") then
			if otherEraserButton == eraserButton then
				otherEraserButton.BackgroundTransparency = Config.Gui.HighlightTransparency
			else
				otherEraserButton.BackgroundTransparency = 1
			end
		end

	end
end

function Buttons.SyncPenButton(penButton, pen)
	penButton.PenStroke.BackgroundColor3 = pen.Color
	penButton.PenStroke.Size = UDim2.new(0.8, 0, 0, CanvasState.CanvasYScaleToOffset(pen.ThicknessYScale))
end

function Buttons.ConnectPenButton(penButton, penTool)

	penButton.MouseEnter:Connect(function(x,y)
		penButton.BackgroundTransparency = Config.Gui.HighlightTransparency
	end)

	penButton.MouseLeave:Connect(function(x,y) 
		if Drawing.EquippedTool.GuiButton ~= penButton then
			penButton.BackgroundTransparency = 1
		end
	end)

	penButton.Activated:Connect(function(input, clickCount)
		
		Drawing.EquippedTool = penTool
		Drawing.ReservedTool = Drawing.Eraser
		Buttons.SyncSlider(penTool)
		
		Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
		Buttons.HighlightJustPenButton(penButton)
		Buttons.HighlightJustEraserButton()
	end)

end

function Buttons.ConnectColorButton(colorButton)
	colorButton.MouseEnter:Connect(function(x,y) colorButton.Highlight.Visible = true end)
	colorButton.MouseLeave:Connect(function(x,y)
		if Drawing.EquippedTool.ToolType ~= "Pen" or Drawing.EquippedTool.Color ~= colorButton.BackgroundColor3 then
			colorButton.Highlight.Visible = false
		end 
	end)
	
	colorButton.Activated:Connect(function(input, clickCount)
		colorButton.Highlight.Visible = true
		if Drawing.EquippedTool.ToolType ~= "Pen" then
			-- Pressed color button while using Eraser
			assert(Drawing.EquippedTool.ToolType == "Eraser")
			assert(Drawing.ReservedTool.ToolType == "Pen")
			
			-- switched to reserved pen and reserve the eraser
			local tmp = Drawing.EquippedTool
			Drawing.EquippedTool = Drawing.ReservedTool
			Drawing.ReservedTool = tmp
		end

		Drawing.EquippedTool:SetColor(colorButton.BackgroundColor3)
		Buttons.SyncPenButton(Drawing.EquippedTool.GuiButton, Drawing.EquippedTool)
		
		-- Unhighlight all erasers
		Buttons.HighlightJustEraserButton()
		-- highlight the right color
		Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
		-- Highlight the equipped pen
		Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
	end)
end

function Buttons.ConnectEraserIconButton(eraserIconButton)
	eraserIconButton.Activated:Connect(function(input, clickCount)
		if Drawing.EquippedTool.ToolType ~= "Eraser" then
			assert(Drawing.ReservedTool.ToolType == "Eraser")
			-- equip the reserved eraser and reserve the pen
			local tmp = Drawing.EquippedTool
			Drawing.EquippedTool = Drawing.ReservedTool
			Drawing.ReservedTool = tmp

			-- Highlight just the eraser and unhighlight all colors and pens
			Buttons.HighlightJustEraserButton(Drawing.EquippedTool.GuiButton)
			Buttons.HighlightJustColor()
			Buttons.HighlightJustPenButton()
		end
	end)
end

function Buttons.ConnectEraserSizeButton(eraserSizeButton, eraserThicknessYScale)

	eraserSizeButton.MouseEnter:Connect(function(x,y) eraserSizeButton.BackgroundTransparency = Config.Gui.HighlightTransparency end)
			
	eraserSizeButton.MouseLeave:Connect(function(x,y)
		if Drawing.EquippedTool.ToolType ~= "Eraser" or Drawing.EquippedTool.GuiButton ~= eraserSizeButton then
			eraserSizeButton.BackgroundTransparency = 1
		end 
	end)
	
	eraserSizeButton.Activated:Connect(function(input, clickCount)
		eraserSizeButton.BackgroundTransparency = Config.Gui.HighlightTransparency
		if Drawing.EquippedTool.ToolType ~= "Eraser" then
			assert(Drawing.EquippedTool.ToolType == "Pen")
			assert(Drawing.ReservedTool.ToolType == "Eraser")
			
			-- equip reserved eraser and reserve the pen
			local tmp = Drawing.EquippedTool
			Drawing.EquippedTool = Drawing.ReservedTool
			Drawing.ReservedTool = tmp
			
		end

		-- Configure equipped eraser tool
		Drawing.EquippedTool:SetThicknessYScale(eraserThicknessYScale)
		Drawing.EquippedTool:SetGuiButton(eraserSizeButton)
		
		-- Highlight just the eraser and unhighlight all colors and pens
		Buttons.HighlightJustEraserButton(eraserSizeButton)
		Buttons.HighlightJustColor()
		Buttons.HighlightJustPenButton()
	end)
	
end

function Buttons.SyncUndoButton(playerHistory)
	if playerHistory and playerHistory.MostRecent.Value then
		Toolbar.UndoButton.ImageTransparency = 0
		Toolbar.UndoButton.AutoButtonColor = true
	else
		Toolbar.UndoButton.ImageTransparency = 0.5
		Toolbar.UndoButton.AutoButtonColor = false
	end
end

function Buttons.ConnectUndoButton(undoButton)

	undoButton.Activated:Connect(function()
		-- We use this flag to indicate whether this button should be clickable
		if not undoButton.AutoButtonColor then return end

		if not CanvasState.HasWritePermission then return end
		
		if CanvasState.EquippedBoard:FindFirstChild("PersistId") and
			CanvasState.EquippedBoard.IsFull.Value then
			return
		end

		local playerHistory = BoardGui.History:FindFirstChild(LocalPlayer.UserId)
		local taskObjectValue = playerHistory.MostRecent.Value

		if taskObjectValue == nil then return end

		if taskObjectValue.Value then
			
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")
			
			ClientDrawingTasks[taskType].Undo(taskObjectValue.Value)
			taskObjectValue.Value.Parent = Common.HistoryStorage
		else
			-- This currently happens, and shouldn't happen
			print("taskObjectValue not linked to client side value")
		end

		Remotes.Undo:FireServer(CanvasState.EquippedBoard)

		if playerHistory.MostRecent.Value.Parent == playerHistory then
			playerHistory.MostRecent.Value = nil
		else
			playerHistory.MostRecent.Value = playerHistory.MostRecent.Value.Parent
		end
		playerHistory.MostImminent.Value = taskObjectValue
		Buttons.SyncUndoButton(playerHistory)
		Buttons.SyncRedoButton(playerHistory)
	end)
end

function Buttons.SyncRedoButton(playerHistory)
	if playerHistory and playerHistory.MostImminent.Value then
		Toolbar.RedoButton.ImageTransparency = 0
		Toolbar.RedoButton.AutoButtonColor = true
	else
		Toolbar.RedoButton.ImageTransparency = 0.5
		Toolbar.RedoButton.AutoButtonColor = false
	end
end

function Buttons.ConnectRedoButton(redoButton)

	redoButton.Activated:Connect(function()
		-- We use this flag to indicate whether this button should be clickable
		if not redoButton.AutoButtonColor then return end

		if not CanvasState.HasWritePermission then return end

		local playerHistory = BoardGui.History:FindFirstChild(LocalPlayer.UserId)
		local taskObjectValue = playerHistory.MostImminent.Value

		-- Ignore if there's no actual recorded drawing task
		if taskObjectValue == nil then return end

		if taskObjectValue.Value then
			local taskType = taskObjectValue.Value:GetAttribute("TaskType")

			ClientDrawingTasks[taskType].Redo(taskObjectValue.Value)
			if taskType == "Erase" then
				taskObjectValue.Value.Parent = BoardGui.Erases
			else
				taskObjectValue.Value.Parent = BoardGui.Curves
			end
		else
			-- This currently happens, and shouldn't happen
			print("taskObjectValue not linked to client side value")
		end

		Remotes.Redo:FireServer(CanvasState.EquippedBoard)

		local nextImminentTaskObjectValue = playerHistory.MostImminent.Value:FindFirstChildOfClass("ObjectValue")
		if nextImminentTaskObjectValue == nil then
			playerHistory.MostImminent.Value = nil
		else
			playerHistory.MostImminent.Value = nextImminentTaskObjectValue
		end
		playerHistory.MostRecent.Value = taskObjectValue
		Buttons.SyncUndoButton(playerHistory)
		Buttons.SyncRedoButton(playerHistory)
	end)
end

function Buttons.ConnectCloseButton(closeButton)
	closeButton.Activated:Connect(function()
		CanvasState.CloseBoard(CanvasState.EquippedBoard)
	end)
end

function Buttons.ConnectPenModeButton(penModeButton)
	penModeButton.Activated:Connect(function()
		if Drawing.PenMode == "FreeHand" then
			Buttons.SyncPenModeButton(penModeButton, "StraightLine")
			Drawing.PenMode = "StraightLine"
		else
			Buttons.SyncPenModeButton(penModeButton, "FreeHand")
			Drawing.PenMode = "FreeHand"
		end

		if Drawing.EquippedTool.ToolType ~= "Pen" then
			-- Pressed pen mode button while using Eraser
			assert(Drawing.EquippedTool.ToolType == "Eraser")
			assert(Drawing.ReservedTool.ToolType == "Pen")
			
			-- switched to reserved pen and reserve the eraser
			local tmp = Drawing.EquippedTool
			Drawing.EquippedTool = Drawing.ReservedTool
			Drawing.ReservedTool = tmp

				-- Unhighlight all erasers
			Buttons.HighlightJustEraserButton()
			-- highlight the right color
			Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
			-- Highlight the equipped pen
			Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
		end
	end)
end

function Buttons.SyncPenModeButton(penModeButton, mode)
	if mode == "FreeHand" then
		penModeButton.Image = "rbxassetid://8260808744"
	elseif mode == "StraightLine" then
		penModeButton.Image = "rbxassetid://8260809648"
	end
end

function Buttons.ConnectClearButton(clearButton, confirmClearModal)
	clearButton.Activated:Connect(function()
		if not CanvasState.HasWritePermission then return end

		confirmClearModal.Visible = true
	end)

	confirmClearModal.ConfirmClearButton.Activated:Connect(function()
		if not CanvasState.HasWritePermission then return end
		
		confirmClearModal.Visible = false

		CanvasState.Clear()

		Remotes.Clear:FireServer(CanvasState.EquippedBoard)
	end)

	confirmClearModal.CancelButton.Activated:Connect(function()
		confirmClearModal.Visible = false
	end)
end

function Buttons.ApplyToolbarHoverEffects(toolbar)
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
		end)
	end
	
	-- Pens
	local Pens = toolbar.Pens
	InitiateHoverEffect(Pens.Slider, "Thickness")
	InitiateHoverEffect(Pens.PenAButton, "Dotted Stroke")
	InitiateHoverEffect(Pens.PenBButton, "Stroke")
	
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

return Buttons
