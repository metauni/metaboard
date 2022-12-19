-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Destructor = require(Common.Destructor)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary

-- Helper Functions
local setActive = require(script.setActive)
local setDead = require(script.setDead)
local kNearest = require(script.kNearest)
local visibilityDot = require(script.visibilityDot)

local LINEFRAMEBUDGET = 50

local ViewStateManager = {}
ViewStateManager.__index = ViewStateManager

function ViewStateManager.new()
	local self = setmetatable({}, ViewStateManager)

	self.Destructor = Destructor.new()

	-- board -> setActive() | setDormant() | setDead()
	self.ViewStates = {}

	RunService.Heartbeat:Connect(function()
		if self.BoardsToLoadThisFrame and #self.BoardsToLoadThisFrame > 0 then

			local boardToLoad do

				local closestLoading
				local closestInFOV
				local closestVisible

				for i, board in ipairs(self.BoardsToLoadThisFrame) do

					local viewState = self.ViewStates[board]
					if viewState.WhenLoaded then
						closestLoading = closestLoading or board
					end

					local boardPos = board.SurfaceCFrame.Position
					local _, inFOV = workspace.CurrentCamera:WorldToViewportPoint(boardPos)
					if inFOV then
						closestInFOV = closestInFOV or board

						if board.SurfaceCFrame.LookVector:Dot(workspace.CurrentCamera.CFrame.LookVector) < 0 then
							closestVisible = closestVisible or board
							break
						end
					end
				end

				boardToLoad = closestVisible or closestInFOV or closestLoading
			end

			if boardToLoad then
				local viewState = self.ViewStates[boardToLoad]

				viewState.LoadMore(128)

				if viewState.WhenLoaded == nil then
					self.BoardsToLoadThisFrame = Array.removeValue(self.BoardsToLoadThisFrame, boardToLoad)
				end
			end
		end

	end)

	self.CanvasesFolder = Instance.new("Folder")
	self.CanvasesFolder.Name = "ClientManagedCanvases"
	self.CanvasesFolder.Parent = workspace

	self.CanvasStorage = Instance.new("Folder")
	self.CanvasStorage.Name = "ClientCanvasStorage"
	self.CanvasStorage.Parent = ReplicatedStorage

	self.BudgetThisFrame = LINEFRAMEBUDGET

	self.Destructor:Add(RunService.RenderStepped:Connect(function()
		self.BudgetThisFrame = LINEFRAMEBUDGET
	end))

	return self
end

function ViewStateManager:OnBoardChange(board)
	local viewState = self.ViewStates[board]
	if viewState and viewState.Status == "Active" then
		viewState.DoUpdate()
	end
end

--[[
	Update viewStates based on the status of each board.
--]]
function ViewStateManager:_reconcileBoards(boardToViewStatus)

	-- Destroy all no-longer existing boards
	for board, viewState in pairs(self.ViewStates) do
		if boardToViewStatus[board] == nil then
			viewState.Destroy()
		end
	end

	do
		local loadingBoards = Dictionary.map(self.ViewStates, function(state, board)
			return state.WhenLoaded, board
		end)

		local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		local characterPos = character:GetPivot().Position
		local kNearestArray, kNearestSet = kNearest(characterPos, loadingBoards, math.huge)

		self.BoardsToLoadThisFrame = kNearestArray
	end

	local viewStateSetter = {
		Active = setActive,
		Dead = setDead,
	}

	-- Set viewstate based on status
	self.ViewStates = Dictionary.map(boardToViewStatus, function(viewStatus, board)

		local viewState = self.ViewStates[board]

		if not viewState then
			viewState = setDead(self, board, nil)
		end

		if viewStatus == viewState.Status then
			return viewState
		else
			return viewStateSetter[viewStatus](self, board, viewState)
		end

	end)
end

function ViewStateManager:RefreshViewStates()
	local viewStateSetter = {
		Active = setActive,
		Dead = setDead,
	}

	self.ViewStates = Dictionary.map(self.ViewStates, function(viewState, board)
		return viewStateSetter[viewState.Status](self, board, viewState)
	end)
end

function ViewStateManager:UpdateWithAllActive(instanceToBoard)
	local boardToViewStatus = Dictionary.map(instanceToBoard, function(board)
		return "Active", board
	end)

	self:_reconcileBoards(boardToViewStatus)
end

function ViewStateManager:UpdateWithAllDead(instanceToBoard)
	local boardToViewStatus = Dictionary.map(instanceToBoard, function(board)
		return "Dead", board
	end)

	self:_reconcileBoards(boardToViewStatus)
end

function ViewStateManager:UpdateWithBudget(instanceToBoard, lineBudget)
	local allBoards = Set.fromArray(Dictionary.values(instanceToBoard))

	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	local characterPos = character:GetPivot().Position

	local nearestArray, _ = kNearest(characterPos, allBoards, Set.count(allBoards))

	local boardToViewStatus = {}

	local totalLineCount = 0
	for i, board in ipairs(nearestArray) do
		totalLineCount += board:LinesForBudget()

		if totalLineCount <= lineBudget or i==1 then

			if - visibilityDot(board, characterPos) >= 50 then
				boardToViewStatus[board] = true and "Active"
			else
				boardToViewStatus[board] = "Active"
			end

		else
			boardToViewStatus[board] = "Dead"
		end
	end

	self:_reconcileBoards(boardToViewStatus)
end

return ViewStateManager