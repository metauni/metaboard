-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

--!strict

-- Imports
local root = script.Parent
local Config = require(root.Config)
local Collision = require(root.Collision)
local Sift = require(root.Parent.Sift)
local Dictionary = Sift.Dictionary

-- Figure Types

export type AnyFigure = Line | Curve

export type Line = {
	Type: "Line",
	P0: Vector2,
	P1: Vector2,
	Width: number,
	Color: Color3,
	ZIndex: number,
}

export type Curve = {
	Type: "Curve",
	Points: {Vector2},
	Width: number,
	Color: number,
	ZIndex: number,
}

-- Figure Masks

export type AnyMask = LineMask| CurveMask

export type LineMask = boolean
export type CurveMask = {boolean}

local function serialiseVector2(vector: Vector2)
	return { X = vector.X, Y = vector.Y }
end

local function deserialiseVector2(vData: { X: number, Y: number })
	return Vector2.new(vData.X, vData.Y)
end

local function serialiseColor3(color: Color3)
	return { R = color.R, G = color.G, B = color.B }
end

local function deserialiseColor3(cData: { R: number, G: number, B: number })
	return Color3.new(cData.R, cData.G, cData.B)
end

local serialisers

serialisers = {

	Line = function(line: Line)
		return {
			Type = "Line",
			P0 = serialiseVector2(line.P0),
			P1 = serialiseVector2(line.P1),
			Width = line.Width,
			Color = serialiseColor3(line.Color),
			ZIndex = line.ZIndex,
			Mask = line.Mask,
		}
	end,

	Curve = function(curve: Curve)
		local serialisedPoints = table.create(#curve.Points)

		for i, point in ipairs(curve.Points) do
			serialisedPoints[i] = serialiseVector2(point)
		end

		return {
			Type = "Curve",
			Points = serialisedPoints,
			Width = curve.Width,
			Color = serialiseColor3(curve.Color),
			ZIndex = curve.ZIndex,
			Mask = curve.Mask,
		}
	end,

}

local deserialisers = {

	Curve = function(curveData)

		local deserialisedPoints = table.create(#curveData.Points)

		for i, pointData in ipairs(curveData.Points) do
			deserialisedPoints[i] = deserialiseVector2(pointData)
		end

		return {
			Type = "Curve",
			Points = deserialisedPoints,
			Width = curveData.Width,
			Color = deserialiseColor3(curveData.Color),
			ZIndex = curveData.ZIndex,
			Mask = curveData.Mask,
		}
	end,

	Line = function(lineData)
		return {
			Type = "Line",
			P0 = deserialiseVector2(lineData.P0),
			P1 = deserialiseVector2(lineData.P1),
			Width = lineData.Width,
			Color = deserialiseColor3(lineData.Color),
			ZIndex = lineData.ZIndex,
			Mask = lineData.Mask,
		}
	end,

}

local maskMergers = {

	Curve = function(curveMask, ...)
		return Dictionary.merge(curveMask or {}, ...)
	end,

	Line = function(...)
		for _, value in ipairs({...}) do
			if value then
				return true
			end
		end

		return false
	end,

}

local intersectsCircle = {

	Curve = function(centre, radius, curve, maybeTouchedMask)

		for i in pairs(maybeTouchedMask) do
			if Collision.CircleLine(centre, radius, curve.Points[tonumber(i)], curve.Points[tonumber(i+1)], curve.Width) then
				return true
			end
		end

		return false

	end,

	Line = function(centre, radius, line, maybeTouchedMask)
		return maybeTouchedMask and Collision.CircleLine(centre, radius, line.P0, line.P1, line.Width)
	end,

}

return {

	Serialise = function(figure: AnyFigure)
		return serialisers[figure.Type](figure)
	end,

	Deserialise = function(figureData)
		return deserialisers[figureData.Type](figureData)
	end,

	MergeMask = function(figureType: "Curve" | "Line" | "Circle", mask, ...)
		return maskMergers[figureType](mask, ...)
	end,

	FullyMasked = function(figure)
		if figure.Type == "Curve" then

			if figure.Mask == nil then
				return false
			end

			for i=1, #figure.Points-1 do
				if figure.Mask[tostring(i)] == nil then
					return false
				end
			end

			return true

		else

			return figure.Mask == true

		end
	end,

	IntersectsCircle = function(centre, radius, figureType: "Curve" | "Line" | "Circle", figure: AnyFigure, maybeTouchedMask)
		return intersectsCircle[figureType](centre, radius, figure, maybeTouchedMask)
	end,

}