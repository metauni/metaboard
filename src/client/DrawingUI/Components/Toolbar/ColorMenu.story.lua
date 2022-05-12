return function(target)
	local Roact = require(game:GetService("ReplicatedStorage").metaboardCommon.Packages.Roact)
	local e = Roact.createElement

	local ColorMenu = require(script.Parent.ColorMenu)

	local comp = Roact.Component:extend("comp")

	function comp:init()
		self:setState({
			ShadedColor = {
				BaseName = "Red",
				BaseColor = Color3.fromHex("D20000"),
				Color = Color3.fromHex("D20000"),
			}
		})
	end

	function comp:render()

		return e(ColorMenu, {
			SelectedShadedColor = self.state.ShadedColor,
			OnShadedColorSelect = function(shadedColor)
				self:setState({
					ShadedColor = shadedColor,
				})
			end
		})
	end

	local handle = Roact.mount(e(comp), target, "ColorMenu")

	return function()
		Roact.unmount(handle)
	end
end