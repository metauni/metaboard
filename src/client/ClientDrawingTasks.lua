local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DrawingTask = require(Common.DrawingTask)
local Config = require(Common.Config)
local Drawing
local CanvasState
local Curves
local CatRom = require(Common.Packages.CatRom)
local LineInfo = require(Common.LineInfo)

local LocalPlayer = game:GetService("Players").LocalPlayer

local ClientDrawingTasks = {}
ClientDrawingTasks.__index = ClientDrawingTasks

function ClientDrawingTasks.Init(boardGui)
	Drawing = require(script.Parent.Drawing)
	CanvasState = require(script.Parent.CanvasState)
	Curves = boardGui.Curves
end

ClientDrawingTasks.FreeHand = {}
ClientDrawingTasks.FreeHand.__index = ClientDrawingTasks.FreeHand

function ClientDrawingTasks.FreeHand.Init(curve, authorUserId, thicknessYScale, color, zIndex, pos)
	curve:SetAttribute("TaskType", "FreeHand")

	curve:SetAttribute("AuthorUserId", authorUserId)
	curve:SetAttribute("Color", color)
	curve:SetAttribute("ThicknessYScale", thicknessYScale)
	CanvasState.SetZIndex(curve, zIndex)

	curve:SetAttribute("CurveStop", pos)
	curve:SetAttribute("NumPoints", 1)

	local lineInfo = LineInfo.new(pos, pos, thicknessYScale, color)
	local lineFrame = CanvasState.CreateLineFrame(lineInfo)
	lineFrame.Name = "0"

	CanvasState.AttachLine(lineFrame, curve)

end

function ClientDrawingTasks.FreeHand.Update(curve, pos)
	if curve == nil then
		-- BUG: This has happened
		print("[metaboard] ERROR: Nil curve passed to ClientDrawingTasks.FreeHand.Update")
		return
	end

	local lineInfo =
		LineInfo.new(
			curve:GetAttribute("CurveStop"),
			pos,
			curve:GetAttribute("ThicknessYScale"),
			curve:GetAttribute("Color"))

	local numPoints = curve:GetAttribute("NumPoints")

	if numPoints == 1 then
		-- The zero line is the dot that is created when the user first puts the
		-- tool down. It's a zero length line and makes non-rounded lines look gross,
		-- because they have an unrotated square at the start of the line
		local zeroLine = CanvasState.GetLinesContainer(curve):FindFirstChild("0")
		-- We update it to be the new line, instead of a making a new line
		CanvasState.UpdateLineFrame(zeroLine, lineInfo)
		zeroLine.Name = "1"
		-- Show it in case someone already erased the zero line
		zeroLine.Visible = true
	else
		-- Draw the next line
		local lineFrame = CanvasState.CreateLineFrame(lineInfo)
		lineFrame.Name = tostring(numPoints)
		CanvasState.AttachLine(lineFrame, curve)
	end

	curve:SetAttribute("CurveStop", pos)
	curve:SetAttribute("NumPoints", numPoints + 1)
end

function ClientDrawingTasks.FreeHand.Finish(curve) end
function ClientDrawingTasks.FreeHand.Undo(curve) end
function ClientDrawingTasks.FreeHand.Redo(curve) end
function ClientDrawingTasks.FreeHand.Commit(curve)
	if #curve:GetChildren() == 0 then
		curve:Destroy()
	end
end

ClientDrawingTasks.Attention = {}
ClientDrawingTasks.Attention.__index = ClientDrawingTasks.Attention

function ClientDrawingTasks.Attention.Init(curve, authorUserId, thicknessYScale, color, zIndex, pos)
	curve:SetAttribute("TaskType", "Attention")

	curve:SetAttribute("AuthorUserId", authorUserId)
	curve:SetAttribute("Color", color)
	curve:SetAttribute("ThicknessYScale", thicknessYScale)
	CanvasState.SetZIndex(curve, zIndex)

	curve:SetAttribute("CurveStop", pos)
	curve:SetAttribute("NumPoints", 1)

	local lineInfo = LineInfo.new(pos, pos, thicknessYScale, color)
	local lineFrame = CanvasState.CreateLineFrame(lineInfo)
	lineFrame.Name = "0"

	CanvasState.AttachLine(lineFrame, curve)
