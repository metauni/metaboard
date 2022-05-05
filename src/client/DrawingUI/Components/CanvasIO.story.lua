-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local CanvasIO = require(script.Parent.CanvasIO)

return function (target)

	Roact.setGlobalConfig({
		elementTracing = true
	})

	local App = Roact.Component:extend("App")

	function App:init()
		self.absPositionBinding, self.setAbsPosition = Roact.createBinding(Vector2.new(0,0))
		self.absSizeBinding, self.setAbsSize = Roact.createBinding(Vector2.new(0,0))
		self.cursorPositionBinding, self.setCursorPosition = Roact.createBinding(Vector2.new(0,0))
	end

	function App:render()
		local down = self.state.Down or Vector2.new(0,0)
		local moved = self.state.Moved or Vector2.new(0,0)
		local upCount = self.state.UpCount or 0

		local canvasBox = e("TextLabel", {
			Text = string.format("Down %d, %d\nMoved %d, %d\nUp Count: %d", down.X*100, down.Y*100, moved.X*100, moved.Y*100, upCount),
			
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.fromScale(0.5,0.5),
			Size = UDim2.fromScale(1,1),
			BackgroundTransparency = 0,

			[Roact.Change.AbsoluteSize] = function(rbx)
				self.setAbsSize(rbx.AbsoluteSize)
			end,
			[Roact.Change.AbsolutePosition] = function(rbx)
				self.setAbsPosition(rbx.AbsolutePosition)
			end,

			[Roact.Children] = {
				UIAspectRatioConstraint = e("UIAspectRatioConstraint", {
					AspectRatio = 4/3,
				})
			}
		})


		local regionFrame = e("Frame", {
			Position = UDim2.new(0,50,0,50),
			Size = UDim2.new(1,-100,1,-100),
			BackgroundTransparency = 1,
			ZIndex = 1,

			[Roact.Children] = {
				CanvasBox = canvasBox
			}
		})

		local canvasIO = e(CanvasIO, {
			AbsolutePositionBinding = self.absPositionBinding,
			AbsoluteSizeBinding = self.absSizeBinding,
			IgnoreGuiInset = false,
			SetCursorPosition = self.setCursorPosition,
			ZIndex = 2,

			ToolDown = function(pos)
				self:setState({
					Down = pos,
				})
			end,
			ToolMoved = function(pos)
				self:setState({
					Moved = pos,
				})
			end,
			ToolUp = function()
				self:setState(function(oldState)
					return {
						UpCount = (oldState.UpCount or 0) + 1
					}
				end)
			end,
		})

		local cursor = e("Frame", {
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = self.cursorPositionBinding:map(function(position)
				return UDim2.fromOffset(position.X, position.Y)
			end),
			BackgroundTransparency = 0.8,
			BackgroundColor3 = Color3.new(0,0,0),
			ZIndex = 3,
	
			[Roact.Children] = {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0.5,0) }),
				UIStroke = e("UIStroke", { Thickness = 2, Color = Color3.new(1,1,1) })
			}
		})
		
		return e("Folder", {}, {
			RegionFrame = regionFrame,
			CanvasIO = canvasIO,
			cursor = cursor,
		})
	end

	local handle = Roact.mount(e(App, {}), target)

	return function()
		Roact.unmount(handle)
	end
end