return function(target)
	local Common = game:GetService("ReplicatedStorage").metaboardCommon
	local Roact: Roact = require(Common.Packages.Roact)
	local e = Roact.createElement

	local Slider = require(script.Parent.Slider)

	local comp = Roact.Component:extend("comp")

	function comp:init()
		self:setState({
			Alpha = 0,
		})
	end

	function comp:render()

		local alpha = self.state.Alpha

		local slider1 = e(Slider, {
			Position = UDim2.new(0.5, 0, 0.5, -100),

			KnobLabelText = tostring(math.round(100*alpha)),
			KnobAlpha = alpha,
			OnKnobPositionUpdate = function(newAlpha)
				self:setState({
					Alpha = newAlpha,
				})
			end
		})

		local slider2 = function(props)
			return e(Slider, {
				Position = UDim2.new(0.5, 0, 0.5, 100),

				KnobLabelText = tostring(math.round(100*alpha)),
				KnobAlpha = alpha,
				OnKnobPositionUpdate = function(newAlpha)
					self:setState({
						Alpha = newAlpha,
					})
				end
			})
		end

		return e("Folder", {}, {
			Slider1 = slider1,
			Slider2 = e(slider2),
		})
	end

	local handle = Roact.mount(e(comp, {}), target)

	return function()
		Roact.unmount(handle)
	end
end