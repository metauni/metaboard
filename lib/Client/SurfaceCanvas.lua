-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local root = script.Parent.Parent
local Destructor = require(root.Destructor)
local Sift = require(root.Parent.Sift)
local Feather = require(root.Parent.Feather)
local DrawingTask = require(root.DrawingTask)
local PartCanvas = require(root.PartCanvas)

local SurfaceCanvas = {}
SurfaceCanvas.__index = SurfaceCanvas

function SurfaceCanvas.new(board)
	
	local self = setmetatable({
		
		Board = board,
		UnverifiedDrawingTasks = {},
		_destructor = Destructor.new(),
	}, SurfaceCanvas)

	self._destructor:Add(function()
		
		if self.CanvasTree then
			Feather.unmount(self.CanvasTree)
			self.CanvasTree = nil
		end
	end)

	self._destructor:Add(board.DataChangedSignal:Connect(function()
		if not self.Loading then
			self:render()
		end
	end))

	self._destructor:Add(board.SurfaceChangedSignal:Connect(function()
		self:render()
	end))

	self:_initLoadingStack()
	if #self.LoadingStack > 0 then
		self.Loading = true
		self:_setTransparency()
	else
		self.Loading = false
		self:_setActive()
	end

	return self
end

function SurfaceCanvas:Destroy()
	self._destructor:Destroy()
end

function SurfaceCanvas:_getContainer()

	local container
	if self.Board._instance:IsDescendantOf(workspace) then
		
		container = workspace:FindFirstChild("ClientManagedCanvases")
		if not container then
			container = Instance.new("Folder")
			container.Name = "ClientManagedCanvases"
			container.Parent = workspace
		end
	else
		
		container = ReplicatedStorage:FindFirstChild("ClientCanvasStorage")
		if not container then
			container = Instance.new("Folder")
			container.Name = "ClientCanvasStorage"
			container.Parent = ReplicatedStorage
		end
	end
	return container
end

function SurfaceCanvas:_initLoadingStack()
	
	self.LineLimit = 0
	self.LineCount = 0
	self.LoadingStack = Sift.Array.sort(Sift.Dictionary.entries(self.Board.Figures), function(entry1, entry2)
		return entry1[2].ZIndex > entry2[2].ZIndex
	end)
	self.LoadedFigures = {}
end

function SurfaceCanvas:LoadMore(lineBudget)

	if self.Loading and #self.LoadingStack > 0 then
			
		self.LineLimit += lineBudget

		while self.LineCount <= self.LineLimit and #self.LoadingStack > 0 do

			local figureId, figure = unpack(self.LoadingStack[#self.LoadingStack])
			local figureLineCount = #figure.Points-1

			if self.LineCount + figureLineCount <= self.LineLimit then
				
				self.LoadedFigures[figureId] = figure
				self.LineCount += figureLineCount
				self.LoadingStack[#self.LoadingStack] = nil
			else
				self:render()
				return
			end
		end

		if #self.LoadingStack == 0 then
			self.Loading = false
			self:_setActive()
		end
	else
		self.Loading = false
		self:_setActive()
	end

	self:render()
end

function SurfaceCanvas:_setActive()

	self:_setTransparency()

	if self._dataChangedConnection then
		self._dataChangedConnection:Disconnect()
	end

	self._dataChangedConnection = self.Board.DataChangedSignal:Connect(function()
		if not self.Loading then
			self:render()
		end
	end)
end

function SurfaceCanvas:_trimUnverified()

	self.UnverifiedDrawingTasks = Sift.Dictionary.filter(self.UnverifiedDrawingTasks, function(_, taskId)
		local verifiedDrawingTask = self.Board.DrawingTasks[taskId]
		return not (verifiedDrawingTask and verifiedDrawingTask.Finished)
	end)
end

function SurfaceCanvas:_setTransparency()

	local surfacePart = self.Board._instance

	if self.Loading and not self._originalTransparency then
		self._originalTransparency = surfacePart.Transparency
		surfacePart.Transparency = 3/4 + 1/4 * self._originalTransparency
	elseif not self.Loading and self._originalTransparency then
		surfacePart.Transparency = self._originalTransparency
	end
end

function SurfaceCanvas:render()

	local figures, figureMaskBundles

	if self.Loading then
		
		figures = self.LoadedFigures
		figureMaskBundles = {}
	else

		self:_trimUnverified()

		local drawingTasks = Sift.Dictionary.merge(self.Board.DrawingTasks, self.UnverifiedDrawingTasks)
		
		figures = table.clone(self.Board.Figures)
		figureMaskBundles = {}

		-- Apply all of the drawingTasks to the figures,
		-- then all of the unverified ones on top.

		for _, family in {drawingTasks, self.UnverifiedDrawingTasks} do

			for taskId, drawingTask in pairs(family) do
				
				if drawingTask.Type == "Erase" then
	
					local figureIdToFigureMask = DrawingTask.Render(drawingTask)
					
					for figureId, figureMask in pairs(figureIdToFigureMask) do
						local bundle = figureMaskBundles[figureId] or {}
						bundle[taskId] = figureMask
						figureMaskBundles[figureId] = bundle
					end
				else
					figures[taskId] = DrawingTask.Render(drawingTask)
				end
			end
		end
	end

	local element = Feather.createElement(PartCanvas, {

		Figures = figures,
		FigureMaskBundles = figureMaskBundles,

		CanvasSize = self.Board.SurfaceSize,
		CanvasCFrame = self.Board.SurfaceCFrame,
	})

	if self.CanvasTree then
		Feather.update(self.CanvasTree, element)

		self.CanvasTree.root.result[1].Parent = self:_getContainer()
	else
		self.CanvasTree = Feather.mount(element, self:_getContainer(), self.Board:FullName())
	end
end

return SurfaceCanvas