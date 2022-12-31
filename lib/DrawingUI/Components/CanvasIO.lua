-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
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

		[Roact.Event.InputBegan] = function(rbx, inputObject)

			-- Ignore irrelevant input types
			if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 
				and inputObject.UserInputType ~= Enum.UserInputType.Touch then
				
				return
			end

			if inputObject.UserInputType == Enum.UserInputType.Touch then

				-- Only start a new stroke if the active input object has ended
				
				if self._activeInputObject then
					
					if self._activeInputObject.UserInputState.Value < Enum.UserInputState.End.Value then
						
						-- active input object is not done
						return
						
					end
					
				end
			end

			-- Set the new active input object
			self._activeInputObject = inputObject

			local x, y = inputObject.Position.X, inputObject.Position.Y + 36

			setCursorPixelPosition(x,y)

			if withinCanvas(self, x, y) then
				self.props.QueueToolDown(toCanvasPoint(self, x, y))
			end
		end,

		[Roact.Event.InputChanged] = function(rbx, inputObject)
			
			if inputObject.UserInputType == Enum.UserInputType.Touch then
				
				-- ignore other fingers/palms moving
				if inputObject ~= self._activeInputObject then
					return
				end
			end

			local x, y = inputObject.Position.X, inputObject.Position.Y + 36

			if withinCanvas(self, x, y) then

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

		[Roact.Event.InputEnded] = function(rbx, inputObject)

			if inputObject.UserInputType == Enum.UserInputType.Touch then
				
				-- ignore other fingers/palms lifting
				if inputObject ~= self._activeInputObject then
	
					return
				end
			end

			if self.props.ToolHeld then
				self.props.QueueToolUp()
			end
		end,
	})
end

return CanvasIO