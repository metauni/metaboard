-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local UserInputService = game:GetService("UserInputService")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local toolFunctions = require(script.Parent.Parent.DrawingUI.toolFunctions)
local ToolQueue = require(script.Parent.ToolQueue)

local function toScalar(viewX, viewY, canvasCFrame, canvasSize)
	return Vector2.new(viewX, viewY) / workspace.CurrentCamera.ViewportSize.Y
end

return function (self)

	local connections = {}

	local toolQueue = ToolQueue(self)

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			toolQueue.Enqueue(function(state)
				return toolFunctions.ToolDown(self, state, toScalar(input.Position.X, input.Position.Y, self.props.CanvasCFrame, self.props.CanvasSize))
			end)
		end

	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			toolQueue.Enqueue(function(state)
				return toolFunctions.ToolMoved(self, state, toScalar(input.Position.X, input.Position.Y, self.props.CanvasCFrame, self.props.CanvasSize))
			end)
		end

	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			toolQueue.Enqueue(function(state)
				return toolFunctions.ToolUp(self, state)
			end)
		end

	end))

	return {

		Destroy = function ()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			toolQueue.Destroy()
		end

	}

end