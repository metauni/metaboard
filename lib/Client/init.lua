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

-- Imports
local root = script.Parent
local Maid = require(ReplicatedStorage.Packages.metaboard.Util.Maid)
local Map = require(ReplicatedStorage.Util.Map)
local Promise = require(ReplicatedStorage.Util.Promise)
local Stream = require(ReplicatedStorage.Util.Stream)
local U = require(ReplicatedStorage.Util.U)
local Value = require(ReplicatedStorage.Util.Value)
local Config = require(root.Config)
local BoardClient = require(script.BoardClient)
local Feather = require(root.Parent.Feather)
local BoardState = require(root.BoardState)
local SurfaceCanvas = require(script.SurfaceCanvas)
local DrawingUI = require(root.DrawingUI)

local Remotes = root.Remotes

-- Constants
local LINE_LOAD_FRAME_BUDGET = 256
local LINE_DESTROY_FRAME_BUDGET = 256

local Client = {
	VRInputs = {},

	Boards =  Map({} :: {[Instance]: BoardClient.BoardClient}),
	SurfaceCanvases = Map({} :: {[Instance]: any}),

	_maid = Maid.new(),
	OpenedBoard = Value(nil),
	BoardSelectionMode = Value(false),
	HoveredBoard = Value(nil),
}

local CanvasLoadingQueue = {}
local SurrenderedCanvasTrees = {}

function Client:OpenBoard(board: BoardClient.BoardClient)
	local onClose = function()
		self._maid._drawingUI = nil
		task.wait() -- wtf is this for? yikes for not explaining
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
		if not object.Visible then
			continue
		end
		if object.BackgroundTransparency < 1 then
			return true
		end
		if object:IsA("ImageButton") or object:IsA("ImageLabel") then
			if object.ImageTransparency < 1 then
				return true
			end
		end
	end
	return false
end

function Client:GetHoveredBoard(screenPos: Vector2 | Vector3): BoardClient.BoardClient?

	if obscuredByGuiObject(screenPos) then
		return nil
	end

	local unitRay = workspace.CurrentCamera:ScreenPointToRay(screenPos.X, screenPos.Y)

	local boardRaycastParams = RaycastParams.new()
	boardRaycastParams.FilterType = Enum.RaycastFilterType.Include
	boardRaycastParams.FilterDescendantsInstances = CollectionService:GetTagged("BoardClient")
	
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, boardRaycastParams)
	if not raycastResult then
		return nil
	end

	local board = self.Boards:Get(raycastResult.Instance)
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
			maid:Add(UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
				local ignore = processedByUI
					or self.OpenedBoard.Value
					or self.BoardSelectionMode.Value
				if ignore then
					return
				end
		
				local board = self:GetHoveredBoard(position)
				resolve(board) -- could be nil
			end))
		else
			maid:Add(UserInputService.InputBegan:Connect(function(inputObject: InputObject, processedByUI: boolean)
				local ignore = processedByUI
					or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
					or self.OpenedBoard.Value
					or self.BoardSelectionMode.Value
				if ignore then
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
			promise:Reject()
		end
		task.defer(function()
			self.BoardSelectionMode.Value = false
		end)
	end)

	return promise, maid
end

local function setupBoardClickAndHover()
	if UserInputService.TouchEnabled then
		UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
			local ignore = processedByUI
				or Client.OpenedBoard.Value
				or Client.BoardSelectionMode.Value
			if ignore then
				return
			end
	
			local board = Client:GetHoveredBoard(position)
			if board then
				Client:OpenBoard(board)
			end
		end)
	else

		UserInputService.InputChanged:Connect(function(inputObject: InputObject)
			if Client.OpenedBoard.Value then
				Client.HoveredBoard.Value = nil
				return
			end
			local board = Client:GetHoveredBoard(inputObject.Position)
			Client.HoveredBoard.Value = board
		end)

		Stream.listenTidy(Client.HoveredBoard:Stream(), function(board)
			if board == nil then
				return
			end

			return U.new "Highlight" {
				Parent = board:GetPart(),
				Archivable = false,
				FillColor = Color3.new(1,1,1),
				FillTransparency = 0.6,
				OutlineTransparency = 1,
				Name = "BoardHover"
			}
		end)

		local clickBeganBoard = nil

		Client.HoveredBoard.Changed:Connect(function(board)
			if board == nil then
				clickBeganBoard = nil
			end
		end)

		UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
			local ignore = gameProcessedEvent
				or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
				or Client.OpenedBoard.Value
				or Client.BoardSelectionMode.Value
			if ignore then
				return
			end
	
			local board = Client:GetHoveredBoard(inputObject.Position)
			if board then
				clickBeganBoard = board
			end
		end)

		UserInputService.InputEnded:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
				clickBeganBoard = nil
				return
			end
			if Client.OpenedBoard.Value or Client.BoardSelectionMode.Value or obscuredByGuiObject(inputObject.Position) then
				clickBeganBoard = nil
				return
			end
	
			local board = Client:GetHoveredBoard(inputObject.Position)
			if board and board == clickBeganBoard then
				Client.HoveredBoard.Value = nil
				Client:OpenBoard(board)
			end
			clickBeganBoard = nil
		end)
	end
