-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local CanvasViewport = Roact.Component:extend("CanvasViewport")

function CanvasViewport:init()
	self.vpfRef = Roact.createRef()
	self.camRef = Roact.createRef()
end

function CanvasViewport:render()
	local zIndex = self.props.ZIndex
	local fieldOfView = self.props.FieldOfView
	local canvasCFrame = self.props.CanvasCFrame

	local cam = e("Camera", {
		FieldOfView = fieldOfView,
		[Roact.Ref] = self.camRef,
	})

	local vpf = e("ViewportFrame", {
		Position = UDim2.fromScale(0,0),
		Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		[Roact.Ref] = self.vpfRef,
		[Roact.Change.AbsoluteSize] = function(vpfInstance)
			self.camRef:getValue().CFrame = canvasCFrame * self:CanvasToCameraCFrame(vpfInstance.AbsoluteSize)
		end
	}, {
		CanvasCamera = cam
	})

	return vpf
end

function CanvasViewport:CanvasToCameraCFrame(viewportPixelSize)
	local fov = self.props.FieldOfView
	local canvasHeightStuds = self.props.CanvasHeightStuds
	local canvasButtonInstance = self.props.CanvasButtonRef:getValue()

	if canvasButtonInstance == nil then
		return CFrame.identity
	end

	local canvasPixelPosition = canvasButtonInstance.AbsolutePosition + Vector2.new(0,36)
	local canvasPixelSize = canvasButtonInstance.AbsoluteSize

	local tanHalfFOV = math.tan(math.rad(fov/2))

	local canvasButtonHeightScale = (canvasPixelSize.Y / viewportPixelSize.Y)
	local zDistance = (canvasHeightStuds/2 / canvasButtonHeightScale) / tanHalfFOV
	local studsPerPixel = canvasHeightStuds / canvasPixelSize.Y

	local canvasCentre = canvasPixelPosition + canvasPixelSize / 2
	local vpfCentre = viewportPixelSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre
	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	-- y-axis points down in gui world
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel

	return CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

function CanvasViewport:didMount()
	local canvasCFrame = self.props.CanvasCFrame
	local vpfInstance = self.vpfRef:getValue()
	local mountBoard = self.props.MountBoard

	mountBoard(vpfInstance)
	self.camRef:getValue().CFrame = canvasCFrame * self:CanvasToCameraCFrame(vpfInstance.AbsoluteSize)
	vpfInstance.CurrentCamera = self.camRef:getValue()
end

function CanvasViewport:willUnmount()
	local unmountBoard = self.props.UnmountBoard

	unmountBoard()
end

return CanvasViewport