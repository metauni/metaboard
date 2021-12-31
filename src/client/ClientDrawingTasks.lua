local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DrawingTask = require(Common.DrawingTask)
local Config = require(Common.Config)
local Cache = require(Common.Cache)
local Drawing
local CanvasState
local Curves
local CatRom = require(Common.Packages.CatRom)
local LineInfo = require(Common.LineInfo)

local LocalPlayer = game:GetService("Players").LocalPlayer

local ClientDrawingTasks = {}
ClientDrawingTasks.__index = ClientDrawingTasks

function ClientDrawingTasks.Init(curvesContainer)
	Drawing = require(script.Parent.Drawing)
	CanvasState = require(script.Parent.CanvasState)
	Curves = curvesContainer
end

function ClientDrawingTasks.new(taskKind)
	return ClientDrawingTasks[taskKind].new()
end

ClientDrawingTasks.FreeHand = {}
ClientDrawingTasks.FreeHand.__index = ClientDrawingTasks.FreeHand

function ClientDrawingTasks.FreeHand.new()

	local init = function(state, pos)
		local zIndex = CanvasState.EquippedBoard.CurrentZIndex.Value + 1

		state.Curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, Config.CurveNamer(LocalPlayer, Drawing.CurveIndexOf[CanvasState.EquippedBoard]), zIndex)
		state.Curve.Parent = Curves

		state.Points = {pos}

		local lineInfo =
			LineInfo.new(
				pos,
				pos,
				Drawing.EquippedTool.ThicknessYScale,
				Drawing.EquippedTool.Color
			)
		local lineFrame = CanvasState.CreateLineFrame(lineInfo)

		LineInfo.StoreInfo(lineFrame, lineInfo)
		CanvasState.AttachLine(lineFrame, state.Curve)

		state.LastLine = lineFrame
		state.LastLineInfo = lineInfo
		state.CurveLength = 0

		DrawingTask.InitRemoteEvent:FireServer(
			CanvasState.EquippedBoard,
			"FreeHand",
			pos,
			Drawing.EquippedTool.ThicknessYScale,
			Drawing.EquippedTool.Color,
			Config.CurveNamer(LocalPlayer, Drawing.CurveIndexOf[CanvasState.EquippedBoard])
		)
	end

	local update = function(state, pos)

		local lineInfo =
		LineInfo.new(
			state.LastLineInfo.Stop,
			pos,
			Drawing.EquippedTool.ThicknessYScale,
			Drawing.EquippedTool.Color
		)
		
		if #state.Points == 1 then
			CanvasState.UpdateLineFrame(state.LastLine, lineInfo)
		else
			local lineFrame = CanvasState.CreateLineFrame(lineInfo)
			LineInfo.StoreInfo(lineFrame, lineInfo)
			CanvasState.AttachLine(lineFrame, state.Curve)
			state.LastLine = lineFrame
		end

		state.LastLineInfo = lineInfo
		state.CurveLength += lineInfo.Length
		
		table.insert(state.Points, pos)
		DrawingTask.UpdateRemoteEvent:FireServer(pos)
	end

	local finish = function(state)

		if Config.SmoothingAlgorithm == "CatRom" then

			if #state.Points <= 2 then return end

			local chain = CatRom.Chain.new(state.Points)

			for _, lineFrame in CanvasState.GetLinesContainer(state.Curve) do
				CanvasState.DiscardLineFrame(lineFrame)
			end

			local smoothPoints = {chain:SolvePosition(0)}

			for i=1, state.CurveLength/Config.CatRomLength - 1 do
					local lineInfo =
						LineInfo.new(
							chain:SolvePosition((i-1)/(state.CurveLength/Config.CatRomLength - 1)),
							chain:SolvePosition(i/(state.CurveLength/Config.CatRomLength - 1)),
							Drawing.EquippedTool.ThicknessYScale,
							Drawing.EquippedTool.Color
						)
					local lineFrame = CanvasState.CreateLineFrame(lineInfo)

					LineInfo.StoreInfo(lineFrame, lineInfo)
					CanvasState.AttachLine(lineFrame, state.Curve)

					table.insert(smoothPoints, chain:SolvePosition(i/(state.CurveLength/Config.CatRomLength - 1)))
			end

			DrawingTask.FinishRemoteEvent:FireServer(true, smoothPoints)

		elseif Config.SmoothingAlgorithm == "DouglasPeucker" then

			if #state.Points <= 2 then return end

			Drawing.DouglasPeucker(state.Points, 1, #state.Points, Config.DouglasPeuckerEpsilon)

			for _, lineFrame in CanvasState.GetLinesContainer(state.Curve) do
				CanvasState.DiscardLineFrame(lineFrame)
			end

			local smoothPoints = {}

			local i = 1
			while i <= #state.Points and state.Points[i] == nil do i += 1 end

			while i <= #state.Points do
				table.insert(smoothPoints, state.Points[i])
				local j = i+1
				while j <= #state.Points and state.Points[j] == nil do j += 1 end
				if state.Points[j] then
					local lineInfo =
						LineInfo.new(
							state.Points[i],
							state.Points[j],
							Drawing.EquippedTool.ThicknessYScale,
							Drawing.EquippedTool.Color
						)
					local lineFrame = CanvasState.CreateLineFrame(lineInfo)

					LineInfo.StoreInfo(lineFrame, lineInfo)
					CanvasState.AttachLine(lineFrame, state.Curve)
				end
				i = j
			end

			DrawingTask.FinishRemoteEvent:FireServer(true, smoothPoints)
		end
	end

	return DrawingTask.new(init, update, finish)
end


ClientDrawingTasks.StraightLine = {}
ClientDrawingTasks.StraightLine.__index = ClientDrawingTasks.StraightLine

function ClientDrawingTasks.StraightLine.new()

	local init = function(state, pos)
		local zIndex = CanvasState.EquippedBoard.CurrentZIndex.Value + 1

		state.Curve = CanvasState.CreateCurve(CanvasState.EquippedBoard, Config.CurveNamer(LocalPlayer, Drawing.CurveIndexOf[CanvasState.EquippedBoard]), zIndex)
		state.Curve.Parent = Curves

		local lineInfo =
			LineInfo.new(
				pos,
				pos,
				Drawing.EquippedTool.ThicknessYScale,
				Drawing.EquippedTool.Color
			)
		local lineFrame = CanvasState.CreateLineFrame(lineInfo)

		LineInfo.StoreInfo(lineFrame, lineInfo)

		CanvasState.AttachLine(lineFrame, state.Curve)

		state.LineFrame = lineFrame
		state.LineInfo = lineInfo
		DrawingTask.InitRemoteEvent:FireServer(
			CanvasState.EquippedBoard,
			"StraightLine",
			pos,
			Drawing.EquippedTool.ThicknessYScale,
			Drawing.EquippedTool.Color,
			Config.CurveNamer(LocalPlayer, Drawing.CurveIndexOf[CanvasState.EquippedBoard])
		)
	end

	local update = function(state, pos)
		local lineInfo =
		LineInfo.new(
			state.LineInfo.Start,
			pos,
			Drawing.EquippedTool.ThicknessYScale,
			Drawing.EquippedTool.Color
		)
		CanvasState.UpdateLineFrame(state.LineFrame, lineInfo)
		state.LineInfo = lineInfo
		LineInfo.StoreInfo(state.LineFrame, lineInfo)

		DrawingTask.UpdateRemoteEvent:FireServer(pos)
	end

	local finish = function(state) end

	return DrawingTask.new(init, update, finish)
end


ClientDrawingTasks.Erase = {}
ClientDrawingTasks.Erase.__index = ClientDrawingTasks.Erase

function ClientDrawingTasks.Erase.RemoveIntersectingLines(pos)
	local curveLineInfoBundles = {}

	for _, curve in ipairs(Curves:GetChildren()) do
		local lineInfos = {}
		for _, lineFrame in ipairs(CanvasState.GetLinesContainer(curve):GetChildren()) do
			local lineInfo = LineInfo.ReadInfo(lineFrame)
			if CanvasState.Intersects(
					pos,
					Drawing.EquippedTool.ThicknessYScale/2,
					lineInfo) then

				CanvasState.DiscardLineFrame(lineFrame)
				table.insert(lineInfos, lineInfo)
			end
		end
		if #lineInfos > 0 then
			curveLineInfoBundles[curve.Name] = lineInfos
		end
		if #CanvasState.GetLinesContainer(curve):GetChildren() == 0 then
			CanvasState.DiscardCurve(curve)
		end
	end

	return curveLineInfoBundles
end


function ClientDrawingTasks.Erase.new()

	local init = function(state, pos)
		local curveLineInfoBundles = ClientDrawingTasks.Erase.RemoveIntersectingLines(pos)
		DrawingTask.InitRemoteEvent:FireServer(CanvasState.EquippedBoard, "Erase", curveLineInfoBundles)
	end

	local update = function(state, pos)
		local curveLineInfoBundles = ClientDrawingTasks.Erase.RemoveIntersectingLines(pos)

		-- Check if the table is non-empty
		if next(curveLineInfoBundles) then
			DrawingTask.UpdateRemoteEvent:FireServer(curveLineInfoBundles)
		end
	end

	local finish = function(state, pos)
		DrawingTask.FinishRemoteEvent:FireServer()
	end

	return DrawingTask.new(init, update, finish)
end

ClientDrawingTasks.Clear = {}
ClientDrawingTasks.Clear.__index = ClientDrawingTasks.Clear

function ClientDrawingTasks.Clear.new()
	local init = function(state)

		for _, curve in ipairs(Curves:GetChildren()) do
			CanvasState.DiscardCurve(curve)
		end
		DrawingTask.InitRemoteEvent:FireServer(CanvasState.EquippedBoard, "Clear")
	end

	local update = function(state) end

	local finish = function(state)
		DrawingTask.FinishRemoteEvent:FireServer()
	end

	return DrawingTask.new(init, update, finish)
end


return ClientDrawingTasks