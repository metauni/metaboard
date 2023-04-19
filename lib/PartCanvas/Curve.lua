-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent
local Config = require(root.Config)
local Feather = require(root.Parent.Feather)

local e = Feather.createElement

local function lerp(a, b, t)
	if t < 0.5 then
		return a + (b - a) * t
	else
		return b - (b - a) * (1 - t)
	end
end

local partInitProps = {
	
	Material = Enum.Material.SmoothPlastic,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Anchored = true,
	CanCollide = false,
	CastShadow = false ,
	CanTouch = false, -- Do not trigger Touch events
	CanQuery = false, -- Does not take part in e.g. GetPartsInPart
}

local function circle(props)

	local point, color, width, zIndex, canvasSize, canvasCFrame = unpack(props)

	local aspectRatio = canvasSize.X / canvasSize.Y

	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, point.X / aspectRatio)
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, point.Y)
	local z =
		- Config.SurfaceCanvas.ZThicknessStuds / 2
		- Config.SurfaceCanvas.InitialZOffsetStuds
		- zIndex * Config.SurfaceCanvas.StudsPerZIndex

	return e("Part", {

		Shape = Enum.PartType.Cylinder,
		
		Size = Vector3.new(
			0.0001,
			width * canvasSize.Y,
			width * canvasSize.Y
		),
	
		CFrame = canvasCFrame * CFrame.new(x,y,z) * CFrame.Angles(0,math.pi/2,0),
		
		Color = color,

		[Feather.HostInitProps] = partInitProps,
	})
end

local function line(props)

	local p0, p1, roundedP0, roundedP1, color, width, zIndex, canvasSize, canvasCFrame = unpack(props)

	local aspectRatio = canvasSize.X / canvasSize.Y

	local length = (p0 - p1).Magnitude
	local centre = (p0 + p1)/2
	local rotation = math.atan2((p0 - p1).Y, (p0 - p1).X)

	-- Position of the centre of the line relative to the surface of the board
	local x = lerp(canvasSize.X / 2, -canvasSize.X / 2, centre.X / aspectRatio)
	local y = lerp(canvasSize.Y / 2, -canvasSize.Y / 2, centre.Y)
	local z =
		- Config.SurfaceCanvas.ZThicknessStuds / 2
		- Config.SurfaceCanvas.InitialZOffsetStuds
		- zIndex * Config.SurfaceCanvas.StudsPerZIndex

	local firstCircle = roundedP0 and circle({p0, color, width, zIndex, canvasSize, canvasCFrame}) or nil
	local secondCircle = roundedP1 and circle({p1, color, width, zIndex, canvasSize, canvasCFrame}) or nil
	
	if not firstCircle then
		
		firstCircle = secondCircle
		secondCircle = nil
	end

	return e("Part", {

		Shape = Enum.PartType.Block,

		Size = Vector3.new(
			length * canvasSize.Y,
			width * canvasSize.Y,
			Config.SurfaceCanvas.ZThicknessStuds
		),

		CFrame = canvasCFrame * CFrame.new(x,y,z) * CFrame.Angles(0, 0, rotation),
		
		Color = color,

		[Feather.Children] = (roundedP0 or roundedP1) and {firstCircle, secondCircle} or nil,

		[Feather.HostInitProps] = partInitProps,
	})
end

local function extend(u: Vector2, v: Vector2, width: number)

	local sinTheta = math.clamp(math.abs(u.Unit:Cross(v.Unit)), 0, 1)
	local cosTheta = math.clamp(u.Unit:Dot(v.Unit), -1, 1)

	-- Check that sin(theta) is non zero and that both sin(theta) and
	-- cos(theta) are not NaN.
	if sinTheta > 0 and cosTheta == cosTheta then
		return math.clamp(width/2 * (1 + cosTheta) / sinTheta, 0, width/2)
	end

	return 0
end

