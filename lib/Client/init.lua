-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

-- Imports
local root = script.Parent
local Maid = require(ReplicatedStorage.Packages.metaboard.Util.Maid)
local Blend = require(ReplicatedStorage.Util.Blend)
local Promise = require(ReplicatedStorage.Util.Promise)
local Config = require(root.Config)
local BoardClient = require(script.BoardClient)
local Feather = require(root.Parent.Feather)
local BoardState = require(root.BoardState)
local Binder = require(root.Util.Binder)
local ValueObject = require(root.Util.ValueObject)
local SurfaceCanvas = require(script.SurfaceCanvas)
local VRDrawingController = require(script.VRDrawingController)
local DrawingUI = require(root.DrawingUI)

local Remotes = root.Remotes

-- Constants
local LINE_LOAD_FRAME_BUDGET = 256
local LINE_DESTROY_FRAME_BUDGET = 256

local Client = {
	VRInputs = {},

	_canvasLoadingQueue = {},
}
Client.__index = Client


Client.BoardClientBinder = Binder.new("BoardClient", function(part: Part)
	local board = BoardClient.new(part)
	local data = board.Remotes.GetBoardData:InvokeServer()
	debug.profilebegin("[metaboard] Deserialise state")
	board.State = BoardState.deserialise(data)
	debug.profileend()
	board:ConnectRemotes()
	return board
end)
Client.SurfaceCanvasBinder = Binder.new("SurfaceCanvas", SurfaceCanvas, Client)


function Client:Init()
	self._maid = Maid.new()
	self.OpenedBoard = ValueObject.new(nil)
	self.BoardSelectionMode = ValueObject.new(false)
	self.HoveredBoard = ValueObject.new(nil)

	self.BoardClientBinder:Init()
	self.SurfaceCanvasBinder:Init()
end

function Client:OpenBoard(board: BoardClient.BoardClient)
	local onClose = function()
		self._maid._drawingUI = nil
		task.wait()
		self.OpenedBoard.Value = nil
	end
	self._maid._drawingUI = DrawingUI(board, "Gui", onClose)
	self.OpenedBoard.Value = board
end

function Client:CloseBoard()
	self._maid._drawingUI = nil
	self.OpenedBoard.Value = nil
end

-- For preventing boards opens while clicking on gui elements
-- gameProcessedEvent isn't always reliable (e.g. semi-transparent gui elements)
local function obscuredByGuiObject(screenPos: Vector2 | Vector3)
	local objects = Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(screenPos.X, screenPos.Y)
	for _, object in objects do
		if object.Visible and object.Transparency ~= 1 then
			return true
		end
	end
	return false
end

function Client:GetHoveredBoard(screenPos: Vector2 | Vector3): BoardClient.BoardClient?

	local unitRay = workspace.CurrentCamera:ScreenPointToRay(screenPos.X, screenPos.Y)

	local boardRaycastParams = RaycastParams.new()
	boardRaycastParams.FilterType = Enum.RaycastFilterType.Include
	boardRaycastParams.FilterDescendantsInstances = CollectionService:GetTagged("BoardClient")
	
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, boardRaycastParams)
	if not raycastResult then
		return nil
	end

	local board = self.BoardClientBinder:Get(raycastResult.Instance)
	if not board then
		return nil
	end

	if board:GetSurfaceCFrame().LookVector:Dot(workspace.CurrentCamera.CFrame.LookVector) >= 0 then
		-- Board not facing camera
		return nil
	end

	return board
end

