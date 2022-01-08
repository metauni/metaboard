local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DrawingTask = require(Common.DrawingTask)
local Config = require(Common.Config)
local LineInfo = require(Common.LineInfo)
local MetaBoard

local ServerDrawingTasks = {}
ServerDrawingTasks.__index = ServerDrawingTasks

function ServerDrawingTasks.Init()
	MetaBoard = require(script.Parent.MetaBoard)
end

ServerDrawingTasks.FreeHand = {}
ServerDrawingTasks.FreeHand.__index = ServerDrawingTasks.FreeHand

function ServerDrawingTasks.FreeHand.Init(board, curve, authorUserId, thicknessYScale, color, zIndex, pos)
	curve:SetAttribute("TaskType", "FreeHand")

	curve:SetAttribute("AuthorUserId", authorUserId)
	curve:SetAttribute("Color", color)
	curve:SetAttribute("ThicknessYScale", thicknessYScale)
	curve:SetAttribute("ZIndex", zIndex)

	curve:SetAttribute("CurveStop", pos)

	local lineInfo = LineInfo.new(pos, pos, thicknessYScale, color)
	local worldLine = MetaBoard.CreateWorldLine(Config.WorldBoard.LineType, board.Canvas, lineInfo, zIndex)
	worldLine.Name = "1"
	worldLine.Parent = curve
	
	board.CurrentZIndex.Value += 1
end

function ServerDrawingTasks.FreeHand.Update(board, curve, pos)
	local lineInfo =
		LineInfo.new(
			curve:GetAttribute("CurveStop"),
			pos,
			curve:GetAttribute("ThicknessYScale"),
			curve:GetAttribute("Color"))
	
	curve:SetAttribute("CurveStop", pos)
	
	local numLines = #curve:GetChildren()

	if numLines == 1 then
		local onlyLine = curve:FindFirstChild("1")
		if onlyLine:GetAttribute("Start") == pos then
			MetaBoard.UpdateWorldLine(Config.WorldBoard.LineType, onlyLine, board.Canvas, lineInfo, curve:GetAttribute("ZIndex"))
			-- TODO show line
			return
		end
	end
	
	local worldLine = MetaBoard.CreateWorldLine(Config.WorldBoard.LineType, board.Canvas, lineInfo, curve:GetAttribute("ZIndex"))
	worldLine.Parent = curve
	worldLine.Name = tostring(numLines + 1)
end

function ServerDrawingTasks.FreeHand.Finish(board, curve) end
function ServerDrawingTasks.FreeHand.Undo(board, curve) end
function ServerDrawingTasks.FreeHand.Redo(board, curve) end

ServerDrawingTasks.StraightLine = {}
ServerDrawingTasks.StraightLine.__index = ServerDrawingTasks.StraightLine


function ServerDrawingTasks.StraightLine.Init(board, curve, authorUserId, thicknessYScale, color, zIndex, pos)
	curve:SetAttribute("TaskType", "StraightLine")
	curve:SetAttribute("AuthorUserId", authorUserId)
	curve:SetAttribute("Color", color)
	curve:SetAttribute("ThicknessYScale", thicknessYScale)
	curve:SetAttribute("ZIndex", zIndex)

	curve:SetAttribute("CurveStart", pos)

	local lineInfo = LineInfo.new(pos, pos, thicknessYScale, color)
	local worldLine = MetaBoard.CreateWorldLine(Config.WorldBoard.LineType, board.Canvas, lineInfo, zIndex)
	worldLine.Name = "1"
	worldLine.Parent = curve
end

function ServerDrawingTasks.StraightLine.Update(board, curve, pos)
	local lineInfo =
		LineInfo.new(
			curve:GetAttribute("CurveStart"),
			pos,
			curve:GetAttribute("ThicknessYScale"),
			curve:GetAttribute("Color"))
	
	local worldLine = curve:FindFirstChild("1")
	MetaBoard.UpdateWorldLine(Config.WorldBoard.LineType, worldLine, board.Canvas, lineInfo, curve:GetAttribute("ZIndex"))
end

