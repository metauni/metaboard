local Pen = {}
Pen.__index = Pen

function Pen.new(color, thicknessYScale, guiButton)
	local pen = setmetatable({
		Color = color,
		ThicknessYScale = thicknessYScale,
		GuiButton = guiButton,
		ToolType = "Pen",
	},Pen)
	
	pen:Set(color, thicknessYScale)
	
	return pen
end

function Pen:SetColor(color)
	self.Color = color
end

function Pen:SetThicknessYScale(thicknessYScale)
	self.ThicknessYScale = thicknessYScale
end

function Pen:Set(color, thicknessYScale)
	self.Color = color
	self.ThicknessYScale = thicknessYScale
end

local Eraser = {}
Eraser.__index = Eraser

function Eraser.new(thicknessYScale, guiButton)
	return setmetatable({
		ThicknessYScale = thicknessYScale,
		GuiButton = guiButton,
		ToolType = "Eraser"
	},Eraser)
end

function Eraser:SetThicknessYScale(thicknessYScale)
	self.ThicknessYScale = thicknessYScale
end

function Eraser:SetGuiButton(guiButton)
	self.GuiButton = guiButton
end

return {Pen=Pen, Eraser=Eraser}
