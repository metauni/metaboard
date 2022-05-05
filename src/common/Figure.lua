--!strict

-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary

-- Figure Types

export type AnyFigure = Line | Curve | Circle | Group

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

export type Circle = {
	Type: "Circle",
	Centre: Vector2,
	Radius: number,
	Color: Color3,
	ZIndex: number,
}

export type Group = {[string]: AnyFigure}

-- Figure Masks

export type AnyMask = LineMask| CurveMask | CircleMask | GroupMask

export type LineMask = boolean
export type CurveMask = {LineMask}
export type CircleMask = boolean
export type GroupMask = {[string] : AnyMask }

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
			ZIndex = line.ZIndex
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
			ZIndex = curve.ZIndex
		}
	end,

	Circle = function(circle: Circle)
		return {
			Type = "Circle",
			Centre = serialiseVector2(circle.Centre),
			Radius = circle.Radius,
			Color = serialiseColor3(circle.Color),
			ZIndex = circle.ZIndex
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
			ZIndex = curveData.ZIndex
		}
	end,

	Line = function(lineData)
		return {
			Type = "Line",
			P0 = deserialiseVector2(lineData.P0),
			P1 = deserialiseVector2(lineData.P1),
			Width = lineData.Width,
			Color = deserialiseColor3(lineData.Color),
			ZIndex = lineData.ZIndex
		}
	end,

	Circle = function(circleData)
		return {
			Type = "Circle",
			Centre = serialiseVector2(circleData.Centre),
			Radius = circleData.Radius,
			Color = serialiseColor3(circleData.Color),
			ZIndex = circleData.ZIndex
		}
	end,

}

local mergeBool = function(...)
	for _, value in ipairs({...}) do
		if value then
			return true
		end
	end

	return false
end

local maskMergers = {

	Curve = function(curveMask, ...)
		return Dictionary.merge(curveMask, ...)
	end,

	Line = mergeBool,

	Circle = mergeBool,

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
	end
	
}