function ServerDrawingTasks.StraightLine.Finish(board, curve)
	local wholeLine = curve:FindFirstChild("1")
	local wholeLineInfo = LineInfo.ReadInfo(wholeLine)
	
	if wholeLineInfo.Length > Config.Drawing.LineSubdivisionLength then
		wholeLine:Destroy()

		local start = wholeLineInfo.Start
		local stop = wholeLineInfo.Stop
		local lineVector = stop - start

		local lineInfo
		for i=0, wholeLineInfo.Length/Config.Drawing.LineSubdivisionLength do
			if i == wholeLineInfo.Length/Config.Drawing.LineSubdivisionLength then
				break
			end

			local lineStop =
				if
					i+1 >= wholeLineInfo.Length/Config.Drawing.LineSubdivisionLength
				then
					wholeLineInfo.Stop
				else
					start + (i+1) * Config.Drawing.LineSubdivisionLength * lineVector.Unit

			lineInfo =
				LineInfo.new(
					start + i * Config.Drawing.LineSubdivisionLength * lineVector.Unit,
					lineStop,
					wholeLineInfo.ThicknessYScale,
					wholeLineInfo.Color)

			local worldLine = MetaBoard.CreateWorldLine(Config.WorldBoard.LineType, board.Canvas, lineInfo, curve:GetAttribute("ZIndex"))
			worldLine.Name = tostring(i+1)
			worldLine.Parent = curve
		end
	end
end

function ServerDrawingTasks.StraightLine.Undo(curve) end
function ServerDrawingTasks.StraightLine.Redo(curve) end

ServerDrawingTasks.Erase = {}
ServerDrawingTasks.Erase.__index = ServerDrawingTasks.Erase


function ServerDrawingTasks.Erase.CollectAndHide(board, erasedCurves, pos, radius)

	for _, curve in ipairs(board.Canvas.Curves:GetChildren()) do
		
		local erasedLineNames = {}
		
		for _, worldLine in ipairs(curve:GetChildren()) do
			if worldLine:GetAttribute("Hidden") then continue end

			local lineInfo = LineInfo.ReadInfo(worldLine)
			if LineInfo.Intersects(pos, radius, lineInfo) then
				
				MetaBoard.HideWorldLine(Config.WorldBoard.LineType, worldLine)

				table.insert(erasedLineNames, worldLine.Name)
			end
		end

		if #erasedLineNames > 0 then
			local erasedCurve = erasedCurves:FindFirstChild(curve.Name)
			if erasedCurve == nil then
				erasedCurve = Instance.new("Folder")
				erasedCurve.Name = curve.Name
				erasedCurve.Parent = erasedCurves
			end

			for _, name in ipairs(erasedLineNames) do
				if erasedCurve:FindFirstChild(name) == nil then
					local nameVal = Instance.new("StringValue")
					nameVal.Name = name
					nameVal.Value = name
					nameVal.Parent = erasedCurve
				end
			end
		end

	end
end


function ServerDrawingTasks.Erase.Init(board, erasedCurves, authorUserId, thicknessYScale, pos)
	erasedCurves:SetAttribute("AuthorUserId", authorUserId)
	erasedCurves:SetAttribute("ThicknessYScale", thicknessYScale)
	erasedCurves:SetAttribute("TaskType", "Erase")

	ServerDrawingTasks.Erase.CollectAndHide(board, erasedCurves, pos, thicknessYScale/2)
end

function ServerDrawingTasks.Erase.Update(board, erasedCurves, pos)
	ServerDrawingTasks.Erase.CollectAndHide(board, erasedCurves, pos, erasedCurves:GetAttribute("ThicknessYScale")/2)
end

function ServerDrawingTasks.Erase.Finish(board, erasedCurves) end

function ServerDrawingTasks.Erase.Undo(board, erasedCurves)
	for _, erasedCurve in ipairs(erasedCurves:GetChildren()) do
		local curve = board.Canvas.Curves:FindFirstChild(erasedCurve.Name)
		for _, erasedLineIdValue in ipairs(erasedCurve:GetChildren()) do
			local worldLine = curve:FindFirstChild(erasedLineIdValue.Value)
			MetaBoard.ShowWorldLine(Config.WorldBoard.LineType, worldLine)
		end
	end
end

function ServerDrawingTasks.Erase.Redo(board, erasedCurves)
	for _, erasedCurve in ipairs(erasedCurves:GetChildren()) do
		local curve = board.Canvas.Curves:FindFirstChild(erasedCurve.Name)
		for _, erasedLineIdValue in ipairs(erasedCurve:GetChildren()) do
			local worldLine = curve:FindFirstChild(erasedLineIdValue.Value)
			MetaBoard.HideWorldLine(Config.WorldBoard.LineType, worldLine)
		end
	end
end


return ServerDrawingTasks