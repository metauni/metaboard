-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

--[[
	An invisible button placed over the canvas.
	Handles user input (see event connections in :render())
--]]
local CanvasIO = Roact.PureComponent:extend("CanvasIO")

--[[
	Return the position on the canvas in the y-relative scalar coordinates
	(sx,sy) ∈ [0,aspectRatio] x [0,1]
--]]
local function toCanvasPoint(self, x: number, y: number): Vector2
	
	return Vector2.new(x - self.props.CanvasAbsolutePosition.X, y - (self.props.CanvasAbsolutePosition.Y + 36)) / self.props.CanvasAbsoluteSize.Y
end

--[[
	The input centre is within the canvas boundaries.
	Important: points recorded outside the boundaries cause undefined behaviour,
	(like unerasable lines) and can happen as a result of floating point errors
--]]
local function withinCanvas(self, x: number, y: number): boolean

	local canvasPoint = toCanvasPoint(self, x, y)

	return
		0 <= canvasPoint.X and canvasPoint.X <= self.props.AspectRatio and
		0 <= canvasPoint.Y and canvasPoint.Y <= 1
end

function CanvasIO:render()

	local cursorPositionBinding = self.props.CursorPositionBinding
	local setCursorPixelPosition = self.props.SetCursorPixelPosition

	return e("TextButton", {

		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,

		AnchorPoint = self.props.AnchorPoint,
		Position = UDim2.fromOffset(self.props.CanvasAbsolutePosition.X + self.props.Margin/2, self.props.CanvasAbsolutePosition.Y + self.props.Margin/2 + 36),
		Size = UDim2.fromOffset(self.props.CanvasAbsoluteSize.X - self.props.Margin, self.props.CanvasAbsoluteSize.Y - self.props.Margin),

		--[[
			Multiple user inputs can occur per frame (1 to 3) so we queue them so
			that they can be performed all at once (only one setState call)
		--]]

		[Roact.Event.MouseButton1Down] = function(rbx, x, y)

			setCursorPixelPosition(x,y)

			if withinCanvas(self, x, y) then
				self.props.QueueToolDown(toCanvasPoint(self, x, y))
			end
		end,

		[Roact.Event.MouseMoved] = function(rbx, x, y)

			if withinCanvas(self, x, y) then

				-- Simple palm rejection
				if UserInputService.TouchEnabled and self.props.ToolHeld then
					local cursorUDim2 = cursorPositionBinding:getValue()
					local cursorPos = Vector2.new(cursorUDim2.X.Offset, cursorUDim2.Y.Offset)
					local diff = (Vector2.new(x,y) - cursorPos).Magnitude
					if diff > Config.GuiCanvas.MaxLineLengthTouchPixels then
						return
					end
				end

				setCursorPixelPosition(x,y)

				if self.props.ToolHeld then
					self.props.QueueToolMoved(toCanvasPoint(self, x, y))
				end

			else

				if self.props.ToolHeld then
					self.props.QueueToolUp()
				end
			end
		end,

		[Roact.Event.MouseLeave] = function(rbx, x, y)

			if self.props.ToolHeld then
				self.props.QueueToolUp()
			end
		end,

		[Roact.Event.MouseButton1Up] = function(rbx, x, y)

			if self.props.ToolHeld then
				self.props.QueueToolUp()
			end
		end,
	})
end

return CanvasIO