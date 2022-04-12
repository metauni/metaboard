-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Canvas = require(script.Parent)
local Signal = require(Common.Packages.GoodSignal)

-- Helper functions
local makePart = require(script.makePart)
local updateLinePart = require(script.updateLinePart)
local updatePointPart = require(script.updatePointPart)

-- PartCanvas
local PartCanvas = setmetatable({}, Canvas)
PartCanvas.__index = PartCanvas

function PartCanvas.new(board, clickable, name)
	local self = setmetatable(Canvas.new(board), PartCanvas)

	local canvasPart = makePart(name or "Canvas")
	canvasPart.CanQuery = true -- critical for buttons on surface gui
	canvasPart.Transparency = 1
	canvasPart.Size = Vector3.new(board:SurfaceSize().X, board:SurfaceSize().Y, Config.Canvas.CanvasThickness)
	canvasPart.CFrame = board:SurfaceCFrame()

	self._instance = canvasPart
	self._destructor:Add(canvasPart)

	if clickable then
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Adornee = canvasPart
		surfaceGui.Parent = canvasPart

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = canvasPart

		local button = Instance.new("TextButton")
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Parent = surfaceGui

		self._destructor:Add(button.Activated:Connect(function()
			self.ClickedSignal:Fire()
		end))

		self.ClickedSignal = Signal.new()
		self._destructor:Add(function() self.ClickedSignal:DisconnectAll() end)
	end

	return self
end

function PartCanvas:Size()
	return Vector2.new(self._instance.Size.X, self._instance.Size.Y)
end

function PartCanvas:AspectRatio()
	return self:Size().X / self:Size().Y
end

function PartCanvas:GetCFrame()
	return self._instance.CFrame
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

local function makePointPart(index)
	return makePart(pointPartName(index), Enum.PartType.Cylinder)
end


function PartCanvas:NewCurve(groupId: string, curveId: string)
	self:_getCurve(groupId, curveId, true)
end

function PartCanvas:WriteCurve(groupId: string, curveId: string, curve)
	local canvasCurve = self:_getCurve(groupId, curveId, true)

	if #canvasCurve:GetChildren() > 0 then
		canvasCurve:ClearAllChildren()
	end

	if #curve.Points == 1 then
		if curve:IsConnectedAt(1) then
			local pointPart = makePointPart(1)
			updatePointPart(self, pointPart, curve.Points[1], curve)
			pointPart.Parent = canvasCurve
		end

	else
		for i=1, #curve.Points-1 do
			if curve:IsConnectedAt(i) then
				local linePart = makeLinePart(i,i+1)

				local startPointPart = makePointPart(i)
				updatePointPart(self, startPointPart, curve.Points[i], curve)
				startPointPart.Parent = canvasCurve

				local stopPointPart
				if i+1 == #curve.Points or not curve:IsConnectedAt(i+1) then
					stopPointPart = makePointPart(i+1)
					updatePointPart(self, stopPointPart, curve.Points[i+1], curve)
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

	local canvasCurve = self:_getCurve(groupId, curveId, false)

	-- This is the very first point in the curve, so just make a point
	if index == 1 and numPoints == 0 then
		local pointPart = makePointPart(index)
		updatePointPart(self, pointPart, pos, curve)
		pointPart.Parent = canvasCurve
	end

	-- If the point already exists in the curve, update where the pointPart is
	if index <= numPoints then
		local pointPart = canvasCurve:FindFirstChild(pointPartName(index))
		updatePointPart(self, pointPart, pos, curve)

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
		updatePointPart(self, stopPointPart, pos, curve)
		stopPointPart.Parent = canvasCurve
	end
end

function PartCanvas:AddSubCurve(groupId: string, curveId: string, curve, lineStartIndices)
	local canvasCurve = self:_getCurve(groupId, curveId)

	for _, startIndex in ipairs(lineStartIndices) do

		-- Check if the the previous point is not connected to this one, in which case
		-- the pointPart at startIndex needs to be added
		if startIndex == 1 or not curve:IsConnectedAt(startIndex - 1) then
			local startPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex))
			if startPointPart then
				startPointPart:Destroy()
			end
		end

		-- Check if the the next point is not connected to the one after it, in which case
		-- the pointPart at startIndex+1 needs to be added
		if startIndex+1 == #curve.Points or not curve:IsConnectedAt(startIndex + 1) then
			local stopPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex + 1))
			if stopPointPart then
				stopPointPart:Destroy()
			end
		end

		local linePart = makeLinePart(startIndex, startIndex + 1)
		updateLinePart(self, linePart, curve:LineBetween(curve.Points[startIndex], curve.Points[startIndex + 1]))
		linePart.Parent = canvasCurve
	end
end

function PartCanvas:SubtractSubCurve(groupId: string, curveId: string, curve, lineStartIndices)
	local group = self:_findGroup(groupId)
	if group == nil then
		return
	end

	local canvasCurve = self:_findCurve(groupId, curveId)
	if canvasCurve == nil then
		return
	end

	for _, startIndex in ipairs(lineStartIndices) do

		-- Check if the the previous point is not connected to this one, in which case
		-- the pointPart at startIndex should disappear
		if startIndex == 1 or not curve:IsConnectedAt(startIndex - 1) then
			local startPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex))
			if startPointPart then
				startPointPart:Destroy()
			end
		end

		-- Check if the the next point is not connected to the one after it, in which case
		-- the pointPart at startIndex+1 should disappear
		if startIndex+1 == #curve.Points or not curve:IsConnectedAt(startIndex + 1) then
			local stopPointPart = canvasCurve:FindFirstChild(pointPartName(startIndex + 1))
			if stopPointPart then
				stopPointPart:Destroy()
			end
		end

		-- Delete the line
		local linePart = canvasCurve:FindFirstChild(startIndex)
		if linePart then
			linePart:Destroy()
		end
	end
end


function PartCanvas:DeleteCurve(groupId: string, curveId: string)
	local canvasCurve = self:_getCurve(groupId, curveId, false)

	canvasCurve:Destroy()
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

function PartCanvas:_getCurve(groupId: string, curveId: string, createIfMissing: boolean)
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
