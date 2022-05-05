-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Viewport = require(script.Parent.Viewport)

local BoardViewport = Roact.Component:extend("BoardViewport")

function BoardViewport:init()
	self.folderRef = Roact.createRef()
end

function BoardViewport:didMount()
	self.boardInstanceClone = self.props.Board._instance:Clone()
	self.boardInstanceClone.Parent = self.folderRef:getValue()
end

function BoardViewport:willUnmount()
	self.boardInstanceClone:Destroy()
	self.boardInstanceClone = nil
end

function BoardViewport:render()

	local folder = e("Folder", {

		[Roact.Ref] = self.folderRef,

	})

	return e(Viewport, {

		TargetAbsolutePositionBinding = self.props.TargetAbsolutePositionBinding,
		TargetAbsoluteSizeBinding = self.props.TargetAbsoluteSizeBinding,

		SubjectCFrame = self.props.Board:SurfaceCFrame(),
		SubjectHeight = self.props.Board:SurfaceSize().Y,

		ZIndex = self.props.ZIndex,

		FieldOfView = 10,

		[Roact.Children] = {
			Board = folder
		}

	})
end

return BoardViewport