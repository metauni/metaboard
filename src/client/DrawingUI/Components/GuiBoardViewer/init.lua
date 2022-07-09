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

--[[
	Board viewer consisting of:
		- ViewportFrame that shows a clone of the empty board
		- Canvas showing figures made out of ScreenGui's and Frame objects
		- A part positioned to block the spatial-audio mute toggle, which otherwise
			captures any user input inside its boundaries. See bug report here:
			https://devforum.roblox.com/t/spatial-voice-icons-can-be-clicked-while-behind-gui-objects/1649049
--]]
local GuiBoardViewer = Roact.PureComponent:extend("GuiBoardViewer")

--[[
	Create binding for camera properties and mapped bindings for mute button
	blocker size and CFrame.

	Typically mapped bindings are created on the fly in :render() but this causes
	it to update any bound properties even if they haven't changed.
--]]
local function setBindings(self, absoluteSizeBinding, absolutePositionBinding)
	self.camPropsBinding, self.setCamProps = Roact.createBinding({
		CFrame = workspace.CurrentCamera.CFrame,
		FieldOfView = workspace.CurrentCamera.FieldOfView,
		ViewportSize = workspace.CurrentCamera.ViewportSize,
		NearPlaneZ = workspace.CurrentCamera.NearPlaneZ,
	})

	-- Returns the stud size of a pixel projected onto a plane facing the camera at
	-- a given zDistance
	local function pixelsToStuds(viewportSize, fieldOfView, zDistance)
		return (1 / viewportSize.Y) * 2 * zDistance * math.tan(math.rad(fieldOfView) / 2)
	end

	self.blockerSizeBinding = Roact.joinBindings({
		CamProps = self.camPropsBinding,
		AbsoluteSize = absoluteSizeBinding,
		AbsolutePosition = absolutePositionBinding,
	}):map(function(values)
		local zDistance = values.CamProps.NearPlaneZ + Config.Gui.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(values.CamProps.ViewportSize, values.CamProps.FieldOfView, zDistance)

		-- Size it to cover the whole canvas region (spatial audio button can move)
		-- Shrink it slightly so it's not visible at edges
		return Vector3.new(
			values.AbsoluteSize.X * factor * 0.99,
			values.AbsoluteSize.Y * factor * 0.99,
			Config.Gui.MuteButtonBlockerThickness
		)
	end)

	self.blockerCFrameBinding = Roact.joinBindings({
		CamProps = self.camPropsBinding,
		AbsoluteSize = absoluteSizeBinding,
		AbsolutePosition = absolutePositionBinding,
	}):map(function(values)
		local zDistance = values.CamProps.NearPlaneZ + Config.Gui.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(values.CamProps.ViewportSize, values.CamProps.FieldOfView, zDistance)

		local viewportCentre = values.CamProps.ViewportSize / 2
		local canvasCentre = values.AbsolutePosition + values.AbsoluteSize / 2 + Vector2.new(0, 36)
		local pixelShift = canvasCentre - viewportCentre

		local x = pixelShift.X * factor
		local y = -pixelShift.Y * factor

		-- Position blocker to coincide with canvas
		return values.CamProps.CFrame * CFrame.new(x, y, 0)
			+ values.CamProps.CFrame.LookVector * (zDistance + Config.Gui.MuteButtonBlockerThickness / 2)
	end)
end

function GuiBoardViewer:init()
	setBindings(self, self.props.AbsoluteSizeBinding, self.props.AbsolutePositionBinding)
end

function GuiBoardViewer:willUpdate(nextProps, nextState)
	if nextProps.AbsoluteSizeBinding ~= self.props.AbsoluteSizeBinding
			or nextProps.AbsolutePositionBinding ~= self.props.AbsolutePositionBinding then

		setBindings(self, self.props.AbsoluteSizeBinding, self.props.AbsolutePositionBinding)
	end
end


function GuiBoardViewer:didMount()

	-- Update camProps binding when relevant properties change in the given camera
	local function connectToCameraProps(camera: Camera)
		return camera.Changed:Connect(function(property)
			if ({ CFrame = true, FieldOfView = true, ViewportSize = true, NearPlaneZ = true })[property] then
				self.setCamProps({
					CFrame = workspace.CurrentCamera.CFrame,
					FieldOfView = workspace.CurrentCamera.FieldOfView,
					ViewportSize = workspace.CurrentCamera.ViewportSize,
					NearPlaneZ = workspace.CurrentCamera.NearPlaneZ,
				})
			end
		end)
	end

	-- Workspace.CurrentCamera may change, in which case we need to migrate the camera.Changed connection
	self.currentCameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.cameraPropsChangedConnection:Disconnect()
		self.cameraPropsChangedConnection = connectToCameraProps(workspace.CurrentCamera)
	end)

	self.cameraPropsChangedConnection = connectToCameraProps(workspace.CurrentCamera)
end

function GuiBoardViewer:willUnmount()
	self.cameraPropsChangedConnection:Disconnect()
	self.currentCameraChangedConnection:Disconnect()
end

function GuiBoardViewer:render()

	local buttonBlocker = e("Part", {

		Color = Color3.new(0,0,0),

		Transparency = 0.95, -- Must be semi-transparent (not fully) to actually block
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
		["CanQuery"] = true,

		Size = self.blockerSizeBinding,
		CFrame = self.blockerCFrameBinding,
	})

	-- Shows the figures as frames gathered in surface guis.
	local canvas = e(FrameCanvas, {

		Figures = self.props.Figures,

		FigureMaskBundles = self.props.FigureMaskBundles,

		AbsolutePositionBinding = self.props.AbsolutePositionBinding,
		AbsoluteSizeBinding = self.props.AbsoluteSizeBinding,

		-- Surface guis are used in each figure which globally resets ZIndexing
		-- inside that surfaceGui, but they are all shifted up by this value so that
		-- we can fit things underneath all of them.
		ZIndex = 1,
	})

	-- Display a cloned instance of an empty board in a viewport frame.
	local boardViewport = e(BoardViewport, {

		TargetAbsolutePositionBinding = self.props.AbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.props.AbsoluteSizeBinding,
		Board = self.props.Board,
		ZIndex = 0,

		-- Lower FOV => flattened perspective.
		FieldOfView = 30,
	})

	return e("Folder", {}, {

		Canvas = canvas,

		BoardViewport = boardViewport,

		ButtonBlocker = e(Roact.Portal, {

			target = workspace,
		}, {

			ButtonBlocker = buttonBlocker,
		}),
	})
end

return GuiBoardViewer
