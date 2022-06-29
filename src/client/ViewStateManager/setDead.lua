-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local SurfaceCanvas = require(script.Parent.SurfaceCanvas)
local extractHostObject = require(script.Parent.extractHostObject)

return function(board, viewData, canvasTarget)
	viewData = viewData or {}

	if viewData.Status ~= "Dead" then

		if viewData.Destroy then
			viewData.Destroy()
		end

		board:SetTransparency(0.75)

		return {
			Status = "Dead",
			Destroy = function()
				board:SetTransparency(0)
			end
		}

	end

	return viewData
end