end

local function startBoardStreamingBehaviour()
	
	task.spawn(function()
		while true do
			-- There is a task.wait at the end of the loop
			local character = Players.LocalPlayer.Character
			if not character or not character.PrimaryPart then
				task.wait(0.3)
				continue
			end

			local boardAncestorValue = ReplicatedStorage:FindFirstChild("BoardAncestor")
			local boardAncestor = boardAncestorValue and boardAncestorValue.Value or nil
			local streamInRadius = if boardAncestor then Config.AttachedRadius else Config.RoamingStreamingInRadius
			local streamOutRadius = if boardAncestor then Config.AttachedRadius else Config.RoamingStreamingOutRadius

			for _, part: Part in CollectionService:GetTagged(Config.BoardTag) do
				
				local surfaceCanvas = Client.SurfaceCanvases:Get(part)
				local board = Client.Boards:Get(part)
				
				local isDescendantBoard = boardAncestor and part:IsDescendantOf(boardAncestor)
				local streamIn = isDescendantBoard or (part.Position - character:GetPivot().Position).Magnitude < streamInRadius
				local streamOut = not isDescendantBoard and (part.Position - character:GetPivot().Position).Magnitude >= streamOutRadius

				if streamIn then
					if not board then
						Remotes.RequestBoardInit:FireServer(part)
					elseif not surfaceCanvas then
						surfaceCanvas = SurfaceCanvas.new(part, Client)
						Client.SurfaceCanvases:Set(part, surfaceCanvas)
					end
				elseif streamOut and surfaceCanvas then
					table.insert(SurrenderedCanvasTrees, surfaceCanvas:SurrenderCanvasTree())
					surfaceCanvas:Destroy()
					Client.SurfaceCanvases:Set(part, nil)
				end
			end

			task.wait(0.3)
		end
	end)
end

local function startSurfaceCanvasLoading()
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

			-- Sort the loading canvases by distance and store them in CanvasLoadingQueue
			do
				local nearestSet = {}

				while true do
					local minSoFar = math.huge
					local nearestCanvas = nil
					for _, surfaceCanvas in Client.SurfaceCanvases.Map do
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
						table.insert(CanvasLoadingQueue, nearestCanvas)
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
		while destroyed < LINE_DESTROY_FRAME_BUDGET and #SurrenderedCanvasTrees > 0 do
			local canvasTree = SurrenderedCanvasTrees[1]
			if Feather.destructionFinished(canvasTree) then
				table.remove(SurrenderedCanvasTrees, 1)
			else
				destroyed += Feather.slowDestroy(canvasTree, LINE_DESTROY_FRAME_BUDGET - destroyed)
			end
		end

		local closestLoading
		local closestInFOV
		local closestVisible
		
		for _, surfaceCanvas in CanvasLoadingQueue do
			
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
end

function Client:Start()

	CollectionService:GetInstanceRemovedSignal("BoardClient"):Connect(function(part: Instance)
		local board = Client.Boards:Get(part)
		if board then
			Client.Boards:Set(part, nil)
			board:Destroy()
		end
	end)

	Stream.listenTidyEach(Stream.eachTagged("BoardClient"), function(part: Instance)
		if Client.Boards:Get(part) ~= nil then
			return
		end
		local board = BoardClient.new(part)

		-- Return this coroutine so it gets cancelled if board is untagged before
		-- the :InvokeServer() finishes.
		return task.spawn(function()
			local data = board.Remotes.GetBoardData:InvokeServer()
			-- Board could have been manually set before we had the chance, for
			-- various reasons.
			if Client.Boards:Get(part) ~= nil then
				board:Destroy()
				return
			end
			debug.profilebegin("[metaboard] Deserialise state")
			board.State = BoardState.deserialise(data)
			debug.profileend()
			board:ConnectRemotes()
			Client.Boards:Set(part, board)
		end)
	end)

	setupBoardClickAndHover()
	startSurfaceCanvasLoading()
	startBoardStreamingBehaviour()
end

function Client:GetBoard(part: Part)
	return Client.Boards:Get(part)
end

function Client:WaitForBoard(part: Part)
	return Client.Boards:Wait(part)
end

return Client
