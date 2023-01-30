-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local Destructor = require(script.Parent.Parent.Destructor)

local BoardButton = {}
BoardButton.__index = BoardButton

function BoardButton.new(board, active, defaultOnClick)
	
	local self = setmetatable({
		
		Board = board,
		_destructor = Destructor.new(),
		DefaultOnClick = defaultOnClick,
		_active = active,
	}, BoardButton)

	self._destructor:Add(board.SurfaceChangedSignal:Connect(function()
		self:render()
	end))

	self:render()

	return self
end

function BoardButton:Destroy()
	self._destructor:Destroy()
end

function BoardButton:SetActive(active)
	self._active = active
	self:render()
end

function BoardButton:render()

	local buttonPart = self._buttonPart

	if not self._buttonPart then
		
		buttonPart = Instance.new("Part")
		self._destructor:Add(buttonPart)

		buttonPart.Archivable = false -- Prevent copying
		buttonPart.Name = "BoardButton"
		buttonPart.Transparency = 1
		buttonPart.CanQuery = true
		buttonPart.Anchored = true
		buttonPart.CanCollide = false
		buttonPart.CastShadow = false

		local clickDetector = Instance.new("ClickDetector") 
		clickDetector.Name = "ClickDetector"
		clickDetector.Parent = buttonPart

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Adornee = buttonPart
		surfaceGui.Parent = buttonPart

		local textButton = Instance.new("TextButton")
		textButton.Text = ""
		textButton.BackgroundTransparency = 1
		textButton.Position = UDim2.fromScale(0,0)
		textButton.Size = UDim2.fromScale(1,1)
		textButton.Parent = surfaceGui

		self._destructor:Add(textButton.Activated:Connect(function()
			if not self._active then
				return
			elseif self.OnClick then
				self.OnClick()
			elseif self.DefaultOnClick then
				self.DefaultOnClick()
			end
		end))
	end

	buttonPart.CFrame = self.Board.SurfaceCFrame
	buttonPart.Size = Vector3.new(self.Board.SurfaceSize.X, self.Board.SurfaceSize.Y, 0.5)
	buttonPart.ClickDetector.MaxActivationDistance = self._active and math.huge or 0

	buttonPart.Parent = self.Board._instance

	if not self._buttonPart then
		self._buttonPart = buttonPart
	end
end

return BoardButton