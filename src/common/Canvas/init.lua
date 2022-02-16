-- Services
local Common = script.Parent

-- Imports
local Config = require(Common.Config)
local Destructor = require(Common.Packages.Destructor)

-- Canvas
local Canvas = {}
Canvas.__index = Canvas

--[[
Wraps the part whose front (back?) surface is where the lines of the board
are attached/positioned relative to.
This object is used as an interface for updating the physical state of the
board in response to changes in the data that defines the board
This is not the source of truth of the state of the board, just a
a representation of that state according to how the client wants to see it.
--]]
function Canvas.new()
	local self = setmetatable({
		_destructor = Destructor.new()
	}, Canvas)

	return self
end

function Canvas:Destroy()
	self._destructor:Destroy()
end


return Canvas