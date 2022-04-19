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

return function(self, pointPart: Part, pos: Vector2, thicknessYScale: number, color: Color3, zIndex: number)
	pointPart.Color = color

	local canvasSize = self:Size()

	pointPart.Size =
		Vector3.new(
			Config.Canvas.ZThicknessStuds,
			thicknessYScale * canvasSize.Y,
			thicknessYScale * canvasSize.Y)

	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, pos.X / self:AspectRatio())
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, pos.Y)
	local z = - Config.Canvas.ZThicknessStuds / 2
		- Config.Canvas.InitialZOffsetStuds
		- zIndex * Config.Canvas.StudsPerZIndex

	pointPart.CFrame = self:GetCFrame() * CFrame.new(x,y,z) * CFrame.Angles(0,math.pi/2,0)
end
