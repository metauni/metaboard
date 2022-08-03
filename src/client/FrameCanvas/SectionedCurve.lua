-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local Line = require(script.Parent.Line)
local Circle = require(script.Parent.Circle)

local SECTION_LENGTH = 50

local SubCurve = Roact.Component:extend("SubCurve")

function SubCurve:render()
	local points = self.props.Points
	local lineMask = self.props.Mask

	local firstIndex = self.props.FirstIndex
  local lastIndex = self.props.LastIndex

  local ithline = function(i)
		local a, b, c, d = points[i-1], points[i], points[i+1], points[i+2]
		local mab = lineMask[tostring(i-1)]
		local mbc = lineMask[tostring(i)]
		local mcd = lineMask[tostring(i+1)]

		if mbc then
			return nil
		end

		if b == c then

			return Circle({

				Position = b,
				Width = self.props.Width,
				Color = self.props.Color,

			})
		end

		local roundedP0 = i == 1 or mab
		local roundedP1 = mcd
		-- roundedP1 = true

		local p0Extend, p1Extend = 0, 0

		if i > 1 and not mab and a ~= b then
			local u = a - b
			local v = c - b

			if u:Dot(v) <= 0 then

				local sinTheta = math.clamp(math.abs(u.Unit:Cross(v.Unit)), 0, 1)
				local cosTheta = math.clamp(u.Unit:Dot(v.Unit), -1, 1)

				-- Check that both sin(theta) and cos(theta) are not NaN.
				if sinTheta == sinTheta and cosTheta == cosTheta then
					if sinTheta < 1/20 then
						-- prevent gaps in (almost) parallel joints
						p0Extend = 0.001
					else
						p0Extend = math.clamp(self.props.Width/2 * (1 + cosTheta) / sinTheta, 0, self.props.Width/2)
					end
				end
			else
				roundedP0 = true
			end
		end

		if i+1 < #points and not mbc and c ~= d then
			local u = b - c
			local v = d - c

			if u:Dot(v) <= 0 then
				local sinTheta = math.clamp(math.abs(u.Unit:Cross(v.Unit)), 0, 1)
				local cosTheta = math.clamp(u.Unit:Dot(v.Unit), -1, 1)

				-- Check that both sin(theta) and cos(theta) are not NaN.
				if sinTheta == sinTheta and cosTheta == cosTheta then
					if sinTheta < 1/20 then
						-- prevent gaps in (almost) parallel joints
						p1Extend = 0.001
					else
						p1Extend = math.clamp(self.props.Width/2 * (1 + cosTheta) / sinTheta, 0, self.props.Width/2)
					end
				end
			end
			-- No "else roundedP1 = true" because this would double up"
		end

    local rounded = roundedP0 or roundedP1

    if rounded then
      p0Extend = self.props.Width/2
      p1Extend = self.props.Width/2
    end


		local p0E = points[i] + p0Extend * (points[i] - points[i+1]).Unit
		local p1E = points[i+1] + p1Extend * (points[i+1] - points[i]).Unit


		return Line({

			P0 = p0E,
			P1 = p1E,
			Width = self.props.Width,
			Color = self.props.Color,

			Rounded = rounded,

		})
	end

	local lines = {}
	for i=firstIndex, lastIndex-1 do
		lines[tostring(i)] = ithline(i)
	end

	-- Keep the end circle in a consistent place so it doesn't get destroyed
	-- and created over and over
	if firstIndex == 1 and not lineMask[tostring(#points-1)] then

		lines["CurveEndCircle"] = Circle({

			Position = points[#points],
			Width = self.props.Width,
			Color = self.props.Color,

		})
	end

	if next(lines) == nil then
		return nil
	end

	return e("ScreenGui", {

    IgnoreGuiInset = true,
    DisplayOrder = self.props.ZIndex + self.props.ZIndexOffset,

    -- [Roact.Children] = lines,
    [Roact.Children] = {
      Container = self.props.Container({
				[Roact.Children] = lines,
			}),
    },

  })
end

function SubCurve:shouldUpdate(newProps, newState)
  if newProps.FirstIndex ~= self.props.FirstIndex then return true end
  if newProps.LastIndex ~= self.props.LastIndex then return true end
  if newProps.Width ~= self.props.Width then return true end
  if newProps.Color ~= self.props.Color then return true end

  for i=self.props.FirstIndex, self.props.LastIndex do
    if newProps.Points[i] ~= self.props.Points[i] then return true end
    if i < self.props.LastIndex and newProps.Mask[tostring(i)] ~= self.props.Mask[tostring(i)] then return true end
  end

	-- Circle at end of curve is stored in the first subcurve
	if self.props.FirstIndex == 1 then
		if newProps.Points[#newProps.Points] ~= self.props.Points[#self.props.Points] then return true end
    if newProps.Mask[tostring(#newProps.Points-1)] ~= self.props.Mask[tostring(#self.props.Points-1)] then return true end
	end

  return false
end

local Curve = Roact.PureComponent:extend("Curve")

function Curve:render()
  local container = self.props.Container

  local points = self.props.Points
  local elements = {}

  local i = 1
  local n = #points

  while i * SECTION_LENGTH < n do

    elements[i] = e(SubCurve, {

      Points = points,
      FirstIndex = (i-1) * SECTION_LENGTH + (if i == 1 then 1 else 0),
      LastIndex = i * SECTION_LENGTH,
      Width = self.props.Width,
      Color = self.props.Color,
      ZIndex = self.props.ZIndex,
      Mask = self.props.Mask,

      Container = container,
      ZIndexOffset = self.props.ZIndexOffset,

    })

    i += 1
  end

  elements[i] = e(SubCurve, {

    Points = points,
    FirstIndex = (i-1) * SECTION_LENGTH + (if i == 1 then 1 else 0),
    LastIndex = n,
    Width = self.props.Width,
    Color = self.props.Color,
    ZIndex = self.props.ZIndex,
    Mask = self.props.Mask,

    Container = container,
    ZIndexOffset = self.props.ZIndexOffset

  })

  return e("Folder", {}, elements)
end

return Curve