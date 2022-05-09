-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary

local PartCanvas = require(script.Parent.PartCanvas)

return function (board)

	local SurfaceCanvas = Roact.Component:extend("SurfaceCanvas")

	function SurfaceCanvas:init()

		local figures = table.clone(board.Figures)
		local bundledFigureMasks = {}

		for taskId, drawingTask in pairs(board.DrawingTasks) do
			if drawingTask.TaskType == "Erase" then
				bundledFigureMasks[taskId] = drawingTask:Render(board)
			else
				figures[taskId] = drawingTask:Render()
			end
		end

		self:setState({

			Figures = figures,
			BundledFigureMasks = bundledFigureMasks,

		})
	end

	function SurfaceCanvas:render()

		return e("Folder", {}, {

			Figures = e(PartCanvas, {

				Figures = self.state.Figures,

				BundledFigureMasks = self.state.BundledFigureMasks,

				CanvasSize = board:SurfaceSize(),
				CanvasCFrame = board:SurfaceCFrame(),

				AsFragment = true,

			})

		})

	end

	function SurfaceCanvas:didMount()

		self.drawingTaskChangedConnection = board.DrawingTaskChangedSignal:Connect(function(drawingTask, player, changeType: "Init" | "Update" | "Finish")

			self:setState(function(state)

				local renderTarget, rendering do
					if drawingTask.TaskType == "Erase" then
						renderTarget = "BundledFigureMasks"
						rendering = drawingTask:Render()
						if rendering == state.BundledFigureMasks[drawingTask.TaskId] then
							return nil
						end
					else
						renderTarget = "Figures"
						rendering = drawingTask:Render()
					end
				end 
			
			
				return {
			
					[renderTarget] = Dictionary.merge(state[renderTarget], {
						[drawingTask.TaskId] = rendering
					})
				
				}

			end)

		end)
	end

	function SurfaceCanvas:willUnmount()
		self.drawingTaskChangedConnection:Disconnect()
	end

	local handle = Roact.mount(e(SurfaceCanvas), workspace, board._instance.Name)

	return function()
		Roact.unmount(handle)
	end

end