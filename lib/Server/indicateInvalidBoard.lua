-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

return function (board, message)

	local Part = Instance.new("Part")
	Part.Name = "BoardInvalidIndicator"
	Part.Size = Vector3.new(board.SurfaceSize.X, board.SurfaceSize.Y, 0.01)
	Part.CFrame = board.SurfaceCFrame + board.SurfaceCFrame.LookVector * Part.Size.Z/2
	Part.Transparency = 1
	Part.Anchored = true
	Part.CanCollide = false
	Part.CastShadow = false
	Part.CanTouch = false
	Part.CanQuery = true

	local SurfaceGui = Instance.new("SurfaceGui")
	SurfaceGui.Parent = Part
	SurfaceGui.Adornee = Part

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Parent = SurfaceGui

	TextLabel.AnchorPoint = Vector2.new(0.5,0.5)
	TextLabel.Position = UDim2.fromScale(0.5,0.5)
	TextLabel.Size = UDim2.fromScale(0.75, 0.75)

	TextLabel.Text = "Failed to Load Board from DataStore for "..board:FullName().."\n"..message
	TextLabel.TextScaled = true

	TextLabel.BackgroundColor3 = Color3.new(1,0,0)

	Part.Parent = workspace
end