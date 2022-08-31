-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

local CanvasViewport = Roact.Component:extend("CanvasViewport")

function CanvasViewport:init()
	self.CamRef = Roact.createRef()
	self.VpfRef = Roact.createRef()
end

function CanvasViewport:render()

	local cam = e("Camera", {

		FieldOfView = self.props.FieldOfView,
		CFrame = self.props.Board:SurfaceCFrame() * self:BoardToCameraCFrame(),

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

	},
	{
		CanvasCamera = cam,
		Figures = e("Folder", {}, self.props[Roact.Children])
	})

end

function CanvasViewport:BoardToCameraCFrame()
	local subjectHeight = self.props.Board:SurfaceSize().Y

	local tanHalfFOV = math.tan(math.rad(self.props.FieldOfView/2))

	local zDistance = (subjectHeight/2) / tanHalfFOV

	return CFrame.Angles(0,math.pi,0) * CFrame.new(0, 0, zDistance)
end

return CanvasViewport