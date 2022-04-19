-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Canvas = require(script.Parent)
local Signal = require(Common.Packages.GoodSignal)
local Line = require(Common.Figure.Line)

-- Helper functions
local makePart = require(script.makePart)
local updateLinePart = require(script.updateLinePart)
local updatePointPart = require(script.updatePointPart)

-- PartCanvas
local PartCanvas = setmetatable({}, Canvas)
PartCanvas.__index = PartCanvas

function PartCanvas.new(name, boardSurface: Part)
	local self = setmetatable(Canvas.new(), PartCanvas)

	self._boardSurface = boardSurface

	self._instance = Instance.new("Model")
	self._instance.Name = name or "Canvas"

	self._destructor:Add(self._instance)

	return self
end

function PartCanvas:ParentTo(parent)
	self._instance.Parent = parent
end

function PartCanvas:Size()
	return Vector2.new(self._boardSurface.Size.X, self._boardSurface.Size.Y)
end

function PartCanvas:AspectRatio()
	return self:Size().X / self:Size().Y
end

function PartCanvas:GetCFrame()
	return self._boardSurface.CFrame
end

local function linePartName(startIndex, stopIndex)
	return tostring(startIndex).."L"..tostring(stopIndex)
end

local function pointPartName(index)
	return "P"..tostring(index)
end

local function makeLinePart(startIndex, stopIndex)
	return makePart(linePartName(startIndex, stopIndex), Enum.PartType.Block)
end

local function makePointPart(id)
	return makePart(pointPartName(id), Enum.PartType.Cylinder)
end

function PartCanvas:WriteCircle(groupId: string, figureId: string, pos: Vector2, thicknessYScale: number, color, zIndex: number)
	local canvasFigure = self:_getFigure(groupId, figureId, true)

	if #canvasFigure:GetChildren() > 0 then
		canvasFigure:ClearAllChildren()
	end

	local circle = makePointPart(figureId)
	updatePointPart(self, circle, pos, thicknessYScale, color, zIndex)
	circle.Parent = canvasFigure
end

function PartCanvas:DeleteGroup(groupId: string)
	local group = self:_getGroup(groupId, false)
	group:Destroy()
end

function PartCanvas:DeleteFigure(groupId: string, figureId: string)
	local canvasFigure = self:_getFigure(groupId, figureId, false)
	canvasFigure:Destroy()
end

function PartCanvas:NewCurve(groupId: string, curveId: string)
	self:_getFigure(groupId, curveId, true)
end

function PartCanvas:WriteCurve(groupId: string, curveId: string, curve)
	local canvasCurve = self:_getFigure(groupId, curveId, true)

	if #canvasCurve:GetChildren() > 0 then
		canvasCurve:ClearAllChildren()
	end

	if #curve.Points == 1 then
		if curve:IsConnectedAt(1) then
			local pointPart = makePointPart(1)
			updatePointPart(self, pointPart, curve.Points[1], curve.ThicknessYScale, curve.Color, curve.ZIndex)
			pointPart.Parent = canvasCurve
		end

	else
		for i=1, #curve.Points-1 do
			if curve:IsConnectedAt(i) then
				local linePart = makeLinePart(i,i+1)

				local startPointPart = makePointPart(i)
				updatePointPart(self, startPointPart, curve.Points[i], curve.ThicknessYScale, curve.Color, curve.ZIndex)
				startPointPart.Parent = canvasCurve

				local stopPointPart
				if i+1 == #curve.Points or not curve:IsConnectedAt(i+1) then
					stopPointPart = makePointPart(i+1)
					updatePointPart(self, stopPointPart, curve.Points[i+1], curve.ThicknessYScale, curve.Color, curve.ZIndex)
					stopPointPart.Parent = canvasCurve
				end

				updateLinePart(self, linePart, curve:LineBetween(curve.Points[i], curve.Points[i+1]))
				linePart.Parent = canvasCurve
			end
		end
	end
end

