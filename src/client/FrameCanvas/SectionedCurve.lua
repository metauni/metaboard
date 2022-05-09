-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

-- Components
local Line = require(script.Parent.Line)

local SECTION_LENGTH = 50

local SubCurve = Roact.Component:extend("SubCurve")

function SubCurve:render()
	local points = self.props.Points
	local lineMask = self.props.Mask

	local firstIndex = self.props.FirstIndex
  local lastIndex = self.props.LastIndex

	local ithline = function(i)
		return not lineMask[tostring(i)] and e(Line, {
			P0 = points[i],
			P1 = points[i+1],
			Width = self.props.Width,
			Color = self.props.Color,
			ZIndex = 0,
		}) or nil
	end

	local lines = {}
	for i=firstIndex, lastIndex-1 do
		lines[i] = ithline(i)
	end

	return e("ScreenGui", {

    IgnoreGuiInset = true,
    DisplayOrder = self.props.ZIndex + self.props.ZIndexOffset,

    [Roact.Children] = {
      Container = e(self.props.Container, {}, lines),
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