end

function ClientDrawingTasks.Attention.Update(curve, pos)
	if curve == nil then
		-- BUG: This has happened
		print("[metaboard] ERROR: Nil curve passed to ClientDrawingTasks.Attention.Update")
		return
	end

	local lineInfo =
		LineInfo.new(
			curve:GetAttribute("CurveStop"),
			pos,
			curve:GetAttribute("ThicknessYScale"),
			curve:GetAttribute("Color"))

	local numPoints = curve:GetAttribute("NumPoints")

	if numPoints == 1 then
		-- The zero line is the dot that is created when the user first puts the
		-- tool down. It's a zero length line and makes non-rounded lines look gross,
		-- because they have an unrotated square at the start of the line
		local zeroLine = CanvasState.GetLinesContainer(curve):FindFirstChild("0")
		-- We update it to be the new line, instead of a making a new line
		CanvasState.UpdateLineFrame(zeroLine, lineInfo)
		zeroLine.Name = "1"
		-- Show it in case someone already erased the zero line
		zeroLine.Visible = true
	else
		-- Draw the next line
		local lineFrame = CanvasState.CreateLineFrame(lineInfo)
		lineFrame.Name = tostring(numPoints)
		CanvasState.AttachLine(lineFrame, curve)
	end

	curve:SetAttribute("CurveStop", pos)
	curve:SetAttribute("NumPoints", numPoints + 1)
end

function ClientDrawingTasks.Attention.Finish(curve)
	task.delay(Config.Drawing.Defaults.AttentionPenDelayTime, function ()
		for _, child in ipairs(curve:GetChildren()) do
			child:Destroy()
			ClientDrawingTasks.Attention.Commit(curve)
		end
	end)
end
function ClientDrawingTasks.Attention.Undo(curve) end
function ClientDrawingTasks.Attention.Redo(curve) end
function ClientDrawingTasks.Attention.Commit(curve)
	if #curve:GetChildren() == 0 then
		curve:Destroy()
	end
end

ClientDrawingTasks.StraightLine = {}
ClientDrawingTasks.StraightLine.__index = ClientDrawingTasks.StraightLine

function ClientDrawingTasks.StraightLine.Init(curve, authorUserId, thicknessYScale, color, zIndex, pos)
	curve:SetAttribute("TaskType", "StraightLine")
	curve:SetAttribute("AuthorUserId", authorUserId)
	curve:SetAttribute("Color", color)
	curve:SetAttribute("ThicknessYScale", thicknessYScale)
	CanvasState.SetZIndex(curve, zIndex)

	curve:SetAttribute("CurveStart", pos)

	local lineInfo = LineInfo.new(pos, pos, thicknessYScale, color)
	local lineFrame = CanvasState.CreateLineFrame(lineInfo)

	lineFrame.Name = "1"
	CanvasState.AttachLine(lineFrame, curve)
end

function ClientDrawingTasks.StraightLine.Update(curve, pos)
	local lineInfo =
		LineInfo.new(
			curve:GetAttribute("CurveStart"),
			pos,
			curve:GetAttribute("ThicknessYScale"),
			curve:GetAttribute("Color"))

	local lineFrame = CanvasState.GetLinesContainer(curve):FindFirstChild("1")
	CanvasState.UpdateLineFrame(lineFrame, lineInfo)
end

function ClientDrawingTasks.StraightLine.Finish(curve)
	local wholeLine = CanvasState.GetLinesContainer(curve):FindFirstChild("1")
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

			local lineFrame = CanvasState.CreateLineFrame(lineInfo)
			lineFrame.Name = tostring(i+1)
			CanvasState.AttachLine(lineFrame, curve)
		end
	end
end


function ClientDrawingTasks.StraightLine.Undo(curve) end
function ClientDrawingTasks.StraightLine.Redo(curve) end
function ClientDrawingTasks.FreeHand.Commit(curve)
	if #curve:GetChildren() == 0 then
		curve:Destroy()
	end
