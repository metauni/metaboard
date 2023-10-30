-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local root = script.Parent.Parent
local Rx = require(script.Parent.Parent.Util.Rx)
local Blend = require(root.Util.Blend)

return function(props)

	return Blend.New "Part" {
		Name = "BoardButton",
		Archivable = false, -- Prevent copying
		Transparency = 1,
		CanQuery = true,
		Anchored = true,
		CanCollide = false,
		CastShadow = false,

		CFrame = props.SurfaceCFrame,
		Size = Blend.Computed(props.SurfaceSize, function(surfaceSize: Vector2)
			return Vector3.new(surfaceSize.X, surfaceSize.Y, 3)
		end),

		Blend.New "ClickDetector" {
			MaxActivationDistance = Blend.Computed(props.Active, function(active)
				return active and math.huge or 0
			end)
		},

		Blend.New "SurfaceGui" {
			[Blend.Instance] = function(surfaceGui)
				surfaceGui.Adornee = surfaceGui.Parent
			end,
			
			Blend.New "TextButton" {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0,0),
				Size = UDim2.fromScale(1,1),
				
				[Blend.OnEvent "Activated"] = props.OnClick,
			}
		}
	}
end