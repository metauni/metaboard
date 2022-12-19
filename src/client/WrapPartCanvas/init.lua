-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Feather = require(Common.Packages.Feather)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local PartCanvas = require(script.Parent.PartCanvas)

--[[
	Wraps the feather-based PartCanvas in a Roact component
--]]
local WrapPartCanvas = Roact.Component:extend("WrapPartCanvas")

function WrapPartCanvas:init()
	
	self.ModelRef = Roact.createRef()
end

function WrapPartCanvas:render()
	
	return e("Model", {

		[Roact.Ref] = self.ModelRef,
	})
end

function WrapPartCanvas:didMount()
	
	self.Canvas = Feather.mount(Feather.createElement(PartCanvas, self.props), self.ModelRef:getValue(), "Feather Canvas")
end

function WrapPartCanvas:didUpdate(prevProps, prevState)

	Feather.update(self.Canvas, Feather.createElement(PartCanvas, self.props))
end

function WrapPartCanvas:willUnmount()

	Feather.umount(self.Canvas)
end

return WrapPartCanvas