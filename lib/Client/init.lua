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
local VRService = game:GetService("VRService")

-- Imports
local root = script.Parent
local Config = require(root.Config)
local BoardClient = require(script.BoardClient)
local Feather = require(root.Parent.Feather)
local BoardState = require(root.BoardState)
local Binder = require(root.Util.Binder)
local ValueObject = require(root.Util.ValueObject)
local Sift = require(root.Parent.Sift)
local SurfaceCanvas = require(script.SurfaceCanvas)
local VRDrawingController = require(script.VRDrawingController)
local DrawingUI = require(root.DrawingUI)
local VRInput = require(script.VRInput)

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
	self.OpenedBoardPart = ValueObject.new(nil)

	self.BoardClientBinder:Init()
	self.SurfaceCanvasBinder:Init()
end

function Client:OpenBoard(part: Part)

	local board = self.BoardClientBinder:Get(part)
	if not board then
		return
	end

	DrawingUI(board, "Gui", function()
		-- This function is called when the Drawing UI is closed
		self.OpenedBoardPart.Value = nil
	end)

	self.OpenedBoardPart.Value = part
end

function Client:Start()
	self.BoardClientBinder:Start()
	self.SurfaceCanvasBinder:Start()

	self._surrenderedCanvasTrees = {}
	self.SurfaceCanvasBinder:GetClassRemovingSignal():Connect(function(surfaceCanvas)
		local canvasTree = surfaceCanvas:SurrenderCanvasTree()
		if canvasTree then
			table.insert(self._surrenderedCanvasTrees, canvasTree)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
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
