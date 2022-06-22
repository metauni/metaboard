-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local RunService = game:GetService("RunService")
local Client = script.Parent.Parent.Parent

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local FrameCanvas = require(Client.FrameCanvas)
local BoardViewport = require(script.BoardViewport)

local GuiBoardViewer = Roact.PureComponent:extend("GuiBoardViewer")

local function connectToCameraProps(self, camera)
	return camera.Changed:Connect(function(property)
		self.setCamProps({
			CFrame = workspace.CurrentCamera.CFrame,
			FieldOfView = workspace.CurrentCamera.FieldOfView,
			ViewportSize = workspace.CurrentCamera.ViewportSize,
			NearPlaneZ = workspace.CurrentCamera.NearPlaneZ,
		})
	end)
end

function GuiBoardViewer:init()
	self.camPropsBinding, self.setCamProps = Roact.createBinding({
		CFrame = workspace.CurrentCamera.CFrame,
		FieldOfView = workspace.CurrentCamera.FieldOfView,
		ViewportSize = workspace.CurrentCamera.ViewportSize,
		NearPlaneZ = workspace.CurrentCamera.NearPlaneZ,
	})
end

function GuiBoardViewer:didMount()
	self.cameraPropsChangedConnection = connectToCameraProps(self, workspace.CurrentCamera)

	self.currentCameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.cameraPropsChangedConnection:Disconnect()
		self.cameraPropsChangedConnection = connectToCameraProps(self, workspace.CurrentCamera)
	end)
end

function GuiBoardViewer:willUnmount()
	self.cameraPropsChangedConnection:Disconnect()
	self.currentCameraChangedConnection:Disconnect()
end

local function pixelsToStuds(viewportSize, fieldOfView, zDistance)
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView) / 2)

	return (1 / viewportSize.Y) * 2 * zDistance * hfactor
end

function GuiBoardViewer:render()
	local sizeBinding = Roact.joinBindings({
		CamProps = self.camPropsBinding,
		AbsoluteSize = self.props.AbsoluteSizeBinding,
		AbsolutePosition = self.props.AbsolutePositionBinding,
	}):map(function(values)
		local zDistance = values.CamProps.NearPlaneZ + Config.Gui.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(values.CamProps.ViewportSize, values.CamProps.FieldOfView, zDistance)

		local x = values.AbsoluteSize.X * factor
		local y = values.AbsoluteSize.Y * factor
		local z = Config.Gui.MuteButtonBlockerThickness

		return Vector3.new(x, y, z)
	end)

	local cFrameBinding = Roact.joinBindings({
		CamProps = self.camPropsBinding,
		AbsoluteSize = self.props.AbsoluteSizeBinding,
		AbsolutePosition = self.props.AbsolutePositionBinding,
	}):map(function(values)
		local zDistance = values.CamProps.NearPlaneZ + Config.Gui.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(values.CamProps.ViewportSize, values.CamProps.FieldOfView, zDistance)

		local viewportCentre = values.CamProps.ViewportSize / 2
		local canvasCentre = values.AbsolutePosition + values.AbsoluteSize / 2 + Vector2.new(0, 36)
		local pixelShift = canvasCentre - viewportCentre

		local x = pixelShift.X * factor
		local y = -pixelShift.Y * factor

		return values.CamProps.CFrame * CFrame.new(x, y, 0)
			+ values.CamProps.CFrame.LookVector * (zDistance + Config.Gui.MuteButtonBlockerThickness / 2)
	end)

	local buttonBlocker = e("Part", {

		Transparency = 0.5,
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
		["CanQuery"] = true,

		Size = sizeBinding,
		CFrame = cFrameBinding,
	})

	local canvas = e(FrameCanvas, {

		Figures = self.props.Figures,

		FigureMaskBundles = self.props.FigureMaskBundles,

		AbsolutePositionBinding = self.props.AbsolutePositionBinding,
		AbsoluteSizeBinding = self.props.AbsoluteSizeBinding,

		ZIndex = 1,
	})

	local boardViewport = e(BoardViewport, {

		TargetAbsolutePositionBinding = self.props.AbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.props.AbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,
		FieldOfView = 30,
	})

	return e("Folder", {}, {

		Canvas = e("ScreenGui", {

			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Enabled = false,

			[Roact.Children] = {
				Canvas = canvas,
			},
		}),

		BoardViewport = boardViewport,

		ButtonBlocker = e(Roact.Portal, {

			target = workspace,

		}, {

			ButtonBlocker = buttonBlocker,
		}),
	})
end

return GuiBoardViewer
