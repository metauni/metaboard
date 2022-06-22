-- Services
local Common = script.Parent

-- Imports
local Config = require(Common.Config)
local EraseGrid = require(Common.EraseGrid)
local Figure = require(Common.Figure)
local DrawingTask = require(Common.DrawingTask)
local History = require(Common.History)
local Signal = require(Common.Packages.GoodSignal)
local Destructor = require(Common.Packages.Destructor)
local Sift = require(Common.Packages.Sift)

-- Dictionary Operations
local Dictionary = Sift.Dictionary
local merge = Dictionary.merge

-- Board
local Board = {}
Board.__index = Board

function Board.new(instance: Model | Part, boardRemotes, persistId: string?, status: string)
	local self = setmetatable({
		_instance = instance,
		_surfacePart = instance:IsA("Model") and instance.PrimaryPart or instance,
		Remotes = boardRemotes,
		PlayerHistories = {},
		DrawingTasks = {},
		Figures = {},
		NextFigureZIndex = 0,
		PersistId = persistId,
		DataChangedSignal = Signal.new()
	}, Board)

	self._destructor = Destructor.new()

	self._status = status
	self.StatusChangedSignal = Signal.new()
	self._destructor:Add(function()
		self.StatusChangedSignal:DisconnectAll()
	end)


	do
		local faceValue = instance:FindFirstChild("Face")
		if faceValue then
			self.Face = faceValue.Value
		else
			self.Face = "Front"
		end
	end

	self.EraseGrid = EraseGrid.new(self:SurfaceSize().X / self:SurfaceSize().Y)

	return self
end


function Board:Status()
	return self._status
end

function Board:SetStatus(status: string)
	self.StatusChangedSignal:Fire(status)
	self._status = status
end

function Board:CommitAllDrawingTasks()

	local drawingTaskFigures = {}

	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.Type ~= "Erase" then
			drawingTaskFigures[taskId] = DrawingTask.Render(drawingTask)
		end
	end

	local allFigures = merge(self.Figures, drawingTaskFigures)

	local allMaskedFigures = allFigures
	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.Type == "Erase" then
			allMaskedFigures = DrawingTask.Commit(drawingTask, allMaskedFigures)
		end
	end

	return allMaskedFigures
end

function Board:LoadData(figures, drawingTasks, playerHistories, nextFigureZIndex)

	for userId, playerHistory in pairs(playerHistories) do
		setmetatable(playerHistory, History)
	end

	self.Figures = figures
	self.DrawingTasks = drawingTasks
	self.PlayerHistories = playerHistories
	self.NextFigureZIndex = nextFigureZIndex

	local eraseGrid = EraseGrid.new(self:SurfaceSize().X / self:SurfaceSize().Y)

	local committedFigures = self:CommitAllDrawingTasks()

	for figureId, figure in pairs(committedFigures) do
		eraseGrid:AddFigure(figureId, figure)
	end

	self.EraseGrid = eraseGrid

end

local _faceAngleCFrame = {
	Front  = CFrame.Angles(0, 0, 0),
	Left   = CFrame.Angles(0, math.pi / 2, 0),
	Back   = CFrame.Angles(0, math.pi, 0),
	Right  = CFrame.Angles(0, -math.pi / 2, 0),
	Top    = CFrame.Angles(math.pi / 2, 0, 0),
	Bottom = CFrame.Angles(-math.pi / 2, 0, 0)
}

local _faceSurfaceOffsetGetter = {
	Front  = function(size) return size.Z / 2 end,
	Left   = function(size) return size.X / 2 end,
	Back   = function(size) return size.Z / 2 end,
	Right  = function(size) return size.X / 2 end,
	Top    = function(size) return size.Y / 2 end,
	Bottom = function(size) return size.Y / 2 end
}

function Board:SurfaceCFrame()
	if self._surfacePart then

		return self._surfacePart.CFrame

	else

		return self._instance:GetPivot()
			* _faceAngleCFrame[self.Face]
			* CFrame.new(0, 0, -_faceSurfaceOffsetGetter[self.Face](self._surfacePart.Size))

	end
end

local _faceDimensionsGetter = {
	Front  = function(size) return Vector2.new(size.X, size.Y) end,
	Left   = function(size) return Vector2.new(size.Z, size.Y) end,
	Back   = function(size) return Vector2.new(size.X, size.Y) end,
	Right  = function(size) return Vector2.new(size.Z, size.Y) end,
	Top    = function(size) return Vector2.new(size.X, size.Z) end,
	Bottom = function(size) return Vector2.new(size.X, size.Z) end,
}

function Board:SurfaceSize()
	return _faceDimensionsGetter[self.Face](self._surfacePart.Size)
end

function Board:AspectRatio()
	local size = self:SurfaceSize()
	return size.X / size.Y
end

return Board