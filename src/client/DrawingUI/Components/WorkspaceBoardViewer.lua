-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Workspace = game:GetService("Workspace")
local Client = script.Parent.Parent.Parent

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local DrawingTask = require(Common.DrawingTask)
local RoactSpring = require(Common.Packages.RoactSpring)

-- Components
local PartCanvas = require(Client.PartCanvas)

local WorkspaceBoardViewer = Roact.PureComponent:extend("WorkspaceBoardViewer")

function WorkspaceBoardViewer:init()
	self.ScreenAbsoluteSizeBinding, self.SetScreenAbsoluteSize = Roact.createBinding(Vector2.new(100,100))
	self.CamRef = Roact.createRef()
	self.fov = Workspace.CurrentCamera.FieldOfView
	self.originalCFrame = Workspace.CurrentCamera.CFrame

	self.spring, self.api = RoactSpring.Controller.new({
		value = 0,
	})
end

function WorkspaceBoardViewer:didMount()
	self.OriginalCam = Workspace.CurrentCamera:Clone()
	Workspace.CurrentCamera = self.CamRef:getValue()

	self.api:start({ value = 1 })
end

function WorkspaceBoardViewer:willUnmount()
	self.OriginalCam.Parent = Workspace
	Workspace.CurrentCamera = self.OriginalCam
end

function WorkspaceBoardViewer:render()

	local targetAbsolutePositionBinding = self.props.AbsolutePositionBinding
	local targetAbsoluteSizeBinding = self.props.AbsoluteSizeBinding

	local cam = e("Camera", {

		FieldOfView = self.fov,
		CFrame = Roact.joinBindings({
			self.ScreenAbsoluteSizeBinding,
			targetAbsolutePositionBinding,
			targetAbsoluteSizeBinding,
			self.spring.value,
		}):map(function(values) return self.originalCFrame:Lerp(self:CameraCFrame(values[1], values[2], values[3]), values[4]) end),

		CameraType = Enum.CameraType.Scriptable,

		[Roact.Ref] = self.CamRef,

	})

	local canvas = e(PartCanvas, {

		Figures = self.props.Figures,

		FigureMaskBundles = self.props.FigureMaskBundles,

		CanvasSize = self.props.Board:SurfaceSize(),
		CanvasCFrame = self.props.Board:SurfaceCFrame(),

		AsFragment = false,
	})

	return e("Frame", {

		Position = UDim2.fromScale(0,0),
		Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1,

		[Roact.Change.AbsoluteSize] = function(rbx)
			self.SetScreenAbsoluteSize(rbx.AbsoluteSize)
		end,

	}, {
		CanvasCameraPortal = e(Roact.Portal, {
			target = Workspace,

			[Roact.Children] = {

				CanvasCamera = cam,

			}
		}),

		CanvasPortal = e(Roact.Portal, {
			target = Workspace,

			[Roact.Children] = {

				[self.props.Board._instance.Name.."DrawingUIViewer"] = canvas

			}
		})

	})

end

function WorkspaceBoardViewer:CameraCFrame(screenAbsoluteSize, targetAbsolutePosition, targetAbsoluteSize)
	local fov = self.fov
	local subjectHeight = self.props.Board:SurfaceSize().Y
	local subjectCFrame = self.props.Board:SurfaceCFrame()

	local tanHalfFOV = math.tan(math.rad(fov/2))

	local canvasButtonHeightScale = (targetAbsoluteSize.Y / screenAbsoluteSize.Y)
	local zDistance = (subjectHeight/2 / canvasButtonHeightScale) / tanHalfFOV
	local studsPerPixel = subjectHeight / targetAbsoluteSize.Y

	local canvasCentre = targetAbsolutePosition + Vector2.new(0,36) + targetAbsoluteSize / 2
	local vpfCentre = screenAbsoluteSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre

	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel -- y-axis points down in gui world

	return subjectCFrame * CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

return WorkspaceBoardViewer