-- Update an existing curve, either by repositioning an existing point,
-- or extending it by one point.
-- curve: The un-updated curve
-- index: The index of the point to update in the curve
-- pos: The new position of the point at that index
-- The index should be between 1 and #curve.Points + 1
-- Assumes that the curve is completely connected
function PartCanvas:UpdateCurvePoint(groupId, curveId, curve, index, pos)
	local numPoints = #curve.Points
	assert(index <= numPoints + 1)

	local canvasCurve = self:_getFigure(groupId, curveId, false)

	-- This is the very first point in the curve, so just make a point
	if index == 1 and numPoints == 0 then
		local pointPart = makePointPart(index)
		updatePointPart(self, pointPart, pos, curve.ThicknessYScale, curve.Color, curve.ZIndex)
		pointPart.Parent = canvasCurve
	end

	-- If the point already exists in the curve, update where the pointPart is
	if index <= numPoints then
		local pointPart = canvasCurve:FindFirstChild(pointPartName(index))
		updatePointPart(self, pointPart, pos, curve.ThicknessYScale, curve.Color, curve.ZIndex)

		-- Update the line before the point
		if index > 1 then
			local lineBefore = canvasCurve:FindFirstChild(linePartName(index-1,index))
			if lineBefore then
				updateLinePart(self, lineBefore, curve:LineBetween(curve.Points[index-1], pos))
			end
		end

		-- Update the line after the point
		if index < numPoints then
			local lineAfter = canvasCurve:FindFirstChild(tostring(index).."L"..tostring(index+1))
			if lineAfter then
				updateLinePart(self, lineAfter, curve:LineBetween(pos, curve.Points[index+1]))
			end
		end

	elseif index > 1 then

		-- We are extending an existing (non-empty) curve with a new point
		-- add the new linePart and pointPart
		local linePart = makeLinePart(numPoints, numPoints+1)
		updateLinePart(self, linePart, curve:LineBetween(curve.Points[numPoints], pos))
		linePart.Parent = canvasCurve

		local stopPointPart = makePointPart(numPoints+1)
		updatePointPart(self, stopPointPart, pos, curve.ThicknessYScale, curve.Color, curve.ZIndex)
		stopPointPart.Parent = canvasCurve
	end
end

function PartCanvas:DeleteLineInCurve(groupId: string, figureId: string, curve, lineStartIndex: number)
	local canvasCurve = self:_getFigure(groupId, figureId, false)

	-- Check if the the previous point is not connected to this one, in which case
	-- the pointPart at startIndex should disappear
	if lineStartIndex == 1 or not curve:IsConnectedAt(lineStartIndex - 1) then
		local startPointPart = canvasCurve:FindFirstChild(pointPartName(lineStartIndex))
		startPointPart:Destroy()
	end

	-- Check if the the next point is not connected to the one after it, in which case
	-- the pointPart at lineStartIndex+1 should disappear
	if lineStartIndex+1 == #curve.Points or not curve:IsConnectedAt(lineStartIndex + 1) then
		local stopPointPart = canvasCurve:FindFirstChild(pointPartName(lineStartIndex + 1))
		stopPointPart:Destroy()
	end

	-- Delete the line
	local linePart = canvasCurve:FindFirstChild(linePartName(lineStartIndex, lineStartIndex+1))
	linePart:Destroy()
end

function PartCanvas:ShowLineInCurve(groupId: string, figureId: string, curve, lineStartIndex: number)
	local canvasCurve = self:_getFigure(groupId, figureId, true)

	local startPointPart = makePointPart(lineStartIndex)
	updatePointPart(self, startPointPart, curve.Points[lineStartIndex], curve.ThicknessYScale, curve.Color, curve.ZIndex)
	startPointPart.Parent = canvasCurve

	local stopPointPart = makePointPart(lineStartIndex)
	updatePointPart(self, stopPointPart, curve.Points[lineStartIndex+1], curve.ThicknessYScale, curve.Color, curve.ZIndex)
	stopPointPart.Parent = canvasCurve

	local linePart = makeLinePart(lineStartIndex, lineStartIndex+1)
	updateLinePart(self, linePart, curve:LineBetween(curve.Points[lineStartIndex], curve.Points[lineStartIndex+1]))
	linePart.Parent = canvasCurve
end