local function curveLine(i, curve, mask, canvasCFrame, canvasSize)

	local points = curve.Points

	local a, b, c, d = points[i-1], points[i], points[i+1], points[i+2]
	local mab = mask and mask[tostring(i-1)]
	local mbc = mask and mask[tostring(i)]
	local mcd = mask and mask[tostring(i+1)]

	--        (a)            (d)
	--         \             / 
	--          \          /
	--           (b)-----(c)
	--
	-- We are drawing ^ this line from b to c.
	-- mab, mbc, mcd are true iff the respective line is masked (erased)
	-- or non-existent (if i==1 or i+1==#points)

	if mbc then
		return nil
	end

	-- Draw zero-length lines as circles

	if b == c then

		return circle({

			b,
			curve.Color,
			curve.Width,
			curve.ZIndex,
			canvasSize,
			canvasCFrame,
		})
	end
	
	-- Since lines have thickness (they are rectangles) and cause triangular
	-- gaps where they join, which are visible as "spiky" artifacts.
	-- We fix this for obtuse angles by extending the lines to meet at a corner,
	-- and for acute angles by adding a circle.
	-- The former case is more probable, and thus the Instance
	-- count is much lower than if a circle is placed at every joint
	
	-- Place a circle at b/c? (circle at b might still be added below)
	local bCircle = i == 1 or mab
	local cCircle = mcd
	
	-- shifted versions of b and c along the line bc
	local bShift, cShift = b, c
	
	-- If the line bc is preceeded by ab (visible and +ve length),
	-- and the angle abc is not-acute, then extend the line bc towards b
	-- enough to close the gap on the exterior side

	if i > 1 and not mab and a ~= b then

		local u = a - b
		local v = c - b

		if u:Dot(v) <= 0 then

			bShift = b + extend(u, v, curve.Width) * (b - c).Unit
		else

			bCircle = true
		end
	end

	-- If the line bc is preceeded by ab (visible and +ve length),
	-- and the angle abc is not acute, then extend the line bc towards b
	-- enough to close the gap on the exterior side

	if i+1 < #points and not mbc and c ~= d then

		local u = b - c
		local v = d - c

		if u:Dot(v) <= 0 then
			
			cShift = c + extend(u, v, curve.Width) * (c - b).Unit
		end

		-- No "else roundedP1 = true" because this would double up on circles
	end

	return line({

		bShift,
		cShift,
		bCircle,
		cCircle,
		curve.Color,
		curve.Width,
		curve.ZIndex,
		canvasSize,
		canvasCFrame,
	})
end

return function(props, oldProps)

	if 
		-- Note that the curve contains a mask and is treated immutably, so changes to that
		-- mask will make this false (which is a good thing!)
		oldProps.Curve == props.Curve 
		and 
		oldProps.CanvasSize == props.CanvasSize
		and 
		oldProps.CanvasCFrame == props.CanvasCFrame then

		if oldProps.Masks == props.Masks then
			
			return e("Folder", {})
		end
		
		local unchanged = true
		
		if oldProps.Masks then
			
			for key, mask in oldProps.Masks do
				
				if not props.Masks or mask ~= props.Masks[key] then
					
					unchanged = false
					break
				end
			end
		end
	
		if unchanged and props.Masks then
			
			for key, mask in props.Masks do
				
				if not oldProps.Masks or mask ~= oldProps.Masks[key] then
					
					unchanged = false
					break
				end
			end
		end

		if unchanged then
			
			return e("Folder", {})
		end
	end

	-- The curve or canvas changed, or some mask changed.

	local deltaChildren = {}

	local maxPoints = oldProps.Curve and math.max(#oldProps.Curve.Points, #props.Curve.Points) or #props.Curve.Points

	-- Construct the current merged mask

	local mergedMask = props.Curve.Mask

	if props.Masks then

		mergedMask = mergedMask and table.clone(mergedMask) or {}
		
		for _, mask in props.Masks do
			
			for iStr in pairs(mask) do
				
				mergedMask[iStr] = true
			end
		end
	end
	
	-- Construct the old merged mask

	local oldMergedMask = oldProps.Curve and oldProps.Curve.Mask or nil

	if oldProps.Masks then

		oldMergedMask = oldMergedMask and table.clone(oldMergedMask) or {}
		
		for _, mask in oldProps.Masks do
			
			for iStr in pairs(mask) do
				
				oldMergedMask[iStr] = true
			end
		end
	end

	-- Check if whole curve needs to be updated

	local changeAll =
		oldProps.Curve == nil -- first time
		or
		oldProps.Curve.ZIndex ~= props.Curve.ZIndex
		or
		oldProps.Curve.Width ~= props.Curve.Width
		or
		oldProps.Curve.Color ~= props.Curve.Color
		or
		oldProps.CanvasCFrame ~= props.CanvasCFrame
		or
		oldProps.CanvasSize ~= props.CanvasSize

	for i=1, maxPoints-1 do

		if
			changeAll
			or
			-- Update if this line (or neighbours) has a different "masked" status since the last render
			(oldMergedMask and oldMergedMask[tostring(i+1)] or nil) ~= (mergedMask and mergedMask[tostring(i+1)] or nil)
			or
			(oldMergedMask and oldMergedMask[tostring(i)] or nil) ~= (mergedMask and mergedMask[tostring(i)] or nil)
			or
			(oldMergedMask and oldMergedMask[tostring(i-1)] or nil) ~= (mergedMask and mergedMask[tostring(i-1)] or nil)
			or
			oldProps.Curve.Points[i+2] ~= props.Curve.Points[i+2]
			or
			oldProps.Curve.Points[i+1] ~= props.Curve.Points[i+1]
			or
			oldProps.Curve.Points[i] ~= props.Curve.Points[i]
			or
			oldProps.Curve.Points[i-1] ~= props.Curve.Points[i-1] then

			if not (mergedMask and mergedMask[tostring(i)]) and i+1 <= #props.Curve.Points then
				
				deltaChildren[tostring(i)] = curveLine(i, props.Curve, mergedMask, props.CanvasCFrame, props.CanvasSize)

				if i==#props.Curve.Points-1 then
					
					deltaChildren["CurveEndCircle"] = circle({

						props.Curve.Points[#props.Curve.Points],
						props.Curve.Color,
						props.Curve.Width,
						props.Curve.ZIndex,
						props.CanvasSize,
						props.CanvasCFrame,
					})
				end
			
			-- Subtract if there was a previously rendered curve and this line was visible
			elseif oldProps.Curve and not (oldMergedMask and oldMergedMask[tostring(i)]) and i+1 <= #oldProps.Curve.Points then
			
				deltaChildren[tostring(i)] = Feather.SubtractChild

				if i==#props.Curve.Points-1 then
					
					deltaChildren["CurveEndCircle"] = Feather.SubtractChild
				end
			end
		end
	end

	return e("Folder", {

		[Feather.DeltaChildren] = deltaChildren,
	})
end