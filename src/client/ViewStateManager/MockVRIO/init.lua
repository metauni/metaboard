-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local toolFunctions = require(script.toolFunctions)
local ToolQueue = require(script.Parent.Parent.UserInput.ToolQueue)
local Pen = require(script.Pen)
local Eraser = require(script.Eraser)

local function toScalar(viewX, viewY, canvasCFrame, canvasSize)
	return Vector2.new(viewX, viewY) / workspace.CurrentCamera.ViewportSize.Y
end

return function (self)

	local connections = {}

	-- local toolQueue = ToolQueue(self)
	-- self.ToolHeld = false
	self.EquippedTool = Pen
	self.EraserSize = 0.1

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if not self.state.ToolHeld then
				if input.KeyCode == Enum.KeyCode.E then
					self.EquippedTool = Eraser
				elseif input.KeyCode == Enum.KeyCode.P then
					self.EquippedTool = Pen
				elseif input.KeyCode == Enum.KeyCode.U then
					self.props.Board.Remotes.Undo:FireServer()
				elseif input.KeyCode == Enum.KeyCode.R then
					self.props.Board.Remotes.Redo:FireServer()
				end
			end
		end

	end))

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:setState(function(state)
				return toolFunctions.ToolDown(self, state, toScalar(input.Position.X, input.Position.Y, self.props.CanvasCFrame, self.props.CanvasSize))
			end)
		end
		
	end))
	
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:setState(function(state)
				return toolFunctions.ToolMoved(self, state, toScalar(input.Position.X, input.Position.Y, self.props.CanvasCFrame, self.props.CanvasSize))
			end)
		end

	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:setState(function(state)
				return toolFunctions.ToolUp(self, state)
			end)
		end

	end))

	return {

		Destroy = function ()

			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end

		end

	}

end