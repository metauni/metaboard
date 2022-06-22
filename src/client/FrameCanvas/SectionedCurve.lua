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
			return false
		end

		if b == c then

			return Circle({

				Position = b,
				Width = self.props.Width,
				Color = self.props.Color,

			})
		end

		local roundedP0 = i == 1 or mab
		local roundedP1 = i+1 == #points or mcd
		-- roundedP1 = true

		local p0Extend, p1Extend = 0, 0

		if i > 1 and not mab and a ~= b then
			local u = a - b
			local v = c - b

			if u:Dot(v) <= 0 then

				local sinTheta = math.abs(u.Unit:Cross(v.Unit))
				local cosTheta = u.Unit:Dot(v.Unit)

				-- Check that sin(theta) is non zero and that both sin(theta) and
				-- cos(theta) are not NaN.
				if sinTheta > 0 and cosTheta == cosTheta then
					p0Extend = self.props.Width/2 * (1 + cosTheta) / sinTheta
				end
			else
				roundedP0 = true
			end
		end

		if i+1 < #points and not mbc and c ~= d then
			local u = b - c
			local v = d - c

			if u:Dot(v) <= 0 then
				local sinTheta = math.abs(u.Unit:Cross(v.Unit))
				local cosTheta = u.Unit:Dot(v.Unit)

				-- Check that sin(theta) is non zero and that both sin(theta) and
				-- cos(theta) are not NaN.
				if sinTheta > 0 and cosTheta == cosTheta then
					p1Extend = self.props.Width/2 * (1 + cosTheta) / sinTheta
				end
			end
			-- No "else roundedP1 = true" because this would double up"
		end
    
    -- local rounded = roundedP0 or roundedP1
    local rounded = true

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
		lines[i] = ithline(i)
	end

	return e("ScreenGui", {

    IgnoreGuiInset = true,
    DisplayOrder = self.props.ZIndex + self.props.ZIndexOffset,

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