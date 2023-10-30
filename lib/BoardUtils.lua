-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent
local Rx = require(root.Util.Rx)
local Rxi = require(root.Util.Rxi)
local GoodSignal = require(root.Util.GoodSignal)

--[[
	Utilities functions for metaboards
]]
local BoardUtils = {}

-- Orientation of the face CFrame
local FACE_ANGLE_CFRAME = {
	Front  = CFrame.Angles(0, 0, 0),
	Left   = CFrame.Angles(0, math.pi / 2, 0),
	Back   = CFrame.Angles(0, math.pi, 0),
	Right  = CFrame.Angles(0, -math.pi / 2, 0),
	Top    = CFrame.Angles(math.pi / 2, 0, 0),
	Bottom = CFrame.Angles(-math.pi / 2, 0, 0)
}

-- The width, height and normal axes to the face
local FACE_AXES = {
	Front  = {"X", "Y", "Z"},
	Left   = {"Z", "Y", "X"},
	Back   = {"X", "Y", "Z"},
	Right  = {"Z", "Y", "X"},
	Top    = {"X", "Z", "Y"},
	Bottom = {"X", "Z", "Y"},
}

function BoardUtils.getSurfaceSizeFromPart(part: Part)
	local faceValue = part:FindFirstChild("Face")
	local face = faceValue and faceValue.Value or "Front"
	local faceAxes = FACE_AXES[face]
	return Vector2.new(part.Size[faceAxes[1]] :: number, part.Size[faceAxes[2]] :: number)
end

function BoardUtils.getSurfaceCFrameFromPart(part: Part)
	local faceValue = part:FindFirstChild("Face")
	local face = faceValue and faceValue.Value or "Front"
	local faceAxes = FACE_AXES[face]
	local faceAngleCFrame = FACE_ANGLE_CFRAME[face]
	return part.CFrame
		* faceAngleCFrame
		* CFrame.new(0, 0, -(part.Size[faceAxes[3]] :: number)/2)
end

function BoardUtils.getAspectRatioFromPart(part: Part)
	local size = BoardUtils.getSurfaceSizeFromPart(part)
	return size.X/size.Y
end

function BoardUtils.observeSurfaceSize(part: Part)
	return Rxi.propertyOf(part, "Size"):Pipe({
		Rx.map(function()
			return BoardUtils.getSurfaceSizeFromPart(part)
		end)
	})
end

function BoardUtils.observeSurfaceCFrame(part: Part)
	return Rxi.propertyOf(part, "CFrame"):Pipe({
		Rx.map(function()
			return BoardUtils.getSurfaceCFrameFromPart(part)
		end)
	})
end

return BoardUtils