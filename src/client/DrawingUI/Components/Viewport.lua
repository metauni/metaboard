-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Viewport = Roact.Component:extend("Viewport")

function Viewport:init()
	self.ViewportAbsoluteSizeBinding, self.SetViewportAbsoluteSize = Roact.createBinding(Vector2.new(100,100))
	self.CamRef = Roact.createRef()
end

function Viewport:render()
	local targetAbsolutePositionBinding = self.props.TargetAbsolutePositionBinding
	local targetAbsoluteSizeBinding = self.props.TargetAbsoluteSizeBinding

	local cam = e("Camera", {

		FieldOfView = self.props.FieldOfView,
		CFrame = Roact.joinBindings({
			self.ViewportAbsoluteSizeBinding,
			targetAbsolutePositionBinding,
			targetAbsoluteSizeBinding
		}):map(function(values) return self:CameraCFrame(unpack(values)) end),

		[Roact.Ref] = self.CamRef,

	})

	return e("ViewportFrame", {

		CurrentCamera = self.CamRef,

		Position = self.props.Position or UDim2.fromScale(0,0),
		Size = self.props.Size or UDim2.fromScale(1,1),
		ZIndex = self.props.ZIndex or 0,

		BackgroundTransparency = 1,
		ImageTransparency = self.props.ImageTransparency or 0,
		ImageColor3 = self.props.ImageColor3 or Color3.new(1,1,1),

		Ambient = Color3.new(1,1,1),
		LightColor = Color3.new(1,1,1),
		LightDirection = Vector3.new(0,1,0),

		[Roact.Change.AbsoluteSize] = function(vpfInstance)
			self.SetViewportAbsoluteSize(vpfInstance.AbsoluteSize)
		end,

	}, {
		CanvasCamera = cam,
		Children = Roact.createFragment(self.props[Roact.Children]),
	})

end

function Viewport:CameraCFrame(viewportAbsoluteSize, targetAbsolutePosition, targetAbsoluteSize)
	local fov = self.props.FieldOfView
	local subjectHeight = self.props.SubjectHeight
	local subjectCFrame = self.props.SubjectCFrame

	local tanHalfFOV = math.tan(math.rad(fov/2))

	local canvasButtonHeightScale = (targetAbsoluteSize.Y / viewportAbsoluteSize.Y)
	local zDistance = (subjectHeight/2 / canvasButtonHeightScale) / tanHalfFOV
	local studsPerPixel = subjectHeight / targetAbsoluteSize.Y

	local canvasCentre = targetAbsolutePosition + Vector2.new(0,36) + targetAbsoluteSize / 2
	local vpfCentre = viewportAbsoluteSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre

	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel -- y-axis points down in gui world

	return subjectCFrame * CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

return Viewport