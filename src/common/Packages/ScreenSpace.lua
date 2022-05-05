-- Math by Stravant

local ScreenSpace = {}

function ScreenSpace.ViewSizeX()
	return workspace.CurrentCamera.ViewportSize.X
end

function ScreenSpace.ViewSizeY()
	return workspace.CurrentCamera.ViewportSize.Y
end

function ScreenSpace.AspectRatio()
	return ScreenSpace.ViewSizeX() / ScreenSpace.ViewSizeY()
end

function ScreenSpace.ScreenWidthToWorldWidth(screenWidth, depth)
	local aspectRatio = ScreenSpace.AspectRatio()
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView) / 2)
	local wfactor = aspectRatio*hfactor
	local sx = ScreenSpace.ViewSizeX()

	return -(screenWidth / sx) * 2 * wfactor * depth
end

function ScreenSpace.ScreenHeightToWorldHeight(screenHeight, depth)
	local hfactor = math.tan(math.rad(workspace.CurrentCamera.FieldOfView) / 2)
	local sy = ScreenSpace.ViewSizeY()

	return -(screenHeight / sy) * 2 * hfactor * depth
end

return ScreenSpace