-- function PartCanvas:AddSubCurve(groupId: string, curveId: string, curve, lineStartIndices)
-- 	local canvasCurve = self:_getFigure(groupId, curveId)

-- 	for _, startIndex in ipairs(lineStartIndices) do

-- 		-- Check if the the previous point is not connected to this one, in which case
-- 		-- the pointPart at startIndex needs to be added
-- 		if startIndex == 1 or not curve:IsConnectedAt(startIndex - 1) then
-- 			local startPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex))
-- 			if startPointPart then
-- 				startPointPart:Destroy()
-- 			end
-- 		end

-- 		-- Check if the the next point is not connected to the one after it, in which case
-- 		-- the pointPart at startIndex+1 needs to be added
-- 		if startIndex+1 == #curve.Points or not curve:IsConnectedAt(startIndex + 1) then
-- 			local stopPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex + 1))
-- 			if stopPointPart then
-- 				stopPointPart:Destroy()
-- 			end
-- 		end

-- 		local linePart = makeLinePart(startIndex, startIndex + 1)
-- 		updateLinePart(self, linePart, curve:LineBetween(curve.Points[startIndex], curve.Points[startIndex + 1]))
-- 		linePart.Parent = canvasCurve
-- 	end
-- end

-- function PartCanvas:SubtractSubCurve(groupId: string, curveId: string, curve, lineStartIndices)
-- 	local group = self:_findGroup(groupId)
-- 	if group == nil then
-- 		return
-- 	end

-- 	local canvasCurve = self:_findCurve(groupId, curveId)
-- 	if canvasCurve == nil then
-- 		return
-- 	end

-- 	for _, startIndex in ipairs(lineStartIndices) do

-- 		-- Check if the the previous point is not connected to this one, in which case
-- 		-- the pointPart at startIndex should disappear
-- 		if startIndex == 1 or not curve:IsConnectedAt(startIndex - 1) then
-- 			local startPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex))
-- 			if startPointPart then
-- 				startPointPart:Destroy()
-- 			end
-- 		end

-- 		-- Check if the the next point is not connected to the one after it, in which case
-- 		-- the pointPart at startIndex+1 should disappear
-- 		if startIndex+1 == #curve.Points or not curve:IsConnectedAt(startIndex + 1) then
-- 			local stopPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex + 1))
-- 			if stopPointPart then
-- 				stopPointPart:Destroy()
-- 			end
-- 		end

-- 		-- Delete the line
-- 		local linePart = canvasCurve:FindFirstChild(startIndex)
-- 		if linePart then
-- 			linePart:Destroy()
-- 		end
-- 	end
-- end

function PartCanvas:Clear()
	self._groupFolder:ClearAllChildren()
end

function PartCanvas:Destroy()
	self._destructor:Destroy()
end

-- Lookup functions

local function curveNotFoundError(curveId: string)
	error("Canvas: could not find curve with ID " .. curveId)
end

local function groupNotFoundError(groupId: string)
	error("Canvas: could not find curve with groupId " .. groupId)
end

local function makeGroup(groupId: string)
	local group = Instance.new("Folder")
	group.Name = groupId
	return group
end

local function makeCanvasCurve(curveId: string)
	local canvasCurve = Instance.new("Folder")
	canvasCurve.Name = curveId
	return canvasCurve
end

function PartCanvas:_getGroup(groupId: string, createIfMissing: boolean)
	local group = self._instance:FindFirstChild(groupId)
	if group == nil then
		if createIfMissing then
			group = makeGroup(groupId)
			group.Parent = self._instance
		else
			groupNotFoundError(groupId)
		end
	end

	return group
end

function PartCanvas:_getFigure(groupId: string, curveId: string, createIfMissing: boolean)
	if curveId == nil then
		return self:_getGroup(groupId, createIfMissing)
	else
		local group = self:_getGroup(groupId, createIfMissing)

		local canvasCurve = group:FindFirstChild(curveId)
		if canvasCurve == nil then
			if createIfMissing then
				canvasCurve = makeCanvasCurve(curveId)
				canvasCurve.Parent = group
			else
				curveNotFoundError(curveId)
			end
		end

		return canvasCurve
	end
end



return PartCanvas
