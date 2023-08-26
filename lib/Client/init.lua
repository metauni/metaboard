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
local Sift = require(root.Parent.Sift)
local SurfaceCanvas = require(script.SurfaceCanvas)
local DrawingUI = require(root.DrawingUI)
local BoardButton = require(script.BoardButton)
local VRInput = require(script.VRInput)
local GoodSignal = require(root.Parent.GoodSignal)

-- Constants
local LINE_LOAD_FRAME_BUDGET = 128

local Client = {
	Boards = {},
	SurfaceCanvases = {},
	BoardButtons = {},
	OpenedBoard = nil,
	VRInputs = {},

	BoardAdded = GoodSignal.new(),

	_canvasLoadingQueue = {},
}
Client.__index = Client


function Client:Start()
	
	-- VR Chalk

	if VRService.VREnabled then
		task.spawn(function()
			local chalk = ReplicatedStorage.Chalk:Clone()
			chalk.Parent = Players.LocalPlayer:WaitForChild("Backpack")
		end)
	end

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

			local loading = Sift.Dictionary.filter(self.SurfaceCanvases, function(surfaceCanvas, instance)

				local isLoading = instance and instance:IsDescendantOf(workspace) and surfaceCanvas.Loading

				return isLoading
			end)
		
			local characterPos = character:GetPivot().Position
			self._canvasLoadingQueue = {}

			-- Sort the loading canvases by distance and store them in self._canvasLoadingQueue
			do
				local nearestSet = {}

				while true do
					local minSoFar = math.huge
					local nearestCanvas = nil
					for _, surfaceCanvas in loading do
						if nearestSet[surfaceCanvas] then
							continue
						end

						local board = surfaceCanvas.Board

						local distance = (board.SurfaceCFrame.Position - characterPos).Magnitude
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

	-- Constantly connect VRInput objects to whatever boards are "inRange"

	if VRService.VREnabled then

		local function inRange(board)

			if not board or not board._instance:IsDescendantOf(workspace) then
				return false
			end

			local boardLookVector = board.SurfaceCFrame.LookVector
			local boardRightVector = board.SurfaceCFrame.RightVector

			local character = Players.LocalPlayer.Character
			if character then
				local characterVector = character:GetPivot().Position - board.SurfaceCFrame.Position
				local normalDistance = boardLookVector:Dot(characterVector)

				local strafeDistance = boardRightVector:Dot(characterVector)
				return (0 <= normalDistance and normalDistance <= 20) and math.abs(strafeDistance) <= board.SurfaceSize.X/2 + 5
			end
		end
			

		task.spawn(function()
			
			while true do

				-- Destroy VRInputs out of range of board or for dead boards

				self.VRInputs = Sift.Dictionary.filter(self.VRInputs, function(vrInput, instance)
					
					local surfaceCanvas = self.SurfaceCanvases[instance]

					if not surfaceCanvas or not inRange(self.Boards[instance]) then
						vrInput:Destroy()

						if surfaceCanvas then
							surfaceCanvas:render()
						end
						return false
					end
					return true
				end)

				-- Add new VRInputs that are in range

				for instance, surfaceCanvas in self.SurfaceCanvases do

					if self.VRInputs[instance] then
						continue
					end

					local isInRange = inRange(surfaceCanvas.Board)
		
					if isInRange then
						self.VRInputs[instance] = VRInput.new(surfaceCanvas.Board, surfaceCanvas)
					end
				end
	
				task.wait(1)
			end
		end)
	end

	-- Load Surface Canvases gradually, prioritised by proximity and visibility
	RunService.Heartbeat:Connect(function()

		local closestLoading
		local closestInFOV
		local closestVisible
		
		for _, surfaceCanvas in ipairs(self._canvasLoadingQueue) do

			local board = surfaceCanvas.Board
			
			if surfaceCanvas.Loading then
				closestLoading = closestLoading or surfaceCanvas

				local boardPos = board.SurfaceCFrame.Position
				local _, inFOV = workspace.CurrentCamera:WorldToViewportPoint(boardPos)
				
				if inFOV then
					closestInFOV = closestInFOV or surfaceCanvas

					if board.SurfaceCFrame.LookVector:Dot(workspace.CurrentCamera.CFrame.LookVector) < 0 then
						closestVisible = closestVisible or surfaceCanvas
						break
					end
				end
			end
		end

		local canvasToLoad = closestVisible or closestInFOV or closestLoading
		if canvasToLoad then
			canvasToLoad:LoadMore(LINE_LOAD_FRAME_BUDGET)
		end
	end)

	--------------------------------------------------------------------------------
	
	local function onRemoved(instance)
		
		local boardButton = self.BoardButtons[instance]
		local surfaceCanvas = self.SurfaceCanvases[instance]
		local board = self.Boards[instance]
		
		if boardButton then
			boardButton:Destroy()
		end
		if surfaceCanvas then
			surfaceCanvas:Destroy()
		end
		if board then
			board:Destroy()
		end

		self.BoardButtons[instance] = nil
		self.SurfaceCanvases[instance] = nil
		self.Boards[instance] = nil
	end

	local function bindInstanceAsync(instance: Part)

		if not instance:IsDescendantOf(workspace) and not instance:IsDescendantOf(ReplicatedStorage) then
			onRemoved(instance)
			return
		end

		assert(instance:IsA("Part"), "[metaboard] Tagged instance must be a Part")
	
		-- Ignore if already seen this board
		if self.Boards[instance] then
			return
		end
	
		if not instance:GetAttribute("BoardServerInitialised") then
			
			instance:GetAttributeChangedSignal("BoardServerInitialised"):Wait()
		end
	
		local board = BoardClient.new(instance)
		
		local data = board.Remotes.GetBoardData:InvokeServer()
		
		board:LoadData(data)
		
		board:ConnectRemotes()
	
		self.Boards[instance] = board
		self.SurfaceCanvases[instance] = SurfaceCanvas.new(board)
		self.BoardButtons[instance] = BoardButton.new(board, self.OpenedBoard == nil, function()
			
			-- This is the default function called when the boardButton is clicked.
			-- Can be temporarily overwritten by setting boardButton.OnClick

			for _, boardButton in self.BoardButtons do
				boardButton:SetActive(false)
			end
			
			DrawingUI(board, "Gui", function()
				-- This function is called when the Drawing UI is closed
				self.OpenedBoard = nil
				for _, boardButton in self.BoardButtons do
					boardButton:SetActive(true)
				end
			end)

			self.OpenedBoard = board
		end)

		self.BoardAdded:Fire(board)
	end
	
	-- Bind regular metaboards with streaming radius (or based on chosen board Ancestor)

	local boardAncestorValue = ReplicatedStorage:FindFirstChild("BoardAncestor")
	local ATTACHED_RADIUS = 64
	local ROAMING_STREAM_IN_RADIUS = 128
	local ROAMING_STREAM_OUT_RADIUS = 256
	
	if typeof(boardAncestorValue) == "Instance" and boardAncestorValue:IsA("ObjectValue") then
		task.spawn(function()
			while true do
				task.wait(2)
	
				local character = Players.LocalPlayer.Character
				if not character or not character.PrimaryPart then
					return
				end
				for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
					if boardAncestorValue.Value then
						if instance:IsDescendantOf(boardAncestorValue.Value) then
							if not self.Boards[instance] then
								task.spawn(bindInstanceAsync, instance)
							end
						--selene:allow(if_same_then_else)
						elseif (instance.Position - character:GetPivot().Position).Magnitude < ATTACHED_RADIUS then
							if not self.Boards[instance] then
								task.spawn(bindInstanceAsync, instance)
							end
						else
							if self.Boards[instance] then
								task.spawn(onRemoved, instance)
							end
						end
					else -- Just stream based on radius
						if self.Boards[instance] and (instance.Position - character:GetPivot().Position).Magnitude >= ROAMING_STREAM_OUT_RADIUS then
							task.spawn(onRemoved, instance)
						elseif not self.Boards[instance] and (instance.Position - character:GetPivot().Position).Magnitude < ROAMING_STREAM_IN_RADIUS then
							task.spawn(bindInstanceAsync, instance)
						end
						
					end
				end
			end
		end)

	else
		if boardAncestorValue ~= nil then
			warn("Bad BoardAncestor ObjectValue")
		end
		CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(bindInstanceAsync)

		for _, instance in CollectionService:GetTagged(Config.BoardTag) do
			task.spawn(bindInstanceAsync, instance)
		end
	end

	CollectionService:GetInstanceRemovedSignal(Config.BoardTag):Connect(onRemoved)
end

function Client:GetBoard(instance: Part)
	return self.Boards[instance]
end

function Client:WaitForBoard(instance: Part)
	if self.Boards[instance] then
		return self.Boards[instance]
	end
	while true do
		local board = self.BoardAdded:Wait()
		if board._instance == instance then
			return board
		end
	end
end

return Client
