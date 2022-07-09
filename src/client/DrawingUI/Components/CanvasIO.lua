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

	local absPosition = self.props.AbsolutePositionBinding:getValue()
	local absSize = self.props.AbsoluteSizeBinding:getValue()

	return Vector2.new(x - absPosition.X, y - (absPosition.Y + 36)) / absSize.Y
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

--[[
	Assign mapped bindings for position and size of canvas button

	Typically mapped bindings are created on the fly in :render() but this causes
	it to update any bound properties even if they haven't changed.
--]]
local function setBindings(self, margin: number)

	self.positionBinding = self.props.AbsolutePositionBinding:map(function(absPosition)
		return UDim2.fromOffset(absPosition.X + margin/2, absPosition.Y + margin/2 + 36)
	end)

	self.sizeBinding = self.props.AbsoluteSizeBinding:map(function(absSize)
		return UDim2.fromOffset(absSize.X - margin, absSize.Y - margin)
	end)
end

function CanvasIO:init()
	setBindings(self, self.props.Margin)
end

function CanvasIO:willUpdate(nextProps, nextState)
	if nextProps.Margin ~= self.props.Margin then
		setBindings(self, nextProps.Margin)
	end
end

function CanvasIO:render()

	local cursorPositionBinding = self.props.CursorPositionBinding
	local setCursorPixelPosition = self.props.SetCursorPixelPosition

	return e("TextButton", {

		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,

		AnchorPoint = self.props.AnchorPoint,
		Position = self.positionBinding,
		Size = self.sizeBinding,

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
					if diff > Config.Drawing.MaxLineLengthTouchPixels then
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