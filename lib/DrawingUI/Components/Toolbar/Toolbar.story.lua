return function (target)
	
	local root = script.Parent.Parent.Parent.Parent
	local Roact: Roact = require(root.Parent.Roact)
	local Sift: Sift = require(root.Parent.Sift)
	local e = Roact.createElement

	local Toolbar = require(script.Parent)
	local ToolState = require(root.DrawingUI.ToolState)

	local App = Roact.Component:extend("Toolbar")

	function App:init()
		self:setState({
			ToolState = ToolState:Get()
		})
	end

	function App:SetToolState(toolState)
		self:setState(function(state)
	
			local newToolState = Sift.Dictionary.merge(state.ToolState, toolState)
			ToolState.Set(newToolState)
	
			return {
				ToolState = newToolState
			}
		end)
	end

	function App:render()

		local toolState = self.state.ToolState
		
		return e(Toolbar, {
	
			CanWrite = true,
	
			SubMenu = self.state.SubMenu,
			SetSubMenu = function(subMenu)
				self:setState({ SubMenu = subMenu })
			end,
	
			EquippedTool = toolState.EquippedTool,
			EquipTool = function(tool)
				self:SetToolState({ EquippedTool = tool })
			end,
	
			StrokeWidths = toolState.StrokeWidths,
			SelectedStrokeWidthName = toolState.SelectedStrokeWidthName,
			SelectStrokeWidth = function(name)
				self:SetToolState({ SelectedStrokeWidthName = name })
			end,
			UpdateStrokeWidth = function(strokeWidth)
				self:SetToolState({
	
					StrokeWidths = Sift.Dictionary.merge(toolState.StrokeWidths,{
						[toolState.SelectedStrokeWidthName] = strokeWidth
					})
	
				})
			end,
	
			SelectedEraserSizeName = toolState.SelectedEraserSizeName,
			SelectEraserSize = function(name)
				self:SetToolState({ SelectedEraserSizeName = name })
			end,
	
			ColorWells = toolState.ColorWells,
			SelectedColorWellIndex = toolState.SelectedColorWellIndex,
			SelectColorWell = function(index)
				self:SetToolState({ SelectedColorWellIndex = index })
			end,
			UpdateColorWell = function(index, shadedColor)
				self:SetToolState({
					ColorWells = Sift.Dictionary.merge(toolState.ColorWells, {
						[index] = shadedColor
					})
				})
			end,
	
			CanUndo = false,
			CanRedo = false,
			-- TODO: this ignores player histories.
			CanClear = true,
	
			-- OnUndo = function()
			-- 	self.props.Board.Remotes.Undo:FireServer()
			-- end,
			-- OnRedo = function()
			-- 	self.props.Board.Remotes.Redo:FireServer()
			-- end,
	
			-- OnCloseButtonClick = function()
			-- 	self.props.OnClose()
			-- end,
	
		})
	end
	

	local handle = Roact.mount(e(App), target)

	return function ()
		Roact.unmount(handle)
	end
end