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
local function setBindings(self, absoluteSize, absolutePosition)
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

	self.blockerSizeBinding = self.camPropsBinding:map(function(camProps)

		local zDistance = camProps.NearPlaneZ + Config.GuiCanvas.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(camProps.ViewportSize, camProps.FieldOfView, zDistance)

		-- Size it to cover the whole canvas region (spatial audio button can move)
		-- Shrink it slightly so it's not visible at edges
		return Vector3.new(
			absoluteSize.X * factor * 0.99,
			absoluteSize.Y * factor * 0.99,
			Config.GuiCanvas.MuteButtonBlockerThickness
		)
	end)

	self.blockerCFrameBinding = self.camPropsBinding:map(function(camProps)

		local zDistance = camProps.NearPlaneZ + Config.GuiCanvas.MuteButtonNearPlaneZOffset

		local factor = pixelsToStuds(camProps.ViewportSize, camProps.FieldOfView, zDistance)

		local viewportCentre = camProps.ViewportSize / 2
		local canvasCentre = absolutePosition + absoluteSize / 2 + Vector2.new(0, 36)
		local pixelShift = canvasCentre - viewportCentre

		local x = pixelShift.X * factor
		local y = -pixelShift.Y * factor

		-- Position blocker to coincide with canvas
		return camProps.CFrame * CFrame.new(x, y, 0)
			+ camProps.CFrame.LookVector * (zDistance + Config.GuiCanvas.MuteButtonBlockerThickness / 2)
	end)
end

function GuiBoardViewer:init()
	setBindings(self, self.props.CanvasAbsoluteSize, self.props.CanvasAbsolutePosition)
end

function GuiBoardViewer:willUpdate(nextProps, nextState)
	if nextProps.CanvasAbsoluteSize ~= self.props.CanvasAbsoluteSize
			or nextProps.CanvasAbsolutePosition ~= self.props.CanvasAbsolutePosition then

		setBindings(self, nextProps.CanvasAbsoluteSize, nextProps.CanvasAbsolutePosition)
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

		CanvasAbsolutePosition = self.props.CanvasAbsolutePosition,
		CanvasAbsoluteSize = self.props.CanvasAbsoluteSize,

		-- Surface guis are used in each figure which globally resets ZIndexing
		-- inside that surfaceGui, but they are all shifted up by this value so that
		-- we can fit things underneath all of them.
		ZIndex = 1,
	})

	-- Display a cloned instance of an empty board in a viewport frame.
	local boardViewport = e(BoardViewport, {

		TargetAbsolutePosition = self.props.CanvasAbsolutePosition,
		TargetAbsoluteSize = self.props.CanvasAbsoluteSize,
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
