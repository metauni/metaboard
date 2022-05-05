-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local UserInputService = game:GetService("UserInputService")

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Config = require(Common.Config)

local Slider = Roact.PureComponent:extend("Slider")

Slider.defaultProps = {
	Size = UDim2.fromOffset(150, 55),
	LayoutOrder = 0,
	KnobSizeOffset = 20,
	KnobColor = Color3.new(1,1,1),
	RailThicknessOffset = 7,
}

function Slider:init()
	self.KnobRef = Roact.createRef()

	self:setState({
		Held = false,
		HoldDelta = 0,
	})
end

function Slider:render()
	local layoutOrder = self.props.LayoutOrder
	local onKnobPositionUpdate = self.props.OnKnobPositionUpdate
	local size = self.props.Size
	local knobSizeOffset = self.props.KnobSizeOffset
	local knobColor = self.props.KnobColor
	local knobAlpha = self.props.KnobAlpha
	local knobLabelText = self.props.KnobLabelText
	local railThicknessOffset = self.props.RailThicknessOffset

	local knobLabel = e("TextLabel", {
		Text = knobLabelText,
		TextScaled = true,
		BackgroundColor3 = Color3.new(64/255, 64/255, 64/255),
		TextColor3 = Config.UITheme.Stroke,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(20, 20),
		BorderSizePixel = 0,
		[Roact.Children] = {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0.2, 0),
			})
		}
	})


	local knob = e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(knobSizeOffset, knobSizeOffset),
		BackgroundColor3 = knobColor,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(knobAlpha, 0.5),
		ZIndex = 1,
		[Roact.Ref] = self.KnobRef,
		[Roact.Event.MouseButton1Down] = function(rbx, x,y)
			local knobInstance = self.KnobRef:getValue()
			local knobCentreX = knobInstance.AbsolutePosition.X + knobInstance.AbsoluteSize.X/2

			self:setState({
				Held = true,
				HoldDelta = x - knobCentreX
			})
		end,
		[Roact.Event.MouseButton1Up] = function(rbx, x,y)
			self:setState({
				Held = false,
				HoldDelta = 0
			})
		end,
		[Roact.Children] = {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0.5,0)}),
			Label = knobLabel
		}
	})

	local rail = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1,0, 0, railThicknessOffset),
		ZIndex = 0,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0.5, 0),
		}),
		Knob = knob,
	})

	return e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5,0.5),
		LayoutOrder = layoutOrder,
		Position = self.props.Position,
		Size = UDim2.new(size.X + UDim.new(0, knobSizeOffset), size.Y),
		BackgroundTransparency = 1,
		[Roact.Event.MouseButton1Down] = function(rbx, x,y)
			self:setState({
				Held = true,
				HoldDelta = 0
			})
			onKnobPositionUpdate(self:ToAlpha(rbx, x, 0))
		end,
		[Roact.Event.MouseMoved] = function(rbx, x,y)
			if not self.state.Held then return end

			onKnobPositionUpdate(self:ToAlpha(rbx, x, self.state.HoldDelta))
		end,
		[Roact.Event.MouseButton1Up] = function(rbx, x,y)
			self:setState({
				Held = false,
				HoldDelta = 0
			})
		end,
		[Roact.Event.MouseLeave] = function(rbx, x,y)
			self:setState({
				Held = false,
				HoldDelta = 0
			})
		end,

		[Roact.Children] = {
			Rail = rail,
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, knobSizeOffset/2),
				PaddingRight = UDim.new(0, knobSizeOffset/2),
			}),
		}
	})
end

function Slider:ToAlpha(rbx, x, holdDelta)
	local knobSizeOffset = self.props.KnobSizeOffset

	return math.clamp((x - holdDelta - (rbx.AbsolutePosition.X + (knobSizeOffset/2)))/(rbx.AbsoluteSize.X - knobSizeOffset), 0, 1)
end

-- function Slider:didMount()

-- 	self._uisConnection = UserInputService.InputEnded:Connect(function(input)
-- 		if input.UserInputType == Enum.UserInputType.MouseButton1 then
-- 			self:setState({
-- 				Held = false,
-- 			})
-- 		end
-- 	end)
-- end

function Slider:willUnmount()
	print('Unmounted')
end

return Slider