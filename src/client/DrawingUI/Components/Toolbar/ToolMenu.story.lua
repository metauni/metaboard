return function(target)
	local Roact = require(game:GetService("ReplicatedStorage").MetaBoardCommon.Packages.Roact)
	local e = Roact.createElement

	local ToolMenu = require(script.Parent.ToolMenu)

	local comp = Roact.Component:extend("comp")

	function comp:init()
		self:setState({
			EquippedToolName = "Pen",
		})
	end

	function comp:render()

		return e(ToolMenu, {
			EquippedToolName = self.state.EquippedToolName,
			EquipTool = function(toolName)
				self:setState({
					EquippedToolName = toolName
				})
			end
		})
	end

	local handle = Roact.mount(e(comp), target)

	return function()
		Roact.unmount(handle)
	end
end