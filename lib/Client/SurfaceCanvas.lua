-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local root = script.Parent.Parent
local BaseObject = require(root.Util.BaseObject)
local ValueObject = require(root.Util.ValueObject)
local Blend = require(root.Util.Blend)
local Sift = require(root.Parent.Sift)
local BoardUtils = require(root.BoardUtils)
local BoardState = require(script.Parent.Parent.BoardState)
local Rx = require(root.Util.Rx)
local Rxi = require(root.Util.Rxi)
local Feather = require(root.Parent.Feather)
local PartCanvas = require(root.PartCanvas)

local SurfaceCanvas = setmetatable({}, BaseObject)
SurfaceCanvas.__index = SurfaceCanvas
SurfaceCanvas.ClassName = "SurfaceCanvas"

function SurfaceCanvas.new(part: Part, service)
	local self = setmetatable(BaseObject.new(part), SurfaceCanvas)

	self._figures = {}
	self._figureMaskBundles = {}
	self.Loading = self._maid:Add(ValueObject.new(false, "boolean"))
	self.SurfaceSize = self._maid:Add(ValueObject.fromObservable(BoardUtils.observeSurfaceSize(part)))
	self.SurfaceCFrame = self._maid:Add(ValueObject.fromObservable(BoardUtils.observeSurfaceCFrame(part)))

	self._maid:GiveTask(self.Loading:Observe():Subscribe(function(isLoading: boolean)
		self._obj:SetAttribute("Loading", isLoading)
	end))

	-- Will be slow-destroyed as rootParent of self.CanvasTree if surrendered
	self._model = Instance.new("Model")
	self._maid:GiveTask(function()
		if self._model then
			-- This means SurfaceCanvas was destroyed before the canvas tree was surrendered
			self._model:Destroy()
			self._model = nil
		end
	end)
	self._maid:GiveTask(Blend.mount(self._model, {
		Name = "SurfaceCanvas",
		Parent = Rx.fromSignal(self._obj.AncestryChanged):Pipe {
			Rx.map(function()
				return self._obj:IsDescendantOf(workspace)
			end),
			Rx.defaultsTo(self._obj:IsDescendantOf(workspace)),
			Rx.map(function(inWorkspace: boolean)
				if inWorkspace then
					return self:_getWorkspaceContainer()
				else
					return nil
				end
			end)
		},
	}))

	self._maid:GiveTask(function()
		if self.CanvasTree then
			Feather.unmount(self.CanvasTree)
		end
	end)

	self._maid:GiveTask(service.Boards:StreamKey(self._obj)(function(board)
		if not board then
			self._maid.board = nil
			if self.CanvasTree then
				Feather.unmount(self.CanvasTree)
				self.CanvasTree = nil
			end
			return
		end
		
		self._maid.board = {
			function()
				self:_setLoadingVisual(board, false)
			end,
			self.Loading.Changed:Connect(function(isLoading: boolean)
				self:_setLoadingVisual(board, isLoading)
				if not isLoading then
					self._figures, self._figureMaskBundles = BoardState.render(board:GetCombinedState())
					self:render()
				end
			end),
			board:ObserveCombinedState():Subscribe(function(state)
				if not self.Loading.Value then
					self._figures, self._figureMaskBundles = BoardState.render(state)
					self:render()
				end
			end),
			self.SurfaceSize.Changed:Connect(function()
				if not self.Loading.Value then
					self:render()
				end
			end),
			self.SurfaceCFrame.Changed:Connect(function()
				if not self.Loading.Value then
					self:render()
				end
			end)
		}

		self:_init(board)
		self:render()
	end))

	return self
end

function SurfaceCanvas:GetPart()
	return self._obj
end

function SurfaceCanvas:_init(board)
	self.LineLimit = 0
	self.LineCount = 0
	self.LoadingStack = Sift.Array.sort(Sift.Dictionary.entries(board.State.Figures), function(entry1, entry2)
		return entry1[2].ZIndex > entry2[2].ZIndex
	end)

	if #self.LoadingStack == 0 then
		self.Loading.Value = false
		self._figures, self._figureMaskBundles = BoardState.render(board:GetCombinedState())
	else
		self.Loading.Value = true
	end
end

function SurfaceCanvas:_getWorkspaceContainer()
	local container = workspace:FindFirstChild("ClientManagedCanvases")
	if not container then
		container = Instance.new("Folder")
		container.Name = "ClientManagedCanvases"
		container.Parent = workspace
	end
	return container
end

function SurfaceCanvas:LoadMore(lineBudget)

	if lineBudget > 0 and self.CanvasTree and Feather.numLazyInstances(self.CanvasTree) > 0 then
		local rendered = Feather.lazyParent(self.CanvasTree, lineBudget)
		lineBudget -= rendered
	end

	if lineBudget <= 0 or (self.CanvasTree and Feather.numLazyInstances(self.CanvasTree) > 0) then
		return
	end

	if self.Loading.Value and #self.LoadingStack > 0 then
			
		self.LineLimit += lineBudget

		while self.LineCount <= self.LineLimit and #self.LoadingStack > 0 do

			local figureId, figure = unpack(self.LoadingStack[#self.LoadingStack])
			local figureLineCount = #figure.Points-1

			-- new logic allows adding a big figure that goes over budget
			-- since it will be lazily rendered

			self._figures[figureId] = figure
			self.LineCount += figureLineCount
			self.LoadingStack[#self.LoadingStack] = nil

			if self.LineCount <= self.LineLimit then
				continue
			else
				self._figures = table.clone(self._figures)
				debug.profilebegin("LOADMORE")
				self:render()
				if lineBudget > 0 and self.CanvasTree and Feather.numLazyInstances(self.CanvasTree) > 0 then
					local rendered = Feather.lazyParent(self.CanvasTree, lineBudget)
					lineBudget -= rendered
				end
				debug.profileend()
				return
			end
		end

		if #self.LoadingStack == 0 then
			self.Loading.Value = false
		end
	elseif self.CanvasTree and Feather.numLazyInstances(self.CanvasTree) <= 0 then
		self.Loading.Value = false
	end

	self:render()
end

function SurfaceCanvas:_setLoadingVisual(board, isLoading: boolean)
	local surfacePart = board:GetPart()

	if isLoading and not self._originalTransparency then
		self._originalTransparency = surfacePart.Transparency
		surfacePart.Transparency = 3/4 + 1/4 * self._originalTransparency
	elseif not isLoading and self._originalTransparency then
		surfacePart.Transparency = self._originalTransparency
		self._originalTransparency = nil
	end
end

function SurfaceCanvas:render()

	if self.CanvasTree and Feather.numLazyInstances(self.CanvasTree) > 0 then
		return
	end

	local element = Feather.createElement(PartCanvas, {

		Figures = self._figures,
		FigureMaskBundles = self._figureMaskBundles,

		CanvasSize = self.SurfaceSize.Value,
		CanvasCFrame = self.SurfaceCFrame.Value,
	})

	if self.CanvasTree then
		if self.Loading.Value then
			Feather.lazyUpdate(self.CanvasTree, element)
		else
			Feather.update(self.CanvasTree, element)
		end
	else
		self.CanvasTree = Feather.mount(element, self._model, "Figures")
	end
end

function SurfaceCanvas:SurrenderCanvasTree(): Feather.FeatherTreePartiallyDestroyed?
	if self.CanvasTree then
		local tree = Feather.surrender(self.CanvasTree, true)
		self._model = nil
		self.CanvasTree = nil
		return tree
	end
	return nil
end

return SurfaceCanvas