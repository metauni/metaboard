-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local INSET = GuiService:GetGuiInset()

-- Imports
local root = script.Parent.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
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

	local canvasCentre = targetAbsolutePosition + INSET + targetAbsoluteSize / 2
	local vpfCentre = viewportAbsoluteSize / 2
	local canvasCentreOffset = canvasCentre - vpfCentre

	local xOffsetStuds = canvasCentreOffset.X * studsPerPixel
	local yOffsetStuds = -canvasCentreOffset.Y * studsPerPixel -- y-axis points down in gui world

	return CFrame.Angles(0,math.pi,0) * CFrame.new(-xOffsetStuds,-yOffsetStuds, zDistance)
end

function BoardViewport:init()
	self.CamRef = Roact.createRef()
	self.VpfRef = Roact.createRef()
end

function BoardViewport:didMount()

	-- If the board is inside a model, clone the model
	local instance: Part = self.props.Board:GetPart()
	local wholeBoard = instance
	if instance.Parent:IsA("Model") and instance.Parent.PrimaryPart == instance then
		wholeBoard = instance.Parent
	end

	self._wholeBoardClone = wholeBoard:Clone()
	
	-- Take off the tags
	for _, desc in self._wholeBoardClone:GetDescendants() do
		for _, tag in CollectionService:GetTags(desc) do
			CollectionService:RemoveTag(desc, tag)
		end
	end

	self._wholeBoardClone.Parent = self.VpfRef:getValue()
end

function BoardViewport:willUnmount()
	self._wholeBoardClone:Destroy()
	self._wholeBoardClone = nil
end

function BoardViewport:render()

	local toCamCFrame = boardToCameraCFrame(
		self.props.SurfaceSize.Y,
		workspace.CurrentCamera.ViewportSize,
		self.props.TargetAbsolutePosition,
		self.props.TargetAbsoluteSize,
		self.props.FieldOfView
	)

	local cam = e("Camera", {

		FieldOfView = self.props.FieldOfView,
		CFrame = self.props.SurfaceCFrame * toCamCFrame,

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

	}, {
		CanvasCamera = cam,
	})

end

return BoardViewport