-- Returns promise of selected board and maid
function Client:PromiseBoardSelection()
	local maid = Maid.new()
	
	self.BoardSelectionMode.Value = true

	local promise = Promise.new(function(resolve)
		if UserInputService.TouchEnabled then
			maid:Add(UserInputService.TouchTapInWorld:Connect(function(position: Vector2, gameProcessedEvent: boolean)
				if gameProcessedEvent or obscuredByGuiObject(position) then
					return
				end
		
				local board = self:GetHoveredBoard(position)
				resolve(board) -- could be nil
			end))
		else
			maid:Add(UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 or obscuredByGuiObject(inputObject.Position) then
					return
				end
		
				local board = self:GetHoveredBoard(inputObject.Position, true)
				resolve(board) -- could be nil
			end))
		end
	end)

	promise:Finally(function()
		Maid.cleanTask(maid)
	end)

	maid:Add(function()
		if not Promise.IsFulfilled(promise) then
			Promise.Reject(Promise)
		end
		task.defer(function()
			self.BoardSelectionMode.Value = false
		end)
	end)

	return promise, maid
end

function Client:Start()
	self.BoardClientBinder:Start()
	self.SurfaceCanvasBinder:Start()

	self.BoardClientBinder:GetClassRemovingSignal():Connect(function(board)
		if self.OpenedBoard.Value == board then
			self:CloseBoard()
		end
	end)

	if UserInputService.TouchEnabled then
		UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
			if processedByUI or self.OpenedBoard.Value or self.BoardSelectionMode.Value or obscuredByGuiObject(position) then
				return
			end
	
			local board = self:GetHoveredBoard(position)
			if board then
				self:OpenBoard(board)
			end
		end)
	else

		UserInputService.InputChanged:Connect(function(inputObject: InputObject)
			if inputObject.UserInputType ~= Enum.UserInputType.MouseMovement and inputObject.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
	
			local board = self:GetHoveredBoard(inputObject.Position)
			self.HoveredBoard.Value = board
		end)

		Blend.Single(Blend.Dynamic(self.HoveredBoard, function(board: BoardClient.BoardClient?)
			if not board then
				return nil
			end
	
			return Blend.New "Highlight" {
				Parent = board:GetPart(),
				Archivable = false,
				FillColor = Color3.new(1,1,1),
				FillTransparency = 0.6,
				OutlineTransparency = 1,
				Name = "BoardHover"
			}
		end)):Subscribe()

		local clickBeganBoard = nil

		self.HoveredBoard.Changed:Connect(function(board)
			if board == nil then
				clickBeganBoard = nil
			end
		end)

		UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if self.OpenedBoard.Value or self.BoardSelectionMode.Value or obscuredByGuiObject(inputObject.Position) then
				return
			end
	
			local board = self:GetHoveredBoard(inputObject.Position)
			if board then
				clickBeganBoard = board
			end
		end)

		UserInputService.InputEnded:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
				clickBeganBoard = nil
				return
			end
			if self.OpenedBoard.Value or self.BoardSelectionMode.Value or obscuredByGuiObject(inputObject.Position) then
				clickBeganBoard = nil
				return
			end
	
			local board = self:GetHoveredBoard(inputObject.Position)
			if board and board == clickBeganBoard then
				self:OpenBoard(board)
			end
			clickBeganBoard = nil
		end)
	end

	self._surrenderedCanvasTrees = {}
	self.SurfaceCanvasBinder:GetClassRemovingSignal():Connect(function(surfaceCanvas)
		local canvasTree = surfaceCanvas:SurrenderCanvasTree()
		if canvasTree then
			table.insert(self._surrenderedCanvasTrees, canvasTree)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.3)
			local boardAncestorValue = ReplicatedStorage:FindFirstChild("BoardAncestor")
			local boardAncestor = boardAncestorValue and boardAncestorValue.Value or nil
			
			local character = Players.LocalPlayer.Character
			if not character or not character.PrimaryPart then
				continue
			end
			
			for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do

				if boardAncestor then
					if 
						instance:IsDescendantOf(boardAncestor)
						or (instance.Position - character:GetPivot().Position).Magnitude < Config.AttachedRadius
					then
						if instance:HasTag(self.BoardClientBinder:GetTag()) then
							self.SurfaceCanvasBinder:BindClient(instance)
						else
							Remotes.RequestBoardInit:FireServer(instance)
						end
					else
						self.SurfaceCanvasBinder:UnbindClient(instance)
					end
				else -- Just stream based on radius
					if (instance.Position - character:GetPivot().Position).Magnitude < Config.RoamingStreamingInRadius then
						if instance:HasTag(self.BoardClientBinder:GetTag()) then
							self.SurfaceCanvasBinder:BindClient(instance)
						else
							Remotes.RequestBoardInit:FireServer(instance)
						end
					elseif (instance.Position - character:GetPivot().Position).Magnitude >= Config.RoamingStreamingOutRadius then
						self.SurfaceCanvasBinder:UnbindClient(instance)
					end
				end
			end
		end
	end)

	-- Sort all the boards by proximity to the character every 0.5 seconds
	-- TODO: Holy smokes batman is this not optimised. We need a voronoi diagram and/or a heap.
	-- Must not assume that boards don't move around.
	
	task.spawn(function()
		
		while true do
			
			local character = Players.LocalPlayer.Character
			if not character then
				task.wait(0.5)
				continue
			end
			local characterPos = character:GetPivot().Position
		
			self._canvasLoadingQueue = {}

			-- Sort the loading canvases by distance and store them in self._canvasLoadingQueue
			do
				local nearestSet = {}

				while true do
					local minSoFar = math.huge
					local nearestCanvas = nil
					for surfaceCanvas in self.SurfaceCanvasBinder:GetAllSet() do
						if 
							not surfaceCanvas:GetPart():IsDescendantOf(workspace)
							or not surfaceCanvas.Loading.Value
							or nearestSet[surfaceCanvas]
						then
							continue
						end

						local distance = (surfaceCanvas.SurfaceCFrame.Value.Position - characterPos).Magnitude
						if distance < minSoFar then
							nearestCanvas = surfaceCanvas
							minSoFar = distance
						end
					end

					if nearestCanvas then
						table.insert(self._canvasLoadingQueue, nearestCanvas)
						nearestSet[nearestCanvas] = true
					else
						break
					end
				end
			end

			task.wait(0.5)
		end
	end)

	-- Load Surface Canvases gradually, prioritised by proximity and visibility
	RunService.Heartbeat:Connect(function()

		-- Slowly destroy all surrendered canvas trees
		local destroyed = 0
		while destroyed < LINE_DESTROY_FRAME_BUDGET and #self._surrenderedCanvasTrees > 0 do
			local canvasTree = self._surrenderedCanvasTrees[1]
			if Feather.destructionFinished(canvasTree) then
				table.remove(self._surrenderedCanvasTrees, 1)
			else
				destroyed += Feather.slowDestroy(canvasTree, LINE_DESTROY_FRAME_BUDGET - destroyed)
			end
		end

		local closestLoading
		local closestInFOV
		local closestVisible
		
		for _, surfaceCanvas in ipairs(self._canvasLoadingQueue) do
			
			if surfaceCanvas.Loading.Value then
				closestLoading = closestLoading or surfaceCanvas

				local boardPos = surfaceCanvas.SurfaceCFrame.Value.Position
				local _, inFOV = workspace.CurrentCamera:WorldToViewportPoint(boardPos)
				
				if inFOV then
					closestInFOV = closestInFOV or surfaceCanvas

					if surfaceCanvas.SurfaceCFrame.Value.LookVector:Dot(workspace.CurrentCamera.CFrame.LookVector) < 0 then
						closestVisible = closestVisible or surfaceCanvas
						break
					end
				end
			end
		end

		local canvasToLoad = closestVisible or closestInFOV or closestLoading
		if canvasToLoad then
			debug.profilebegin("LoadMore")
			canvasToLoad:LoadMore(LINE_LOAD_FRAME_BUDGET)
			debug.profileend()
		end
	end)

	if VRService.VREnabled then
		VRDrawingController.StartWithBinder(Client.BoardClientBinder)
	end
end

function Client:GetBoard(part: Part)
	return self.BoardClientBinder:Get(part)
end

function Client:WaitForBoard(part: Part)
	return self.BoardClientBinder:Promise(part):Wait()
end

return Client
