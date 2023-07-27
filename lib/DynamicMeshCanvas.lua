local root = script.Parent
local Config = require(root.Config)

local DynamicMeshCanvas = {}
DynamicMeshCanvas.__index = DynamicMeshCanvas

function DynamicMeshCanvas.new(board)
	local self = setmetatable({}, DynamicMeshCanvas)

	self._board = board
	return self
end

function DynamicMeshCanvas:_vertices(p0: Vector2, p1: Vector2, width: number, zIndex: number)
	
	local function lerp(a, b, t)
		if t < 0.5 then
			return a + (b - a) * t
		else
			return b - (b - a) * (1 - t)
		end
	end

	if p0 == p1 then
		p0 = p0 + Vector2.new(-width/2, 0)
		p1 = p1 + Vector2.new(width/2, 0)
	end

	local perp = -Vector2.new((p1-p0).Y, -(p1-p0).X).Unit
	
	local sizeX = self._board.SurfaceSize.X
	local sizeY = self._board.SurfaceSize.Y
	local aspectRatio = sizeX / sizeY

	local z =
		- Config.SurfaceCanvas.ZThicknessStuds / 2
		- Config.SurfaceCanvas.InitialZOffsetStuds
		- zIndex * Config.SurfaceCanvas.StudsPerZIndex
	local v1 = Vector3.new(
		lerp(sizeX / 2, -sizeX / 2, (p0 + perp * width).X / aspectRatio), 
		lerp(sizeY / 2, -sizeY / 2, (p0 + perp * width).Y),
		z
	)
	local v2 = Vector3.new(
		lerp(sizeX / 2, -sizeX / 2, (p0 - perp * width).X / aspectRatio), 
		lerp(sizeY / 2, -sizeY / 2, (p0 - perp * width).Y),
		z
	)
	local v3 = Vector3.new(
		lerp(sizeX / 2, -sizeX / 2, (p1 + perp * width).X / aspectRatio), 
		lerp(sizeY / 2, -sizeY / 2, (p1 + perp * width).Y),
		z
	)
	local v4 = Vector3.new(
		lerp(sizeX / 2, -sizeX / 2, (p1 - perp * width).X / aspectRatio), 
		lerp(sizeY / 2, -sizeY / 2, (p1 - perp * width).Y),
		z
	)
	
	return v1, v2, v3, v4
end

local function pivot(v: Vector3, radians: number)
	return Vector3.new(
		v.X * math.cos(radians) + v.Z * math.sin(radians),
		v.Y,
		v.X * -math.sin(radians) + v.Z * math.cos(radians)
	)
end

function DynamicMeshCanvas:_writeFigureToMesh(figure, mesh: DynamicMesh)
	for i=1, #figure.Points-1 do
		local p0, p1 = figure.Points[i], figure.Points[i+1]
		if not (p0 and p1) then
			continue
		end

		local v1, v2, v3, v4 = self:_vertices(p0, p1, figure.Width, figure.ZIndex)

		-- Workaround for bug when making axis-aligned meshes
		v1 = pivot(v1, math.pi/4)
		v2 = pivot(v2, math.pi/4)
		v3 = pivot(v3, math.pi/4)
		v4 = pivot(v4, math.pi/4)

		local u = v2 - v1
		local v = v3 - v1
		local normal = u:Cross(v).Unit
		
		local index1 = mesh:AddVertex(v1)
		mesh:SetVertexColor(index1, figure.Color)
		local index2 = mesh:AddVertex(v2)
		mesh:SetVertexColor(index2, figure.Color)
		local index3 = mesh:AddVertex(v3)
		mesh:SetVertexColor(index3, figure.Color)
		local index4 = mesh:AddVertex(v4)
		mesh:SetVertexColor(index4, figure.Color)

		mesh:SetVertexNormal(index1, normal)
		mesh:SetVertexNormal(index2, normal)
		mesh:SetVertexNormal(index3, normal)
		mesh:SetVertexNormal(index4, normal)

		mesh:AddTriangle(index1, index4, index2)
		mesh:AddTriangle(index1, index3, index4)
	end
end

-- Returns a Model containing one mesh per curve
function DynamicMeshCanvas:CurvesModelAsync(): Model

	local model = Instance.new("Model")
	for figureId, figure in self._board.Figures do

		local dynamicMesh = Instance.new("DynamicMesh")
		self:_writeFigureToMesh(figure, dynamicMesh)
		if #dynamicMesh:GetVertices() == 0 then
			continue
		end

		dynamicMesh.Parent = workspace
		local figuresPart = dynamicMesh:CreateMeshPartAsync(Enum.CollisionFidelity.Box)
		dynamicMesh:Destroy()

		figuresPart.CanCollide = false
		figuresPart.Anchored = true
		figuresPart.Material = Enum.Material.Neon

		-- correct for pivot
		figuresPart.CFrame = self._board.SurfaceCFrame * CFrame.Angles(0, -math.pi/4, 0)
		figuresPart.Name = figureId
		figuresPart.Parent = model
	end

	return model
end

-- Returns a meshpart for the whole canvas
function DynamicMeshCanvas:CanvasModelAsync(): Model

	local model = Instance.new("Model")
	local dynamicMesh = Instance.new("DynamicMesh")
	for _, figure in self._board.Figures do
		self:_writeFigureToMesh(figure, dynamicMesh)
	end

	local success, numTriangles = pcall(function()
		return #dynamicMesh:GetVertices() == 0
	end)

	if not success or numTriangles == 0 then
		return model
	end

	dynamicMesh.Parent = workspace
	local figuresPart = dynamicMesh:CreateMeshPartAsync(Enum.CollisionFidelity.Box)
	dynamicMesh:Destroy()

	figuresPart.CanCollide = false
	figuresPart.Anchored = true
	figuresPart.Material = Enum.Material.Neon

	-- correct for pivot
	figuresPart.CFrame = self._board.SurfaceCFrame * CFrame.Angles(0, -math.pi/4, 0)
	figuresPart.Parent = model

	return model
end

return DynamicMeshCanvas