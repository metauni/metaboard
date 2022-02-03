-- Services


-- Imports
local Common = script.Parent
local Config = require(Common.Config)

-- Canvas
local Canvas = {}
Canvas.__index = Canvas

-- Wraps the part whose front (back?) surface is where the lines of the board
-- are attached/positioned relative to.
-- This object is used as an interface for updating the physical state of the
-- board in response to changes in the data that defines the board
-- This is not the source of truth of the state of the board, just a
-- a representation of that state according to how the client wants to see it.
function Canvas.new(instance: Part)
	local self = setmetatable({
		_instance = instance
	}, Canvas)

	return self
end

function Canvas.CreateCanvasPart(boardInstance: Model | Part, face: string)
	local canvasPart = Instance.new("Part")
	if face == "Front" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(0,0,0) * CFrame.new(0,0,-boardInstance.Size.Z/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.X,boardInstance.Size.Y, Config.Canvas.ZThicknessStuds)
	elseif face == "Left" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(0,math.pi/2,0) * CFrame.new(0,0,-boardInstance.Size.X/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.Z,boardInstance.Size.Y, Config.Canvas.ZThicknessStuds)
	elseif face == "Back" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(0,math.pi,0) * CFrame.new(0,0,-boardInstance.Size.Z/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.X,boardInstance.Size.Y, Config.Canvas.ZThicknessStuds)
	elseif face == "Right" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(0,-math.pi/2,0) * CFrame.new(0,0,-boardInstance.Size.X/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.Z,boardInstance.Size.Y, Config.Canvas.ZThicknessStuds)
	elseif face == "Top" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(math.pi/2,0,0) * CFrame.new(0,0,-boardInstance.Size.Y/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.X,boardInstance.Size.Z, Config.Canvas.ZThicknessStuds)
	elseif face == "Bottom" then
		canvasPart.CFrame = boardInstance.CFrame * CFrame.Angles(-math.pi/2,0,0) * CFrame.new(0,0,-boardInstance.Size.Y/2)
		canvasPart.Size = Vector3.new(boardInstance.Size.X,boardInstance.Size.Z, Config.Canvas.ZThicknessStuds)
	end
end

local function createLinePart()
	local part = Instance.new("Part")
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CanTouch = false -- Do not trigger Touch events
	part.CanQuery = false -- Does not take part in e.g. GetPartsInPart

	return part
end

local function configureLinePart(part, line)
	
end


return Canvas