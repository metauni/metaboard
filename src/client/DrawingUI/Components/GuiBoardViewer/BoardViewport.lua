-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

--[[
	Display a cloned instance of an empty board in a viewport frame.
	FieldOfView can be decreased to make the board appear flatter.

	TODO: Bug. If the board has been made semi transparent, that transparency
	will persist on the clone. Should probably save a clone on startup
--]]
local BoardViewport = Roact.Component:extend("BoardViewport")

--[[
	Gives the correct CFrame of the camera relative to the board Surface CFrame.
	The board surface will be positioned perfectly at the given region of the
	screen defined by targetAbsolutePosition and targetAbsoluteSize, assuming
	the aspect ratio of targetAbsoluteSize matches the board aspect ratio.
--]]
local function boardToCameraCFrame(boardHeight, viewportAbsoluteSize, targetAbsolutePosition, targetAbsoluteSize, fieldOfView)

	local tanHalfFOV = math.tan(math.rad(fieldOfView/2))

	local canvasButtonHeightScale = (targetAbsoluteSize.Y / viewportAbsoluteSize.Y)
	local zDistance = (boardHeight/2 / canvasButtonHeightScale) / tanHalfFOV
	local studsPerPixel = boardHeight / targetAbsoluteSize.Y

	local canvasCentre = targetAbsolutePosition + Vector2.new(0,36) + targetAbsoluteSize / 2
	local vpfCentre = viewportAbsoluteSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre

	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel -- y-axis points down in gui world

	return CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

--[[
	Assign mapped binding for the cframe of the camera

	Typically mapped bindings are created on the fly in :render() but this causes
	it to update any bound properties even if they haven't changed.
--]]
local function setBindings(self, board, fieldOfView)
	self.cFrameBinding = Roact.joinBindings({
		self.ViewportAbsoluteSizeBinding,
		self.props.TargetAbsolutePositionBinding,
		self.props.TargetAbsoluteSizeBinding,
	}):map(function(values)
		local boardCFrame = board:SurfaceCFrame()
		return boardCFrame * boardToCameraCFrame(board:SurfaceSize().Y, values[1], values[2], values[3], fieldOfView)
	end)
end

function BoardViewport:init()
	self.ViewportAbsoluteSizeBinding, self.SetViewportAbsoluteSize = Roact.createBinding(workspace.CurrentCamera.ViewportSize)
	self.CamRef = Roact.createRef()
	self.VpfRef = Roact.createRef()

	setBindings(self, self.props.Board, self.props.FieldOfView)
end

function BoardViewport:willUpdate(nextProps, nextState)
	if nextProps.Board ~= self.props.Board or nextProps.FieldOfView ~= self.props.FieldOfView then
		setBindings(self, nextProps.Board, nextProps.FieldOfView)
	end
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

	local cam = e("Camera", {

		FieldOfView = self.props.FieldOfView,
		CFrame = self.cFrameBinding,

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

		-- TODO: this lighting could be done better.
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

return BoardViewport