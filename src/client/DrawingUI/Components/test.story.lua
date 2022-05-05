-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function (target)

	local App = Roact.Component:extend("App")

	function App:init()
		self.absPositionBinding, self.setAbsPosition = Roact.createBinding(Vector2.new(0,0))
		self.absSizeBinding, self.setAbsSize = Roact.createBinding(Vector2.new(0,0))
	end

	function App:render()


		local mainBox = e("TextLabel", {
			Text = Roact.joinBindings({
				Pos = self.absPositionBinding,
				Size = self.absSizeBinding,
			}):map(function(values)
				return string.format("Position: %s\nSize: %s", tostring(values.Pos), tostring(values.Size))
			end),
			ZIndex = 1,

			Position = UDim2.fromOffset(500,100),
			Size = UDim2.fromScale(0.5,0.5),
			AnchorPoint = Vector2.new(0,0),
			BackgroundTransparency = 0.5,

			[Roact.Change.AbsoluteSize] = function(rbx)
				self.setAbsSize(rbx.AbsoluteSize)
			end,
			[Roact.Change.AbsolutePosition] = function(rbx)
				self.setAbsPosition(rbx.AbsolutePosition)
			end,
		})

		-- local followerBox = e("TextLabel", {
		-- 	Text = "FollowerBox",
		-- 	ZIndex = 2,

		-- 	AnchorPoint = self.props.AnchorPoint,
		-- 	Position = self.absPositionBinding:map(function(absPosition)
		-- 		return UDim2.fromOffset(absPosition.X, absPosition.Y)
		-- 	end),
		-- 	Size = self.absSizeBinding:map(function(absSize)
		-- 		return UDim2.fromOffset(absSize.X, absSize.Y)
		-- 	end),

		-- 	BackgroundTransparency = 0.5,
		-- 	BackgroundColor3 = Color3.new(1,0,0),
		-- })
		
		return e("Folder", {},
		{
			MainBox = mainBox,
			FollowerBox = followerBox,
		})
	end

	local handle = Roact.mount(e(App, {}), target)

	return function()
		Roact.unmount(handle)
	end
end