local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local Config = require(Common.Config)
local Drawing = require(script.Parent.Drawing)
local LocalPlayer = game:GetService("Players").LocalPlayer
local CanvasState
local Toolbar

local UserInputService = game:GetService("UserInputService")
local UndoCurveRemoteEvent = Common.Remotes.UndoCurve

local Buttons = {}
Buttons.__index = Buttons


function Buttons.Init(toolbar)
	Toolbar = toolbar
	CanvasState = require(script.Parent.CanvasState)

	for _, colorButton in ipairs(Toolbar.Colors:GetChildren()) do
		if colorButton:IsA("TextButton") then
			Buttons.ConnectColorButton(colorButton)
		end
	end

	
	Buttons.ConnectPenModeButton(Toolbar.PenModeButton)
	Buttons.ConnectSlider(Toolbar.Pens.Slider.Rail, Toolbar.Pens.Slider.Rail.Knob)
	Buttons.ConnectPenButton(Toolbar.Pens.PenAButton, Drawing.PenA)
	Buttons.ConnectPenButton(Toolbar.Pens.PenBButton, Drawing.PenB)
	Buttons.ConnectEraserButton(Toolbar.Erasers.SmallButton, Config.EraserSmallRadiusYScale)
	Buttons.ConnectEraserButton(Toolbar.Erasers.MediumButton, Config.EraserMediumRadiusYScale)
	Buttons.ConnectEraserButton(Toolbar.Erasers.LargeButton, Config.EraserLargeRadiusYScale)
	Buttons.ConnectUndoButton(Toolbar.UndoButton)
	Buttons.ConnectCloseButton(Toolbar.CloseButton)
	
	Buttons.SyncSlider(Drawing.EquippedTool)
	Buttons.SyncPenButton(Toolbar.Pens.PenAButton, Drawing.PenA)
	Buttons.SyncPenButton(Toolbar.Pens.PenBButton, Drawing.PenB)
	Buttons.SyncPenModeButton(Toolbar.PenModeButton, Drawing.PenMode)
	
	print("Buttons initialized")
end

function Buttons.OnBoardOpen(board)

	if Drawing.EquippedTool.ToolType == "Pen" then
		Buttons.HighlightJustPenButton(Drawing.EquippedTool.GuiButton)
		Buttons.HighlightJustColor(Drawing.EquippedTool.Color)
	else
		assert(Drawing.EquippedTool.ToolType == "Eraser")
		Buttons.HighlightJustEraserButton(Drawing.EquippedTool.GuiButton)
	end
	
end

function Buttons.ConnectSlider(rail, knob)
	
	local function updateAt(xScale)
		-- slider inactive unless a Pen is selected
		if Drawing.EquippedTool.ToolType == "Pen" then

			-- Put the Knob there
			knob.Position =  UDim2.new(xScale, 0, 0.5, 0)

			-- Cube it for more fine-tuned control at thin end
			local xScaleCubed = math.pow(xScale, 3)

			-- Configure the size of the currently equipped pen
			local thicknessYScale = (Config.MaxThicknessYScale - Config.MinThicknessYScale)*xScaleCubed + Config.MinThicknessYScale
			Drawing.EquippedTool:SetThicknessYScale(thicknessYScale)
			Buttons.SyncPenButton(Drawing.EquippedTool.GuiButton, Drawing.EquippedTool)
		end
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
			local xScale = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
			updateAt(xScale - Buttons.KnobGrabOffset)
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
	local xScaleCubed = (pen.ThicknessYScale - Config.MinThicknessYScale)/(Config.MaxThicknessYScale - Config.MinThicknessYScale)
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

function Buttons.ConnectEraserButton(eraserButton, eraserThicknessYScale)

	eraserButton.MouseEnter:Connect(function(x,y) eraserButton.BackgroundTransparency = Config.Gui.HighlightTransparency end)
			
	eraserButton.MouseLeave:Connect(function(x,y)
		if Drawing.EquippedTool.ToolType ~= "Eraser" or Drawing.EquippedTool.GuiButton ~= eraserButton then
			eraserButton.BackgroundTransparency = 1
		end 
	end)
	
	eraserButton.Activated:Connect(function(input, clickCount)
		eraserButton.BackgroundTransparency = Config.Gui.HighlightTransparency
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
		Drawing.EquippedTool:SetGuiButton(eraserButton)
		
		-- Highlight just the eraser and unhighlight all colors and pens
		Buttons.HighlightJustEraserButton(eraserButton)
		Buttons.HighlightJustColor()
		Buttons.HighlightJustPenButton()
	end)
	
end

function Buttons.ConnectUndoButton(undoButton)
	undoButton.Activated:Connect(function()
		local board = CanvasState.EquippedBoard
		
		-- nothing to undo
		if Drawing.CurveIndexOf[board] == 0 then return end

		local curveName = Config.CurveNamer(LocalPlayer, Drawing.CurveIndexOf[board])
		Drawing.CurveIndexOf[board] -= 1

		CanvasState.DeleteCurve(curveName)
		UndoCurveRemoteEvent:FireServer(board, curveName)
	end)
end

function Buttons.ConnectCloseButton(closeButton)
	closeButton.Activated:Connect(function()
		CanvasState.CloseBoard(CanvasState.EquippedBoard)
	end)
end

function Buttons.ConnectPenModeButton(penModeButton)
	penModeButton.Activated:Connect(function()
		if Drawing.EquippedTool.ToolType == "Pen" then
			if Drawing.PenMode == "FreeHand" then
				Buttons.SyncPenModeButton(penModeButton, "Line")
				Drawing.PenMode = "Line"
			else
				Buttons.SyncPenModeButton(penModeButton, "FreeHand")
				Drawing.PenMode = "FreeHand"
			end
		end
	end)
end

function Buttons.SyncPenModeButton(penModeButton, mode)
	if mode == "FreeHand" then
		penModeButton.Image = "rbxassetid://8260808744"
	elseif mode == "Line" then
		penModeButton.Image = "rbxassetid://8260809648"
	end
end

return Buttons