-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local RoactSpring = require(Common.Packages.RoactSpring)

local BoardViewport = Roact.Component:extend("BoardViewport")

function BoardViewport:init()
	self.ViewportAbsoluteSizeBinding, self.SetViewportAbsoluteSize = Roact.createBinding(Vector2.new(100,100))
	self.CamRef = Roact.createRef()
	self.VpfRef = Roact.createRef()
	

	self.CamStartCFrame = workspace.CurrentCamera.CFrame
	self.fov = workspace.CurrentCamera.FieldOfView
end

function BoardViewport:didMount()
	self.boardInstanceClone = self.props.Board._instance:Clone()
	self.boardInstanceClone.Parent = self.VpfRef:getValue()
end

function BoardViewport:willUnmount()
	self.boardInstanceClone:Destroy()
	self.boardInstanceClone = nil
end

function BoardViewport:render()
	local targetAbsolutePositionBinding = self.props.TargetAbsolutePositionBinding
	local targetAbsoluteSizeBinding = self.props.TargetAbsoluteSizeBinding

	local cam = e("Camera", {

		FieldOfView = self.fov,
		CFrame = Roact.joinBindings({
			self.ViewportAbsoluteSizeBinding,
			targetAbsolutePositionBinding,
			targetAbsoluteSizeBinding,
			self.props.SpringAlphaBinding,
		}):map(function(values)
			local boardCFrame = self.props.Board:SurfaceCFrame()
			return boardCFrame * boardCFrame:Lerp(self.CamStartCFrame * self:BoardToCameraCFrame(values[1], values[2], values[3]):Inverse(), values[4]):Inverse() * self.CamStartCFrame
		end),
		

		[Roact.Ref] = self.CamRef,

	})

	return e("ViewportFrame", {

		CurrentCamera = self.CamRef,
		
		[Roact.Ref] = self.VpfRef,

		Position = self.props.Position or UDim2.fromScale(0,0),
		Size = self.props.Size or UDim2.fromScale(1,1),
		ZIndex = self.props.ZIndex or 0,

		BackgroundTransparency = 1,
		ImageTransparency = self.props.ImageTransparency or 0,
		ImageColor3 = self.props.ImageColor3 or Color3.new(1,1,1),

		Ambient = Color3.new(1,1,1),
		LightColor = Color3.new(140/255,140/255,140/255),
		LightDirection = Vector3.new(0,-2,-1),

		[Roact.Change.AbsoluteSize] = function(vpfInstance)
			self.SetViewportAbsoluteSize(vpfInstance.AbsoluteSize)
		end,

	}, {
		CanvasCamera = cam,
	})

end

function BoardViewport:BoardToCameraCFrame(viewportAbsoluteSize, targetAbsolutePosition, targetAbsoluteSize)
	local fov = self.fov
	local subjectHeight = self.props.Board:SurfaceSize().Y

	local tanHalfFOV = math.tan(math.rad(fov/2))

	local canvasButtonHeightScale = (targetAbsoluteSize.Y / viewportAbsoluteSize.Y)
	local zDistance = (subjectHeight/2 / canvasButtonHeightScale) / tanHalfFOV
	local studsPerPixel = subjectHeight / targetAbsoluteSize.Y

	local canvasCentre = targetAbsolutePosition + Vector2.new(0,36) + targetAbsoluteSize / 2
	local vpfCentre = viewportAbsoluteSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre

	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel -- y-axis points down in gui world

	return CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

return BoardViewport