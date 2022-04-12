-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)

local function lerp(a, b, t)
	if t < 0.5 then
    return a + (b - a) * t
  else
    return b - (b - a) * (1 - t)
  end
end

return function(self, linePart: Part, line)

	local canvasSize = self:Size()

	linePart.Size = Vector3.new(
		line:Length() * canvasSize.Y,
		line.ThicknessYScale * canvasSize.Y,
		Config.Canvas.ZThicknessStuds
	)

	linePart.Color = line.Color

	-- Position of the centre of the line relative to the surface of the board
	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, line:Centre().X / self:AspectRatio())
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, line:Centre().Y)
	local z = - Config.Canvas.ZThicknessStuds / 2
		- Config.Canvas.InitialZOffsetStuds
		- line.ZIndex * Config.Canvas.StudsPerZIndex

	linePart.CFrame = self:GetCFrame() * CFrame.new(x,y,z) * CFrame.Angles(0, 0, line:RotationRadians())
end