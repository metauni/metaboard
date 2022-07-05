-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Destructor = require(Common.Packages.Destructor)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary


-- Helper Functions
local setActive = require(script.setActive)
local setDormant = require(script.setDormant)
local setDead = require(script.setDead)
local kNearest = require(script.kNearest)
local visibilityDot = require(script.visibilityDot)

local LINEFRAMEBUDGET = 150

local ViewStateManager = {}
ViewStateManager.__index = ViewStateManager

function ViewStateManager.new()
	local self = setmetatable({}, ViewStateManager)

	self.Destructor = Destructor.new()

	-- board -> setActive() | setDormant() | setDead()
	self.ViewStates = {}

	self.Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

	self.CanvasesFolder = Instance.new("Folder")
	self.CanvasesFolder.Name = "ClientManagedCanvases"
	self.CanvasesFolder.Parent = workspace

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

	local numNotDead = Dictionary.count(boardToViewStatus, function(status)
		return status ~= "Dead"
	end)

	local getLineBudget = function()
		local boardBudget = LINEFRAMEBUDGET / numNotDead
		if self.BudgetThisFrame - boardBudget >= 0 then
			self.BudgetThisFrame -= boardBudget
			return boardBudget
		else
			return 0
		end
	end

	local viewStateSetter = {
		Active = setActive,
		Dormant = setDormant,
		Dead = setDead,
	}

	-- Set viewstate based on status
	self.ViewStates = Dictionary.map(boardToViewStatus, function(viewStatus, board)
		local viewState = self.ViewStates[board]
		if not viewState then
			viewState = setDead(board, nil, self.CanvasesFolder, getLineBudget)
		end
		return viewStateSetter[viewStatus](board, viewState, self.CanvasesFolder, getLineBudget)
	end)
end

function ViewStateManager:UpdateWithAllActive(instanceToBoard)
	local boardToViewStatus = Dictionary.map(instanceToBoard, function(board)
		return "Active", board
	end)

	self:_reconcileBoards(boardToViewStatus)
end

function ViewStateManager:UpdateWithBudget(instanceToBoard, lineBudget)
	local allBoards = Set.fromArray(Dictionary.values(instanceToBoard))

	local characterPos = self.Character:GetPivot().Position

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
