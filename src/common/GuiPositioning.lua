-- The AbsolutePosition of any object is not the same as it's actual pixel
-- coordinates on the screen. AbsolutePosition is relative to the pixel
-- coordinate (0,36), so the top left pixel actually has AbsolutePosition
-- (0,-36)

-- To place a GuiObject somewhere, you need to set its Position property.
-- The resulting AbsolutePosition depends on whether IgnoreGuiInset is
-- checked on the screen gui that the GuiObject lives in.

-- A Position value has both a scale value and offset value
-- The below discussion is treating GuiObject.Y as if it's just an offset
-- value, since these are pixel units, not proportions of the screen.

-- If IgnoreGuiInset is off then
-- GuiObject.AbsolutePosition.Y = GuiObject.Position.Y
-- If IgnoreGuiInset is on then
-- GuiObject.AbsolutePosition.Y = GuiObject.Position.Y - 36

-- So if we have a target value for GuiObject.AbsolutePosition.Y
-- and IgnoreGuiInset is on, then we should set the GuiObject.Position.Y
-- to +36 more than the target value

-- In terms of actual pixel coordinates... (where objectPixelY is the actual
-- y-coordinate of the object on the screen)

-- If IgnoreGuiInset is off then
-- objectPixelY = GuiObject.Position.Y + 36
-- If IgnoreGuiInset is on then
-- objectPixelY = GuiObject.Position.Y

-- So if we want the anchor point of our object to appear at some pixel
-- coordinate x,y, and IgnoreGuiInset is off, then we should set
-- GuiObject.Position.Y to y-36.


-- Returns the correct value for GuiObject.Position so that it will appear
-- at the given absolutePosition
-- The IgnoreGuiInset property of the screen gui should be passed as the
-- second argument.
local function PositionFromAbsolute(absolutePosition, ignoreGuiInsetChecked)
	if ignoreGuiInsetChecked then
		return UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y + 36)
	else
		return UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y)
	end
end

-- Returns the correct value for GuiObject.Position so that it will appear
-- at the given pixel coordinates on the screen.
-- The IgnoreGuiInset property of the screen gui should be passed as the
-- second argument.
local function PositionFromPixel(pixelX, pixelY, ignoreGuiInsetChecked)
	if ignoreGuiInsetChecked then
		return UDim2.new(0, pixelX, 0, pixelY)
	else
		return UDim2.new(0, pixelX, 0, pixelY-36)
	end
end


return {
  PositionFromAbsolute = PositionFromAbsolute,
  PositionFromPixel = PositionFromPixel,
}