end

ClientDrawingTasks.Erase = {}
ClientDrawingTasks.Erase.__index = ClientDrawingTasks.Erase

function ClientDrawingTasks.Erase.CollectAndHide(erasedCurves, pos, radius)

	for _, curve in ipairs(Curves:GetChildren()) do
		if curve:GetAttribute("TaskType") == "Attention" then
			continue
		end

		local erasedLineNames = {}

		for _, lineFrame in ipairs(CanvasState.GetLinesContainer(curve):GetChildren()) do
			if lineFrame.Visible == false then continue end

			local lineInfo = LineInfo.ReadInfo(lineFrame)
			if LineInfo.Intersects(pos, radius, lineInfo) then

				-- Hide the lineFrame
				lineFrame.Visible = false

				table.insert(erasedLineNames, lineFrame.Name)
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
					nameVal.Value = name
					nameVal.Name = name
					nameVal.Parent = erasedCurve
				end
			end
		end

	end
end

function ClientDrawingTasks.Erase.Init(erasedCurves, authorUserId, thicknessYScale, pos)
	erasedCurves:SetAttribute("AuthorUserId", authorUserId)
	erasedCurves:SetAttribute("ThicknessYScale", thicknessYScale)
	erasedCurves:SetAttribute("TaskType", "Erase")

	ClientDrawingTasks.Erase.CollectAndHide(erasedCurves, pos, thicknessYScale/2)
end

function ClientDrawingTasks.Erase.Update(erasedCurves, pos)
	ClientDrawingTasks.Erase.CollectAndHide(erasedCurves, pos, erasedCurves:GetAttribute("ThicknessYScale")/2)
end

function ClientDrawingTasks.Erase.Finish(erasedCurves) end

function ClientDrawingTasks.Erase.Undo(erasedCurves)
	for _, erasedCurve in ipairs(erasedCurves:GetChildren()) do
		local curve = Curves:FindFirstChild(erasedCurve.Name)
		-- Check if curve is there. If it's been undo'd it won't be, just ignore it.
		if curve then
			for _, erasedLineIdValue in ipairs(erasedCurve:GetChildren()) do
				local line = CanvasState.GetLinesContainer(curve):FindFirstChild(erasedLineIdValue.Value)
				line.Visible = true
			end
		end
	end
end

function ClientDrawingTasks.Erase.Redo(erasedCurves)
	for _, erasedCurve in ipairs(erasedCurves:GetChildren()) do
		local curve = Curves:FindFirstChild(erasedCurve.Name)
		-- Check if curve is there. If it's been undo'd it won't be, just ignore it.
		if curve then
			for _, erasedLineIdValue in ipairs(erasedCurve:GetChildren()) do
				local line = CanvasState.GetLinesContainer(curve):FindFirstChild(erasedLineIdValue.Value)
				line.Visible = false
			end
		end
	end
end

-- Destroy all of the lines which were temporarily invisible.
function ClientDrawingTasks.Erase.Commit(erasedCurves)
	for _, erasedCurve in ipairs(erasedCurves:GetChildren()) do
		local curve = Curves:FindFirstChild(erasedCurve.Name)
		-- Check if curve is there. If it's been undo'd it won't be, just ignore it.
		-- This is kinda bad. Since those invisible lines will never get destroyed
		-- if their author redo's the curve. Doesn't seem like a huge problem.
		if curve then
			for _, erasedLineIdValue in ipairs(erasedCurve:GetChildren()) do
				local line = CanvasState.GetLinesContainer(curve):FindFirstChild(erasedLineIdValue.Value)
				line:Destroy()
			end

			-- If the curve has been committed and all of it's lines were destroyed, then destroy it
			if curve:GetAttribute("Committed") and #CanvasState.GetLinesContainer(curve):GetChildren() == 0 then
				curve:Destroy()
			end
		end
	end

	erasedCurves:Destroy()
end


return ClientDrawingTasks
