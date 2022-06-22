-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Import
local Config = require(Common.Config)

local rd = math.random

return function(aspectRatio, totalLines, minLinesPerCurve, maxLinesPerCurve)
	local lineCount = 0
	local curveCount = 0

	local figures = {}
	while lineCount < totalLines do
		curveCount += 1

		local points = {}
		local point = Vector2.new(rd() * aspectRatio, rd())

		local numCurveLines = rd(
			math.min(minLinesPerCurve, totalLines - lineCount),
			math.min(maxLinesPerCurve, totalLines - lineCount)
		)

		lineCount += numCurveLines

		for i = 1, numCurveLines + 1 do
			local ydir = rd() > 0.5 and 1 or -1
			local xdir = rd() > 0.5 and 1 or -1
			point = Vector2.new(
				math.clamp(point.X + 0.01 * xdir * rd(), 0, aspectRatio),
				math.clamp(point.Y + 0.01 * ydir * rd(), 0, 1)
			)
			table.insert(points, point)
		end

		figures[Config.GenerateUUID()] = {
			Type = "Curve",
			Points = points,
			Width = 0.003,
			Color = Color3.new(rd(), rd(), rd()),
			ZIndex = curveCount,
			Mask = {},
		}
	end

	return figures
end
