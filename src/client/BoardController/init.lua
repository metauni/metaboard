-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local Players = game:GetService("Players")

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Destructor = require(Common.Packages.Destructor)
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local SurfaceCanvas = require(script.SurfaceCanvas)

-- Helper Functions
local dormantBoardUpdater = require(script.dormantBoardUpdater)
local extractHostObject = require(script.extractHostObject)

local BoardController = {}
BoardController.__index = BoardController

local ACTIVE_RADIUS = 100
local DORMANT_RADIUS = 100
local NUM_NEAREST_ACTIVE = 5

function BoardController.new()
	local self = setmetatable({}, BoardController)

	self.Destructor = Destructor.new()

	-- board -> {Tree: RoactTree?, Canvas: Model, numNewFigures: number}
	self.BoardInfo = {}
	-- [Board]
	self.LastOpened = {}

	self.Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	self.Character:WaitForChild("HumanoidRootPart")

	self.CanvasesFolder = Instance.new("Folder")
	self.CanvasesFolder.Name = "ClientManagedCanvases"
	self.CanvasesFolder.Parent = workspace

	return self
end

local function nearestBoards(position: Vector3, boards, k)
	local nearest = table.create(k, nil)
	local nearestSet = {}

	for i = 1, k do
		local minSoFar = math.huge
		local nearestBoard = nil
		for board in pairs(boards) do
			if nearestSet[board] then
				continue
			end

			local distance = (board:SurfaceCFrame().Position - position).Magnitude
			if distance < minSoFar then
				nearestBoard = board
				minSoFar = distance
			end
		end

		if nearestBoard then
			table.insert(nearest, nearestBoard)
			nearestSet[nearestBoard] = true
		else
			break
		end
	end

	return nearestSet
end

function BoardController:_reconcileBoards(activeBoards, dormantBoards, allBoards)
	-- Unmount trees and destroy canvases of non-existing boards
	for board, info in pairs(self.BoardInfo) do
		if not allBoards[board] then
			if info.Tree then
				Roact.unmount(info.Tree)
			end

			if info.Canvas then
				info.Canvas:Destroy()
			end
		end
	end

	self.BoardInfo = Dictionary.filter(self.BoardInfo, function(info, board)
		return allBoards[board]
	end)

	for board in pairs(allBoards) do
		local info = self.BoardInfo[board]
		local wasActive = info and info.Tree
		local wasDormant = not wasActive and info and info.Canvas
		local nowActive = activeBoards[board]
		local nowDormant = dormantBoards[board]
		local wasDead = not (wasActive or wasDormant)
		local nowDead = not (nowActive or nowDormant)

		if (wasActive and nowActive) or (wasDormant and nowDormant) or (wasDead and nowDead) then
			if nowDormant then
				dormantBoardUpdater(
					self.BoardInfo[board].Canvas,
					board,
					self.BoardInfo[board].Figures,
					self.BoardInfo[board].DrawingTasks
				)
				self.BoardInfo[board].Figures = board.Figures
				self.BoardInfo[board].DrawingTasks = board.DrawingTasks
			end
			continue
		end

		if nowDead then
			print(board._instance.Name .. ": active|dormant -> dead")
			if info.Canvas then
				info.Canvas:Destroy()
			end

			if info.UpdateConnection then
				info.UpdateConnection:Disconnect()
			end

			self.BoardInfo[board] = nil
			continue
		end

		if wasActive and nowDormant then
			print(board._instance.Name .. ": active -> dormant")
			-- Active -> Dormant. Disconnect the updater and Dump the tree
			-- Disconnect updater
			if self.BoardInfo[board].UpdateConnection then
				self.BoardInfo[board].UpdateConnection:Disconnect()
			end

			self.BoardInfo[board].Figures = board.Figures
			self.BoardInfo[board].DrawingTasks = board.DrawingTasks

			self.BoardInfo[board].Tree = nil
			continue
		end

		if nowActive then
			print(board._instance.Name .. ": dead|dormant -> active")
		end
		if nowDormant then
			print(board._instance.Name .. ": dead -> dormant")
		end

		local oldCanvas = info and info.Canvas

		local element = e(SurfaceCanvas, {

			Board = board,
			LineLoadFinishedCallback = function()
				if oldCanvas then
					oldCanvas:Destroy()
				end
			end,
		})

		local tree = Roact.mount(element, self.CanvasesFolder, board._instance.Name)

		self.BoardInfo[board] = {
			Tree = nowActive and tree or nil,
			Canvas = extractHostObject(tree),
		}

		if nowActive then
			local connection = board.DataChangedSignal:Connect(function()
				local updatedElement = e(SurfaceCanvas, {

					Board = board,
					LineLoadFinishedCallback = function()
						if oldCanvas then
							oldCanvas:Destroy()
						end
					end,
				})

				Roact.update(tree, updatedElement)
			end)

			self.BoardInfo[board].UpdateConnection = connection
		end
		
		if nowDormant then
			self.BoardInfo[board].Figures = board.Figures
			self.BoardInfo[board].DrawingTasks = board.DrawingTasks
		end

	end
end

function BoardController:Update(instanceToBoard)
	local allBoards = Set.fromArray(Dictionary.values(instanceToBoard))

	local characterPos = self.Character:WaitForChild("HumanoidRootPart").Position

	local activeRadiusBoards = Set.filter(allBoards, function(board)
		return (board:SurfaceCFrame().Position - characterPos).Magnitude <= ACTIVE_RADIUS
	end)

	local nearest = nearestBoards(characterPos, activeRadiusBoards, NUM_NEAREST_ACTIVE)
	local recent = Set.fromArray(self.LastOpened)

	local activeBoards = Set.union(nearest, recent)
	local dormantBoards = Set.filter(allBoards, function(board)
		local distance = (board:SurfaceCFrame().Position - characterPos).Magnitude
		return distance > ACTIVE_RADIUS and distance <= DORMANT_RADIUS
	end)

	self:_reconcileBoards(activeBoards, dormantBoards, allBoards)
	-- self:_reconcileBoards(allBoards, {}, allBoards)
end

return BoardController
