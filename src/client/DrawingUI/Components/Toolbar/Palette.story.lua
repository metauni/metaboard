return function(target)
	local Roact = require(game:GetService("ReplicatedStorage").metaboardCommon.Packages.Roact)
	local e = Roact.createElement

	local Palette = require(script.Parent.Palette)

	local comp = Roact.Component:extend("comp")

	function comp:init()
		self:setState({
			SelectedColorName = "Red"
		})
	end

	function comp:render()

		return e(Palette, {
			SelectedColorName = self.state.SelectedColorName,
			OnNamedColorClick = function(namedColor)
				self:setState({
					SelectedColorName = namedColor.Name,
				})
			end
		})
	end

	local handle = Roact.mount(e(comp), target, "Palette")

	return function()
		Roact.unmount(handle)
	end
end