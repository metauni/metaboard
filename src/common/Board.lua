-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Config = require(Common.Config)
local EraseGrid = require(Common.EraseGrid)
local Figure = require(Common.Figure)

-- Board
local Board = {}
Board.__index = Board

function Board.new(instance: Model | Part, boardRemotes, persistId: string?)
	local self = setmetatable({
		_instance = instance,
		_surfacePart = instance:IsA("Model") and instance.PrimaryPart or instance,
		Remotes = boardRemotes,
		PlayerHistory = {},
		DrawingTasks = {},
		Figures = {},
		NextFigureZIndex = 0,
		PersistId = persistId
	}, Board)


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

function Board:Serialise()
	local figures = table.clone(self.Figures)

	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.TaskType ~= "Erase" then
			figures[taskId] = drawingTask:Render()
		end
	end

	for taskId, drawingTask in pairs(self.DrawingTasks) do
		if drawingTask.TaskType == "Erase" then
			drawingTask:Commit(figures)
		end
	end

	local serialisedFigures = {}

	for figureId, figure in pairs(figures) do
		serialisedFigures[figureId] = Figure.Serialise(figure)
	end

	return {
		Figures = serialisedFigures,
		NextFigureZIndex = self.NextFigureZIndex,
	}

end

function Board.Deserialise(boardData)
	local figures = {}

	for figureId, figure in pairs(boardData.Figures) do
		figures[figureId] = Figure.Deserialise(figure)
	end

	return {
		Figures = figures,
		NextFigureZIndex = boardData.NextFigureZIndex,
	}

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

return Board