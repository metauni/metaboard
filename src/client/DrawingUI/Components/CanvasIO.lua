-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local CanvasIO = Roact.PureComponent:extend("CanvasIO")

function CanvasIO:render()
	local absPositionBinding = self.props.AbsolutePositionBinding
	local absSizeBinding = self.props.AbsoluteSizeBinding
	local margin = self.props.Margin

	local ignoreGuiInset = self.props.IgnoreGuiInset
	local setCursorPosition = self.props.SetCursorPosition
	local cursorPositionBinding = self.props.CursorPositionBinding

	local toolHeld = self.props.ToolHeld

	local insetOffset = ignoreGuiInset and 36 or 0
	
	local function withinCanvas(x, y)
		local absPosition = absPositionBinding:getValue()
		local absSize = absSizeBinding:getValue()

		return
			0 <= (x - absPosition.X) and
			(x - absPosition.X) <= absPosition.X + absSize.X and
			0 <= (y - (absPosition.Y + insetOffset)) and
			(y - (absPosition.Y + insetOffset)) <= (absPosition.Y + insetOffset) + absSize.Y

	end

	local function toScalar(x, y)
		local absPosition = absPositionBinding:getValue()
		local absSize = absSizeBinding:getValue()

		return Vector2.new(x - absPosition.X, y - (absPosition.Y + insetOffset)) / absSize.Y
	end

	return e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		ZIndex = self.props.ZIndex,
		
		AnchorPoint = self.props.AnchorPoint,
		Position = absPositionBinding:map(function(absPosition)
			return UDim2.fromOffset(absPosition.X + margin/2, absPosition.Y + margin/2 + insetOffset)
		end),
		Size = self.props.AbsoluteSizeBinding:map(function(absSize)
			return UDim2.fromOffset(absSize.X - margin, absSize.Y - margin)
		end),
		
		[Roact.Event.MouseButton1Down] = function(rbx, x, y)
			setCursorPosition(Vector2.new(x,y))
			if withinCanvas(x, y) then
				self.props.ToolDown(toScalar(x, y))
			end
		end,
		[Roact.Event.MouseMoved] = function(rbx, x, y)
			if withinCanvas(x, y) then
				setCursorPosition(Vector2.new(x,y))

				-- Simple palm rejection
				if toolHeld and UserInputService.TouchEnabled then
					local diff = (Vector2.new(x,y) - cursorPositionBinding:getValue()).Magnitude
					if diff > Config.Drawing.MaxLineLengthTouchPixels then
						return
					end
				end

				self.props.ToolMoved(toScalar(x, y))
			else
				self.props.ToolUp()
			end
		end,
		[Roact.Event.MouseLeave] = function(rbx, x, y)
			self.props.ToolUp()
		end,
		[Roact.Event.MouseButton1Up] = function(rbx, x, y)
			self.props.ToolUp()
		end,
	})
end

return CanvasIO