local HttpService = game:GetService("HttpService")
local root = script.Parent.Parent

local Board = require(root.Board)
local Destructor = require(root.Destructor)
local BoardRemotes = require(root.BoardRemotes)
local FreeHand = require(root.DrawingTask.FreeHand)
local StraightLine = require(root.DrawingTask.StraightLine)
local Erase = require(root.DrawingTask.Erase)

local SurfaceCanvas = require(root.Client.SurfaceCanvas)

return function()

	local destructor = Destructor.new()

	local instance = Instance.new("Part")
	instance.Size = Vector3.new(16, 12, 0.1)
	instance.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0,0,-20) * CFrame.Angles(0, math.pi, 0)
	destructor:Add(instance)

	local remotes = BoardRemotes.new(instance)
	destructor:Add(remotes)

	local state = {
		DrawingTask = nil,
		Thickness = 1/(2^5),
		EraserThickness = 0.1,
		Color = Color3.new(1, 0, 0),
		AuthorId = "TestPlayer123",
	}

	local board = Board.new({
		Instance = instance,
		BoardRemotes = remotes,
	})
	destructor:Add(board)

	local surfaceCanvas = SurfaceCanvas.new(board)
	surfaceCanvas.Loading = false
	surfaceCanvas:LoadMore()
	destructor:Add(surfaceCanvas)

	local actions = {

	}

	function actions.draw(points: {Vector2}, doStart: boolean, doStop: boolean)
		assert(state.DrawingTask, "Bad draw, no drawing task")
		assert(#points > 0, "Bad Points")

		if doStart then
			board:ProcessInitDrawingTask(state.AuthorId, state.DrawingTask, points[1])
		end

		for i=1, #points do
			if doStart and i==1 then
				continue
			end

			board:ProcessUpdateDrawingTask(state.AuthorId, points[i])
		end

		if doStop then
			board:ProcessFinishDrawingTask(state.AuthorId)
		end
	end

	function actions.dragBetween(startPos: Vector2, endPos: Vector2, numPoints: number, doStart: boolean, doStop: boolean)
		local points = {}
		for i=0, numPoints-1 do
			table.insert(points, startPos:Lerp(endPos, i/numPoints))
		end
		actions.draw(points, doStart, doStop)
	end

	function actions.undo()
		local history = board.State.PlayerHistories[state.AuthorId]
		if history and history:CountPast() > 0 then
			board:ProcessUndo(state.AuthorId)
		end
	end
	
	function actions.redo()
		local history = board.State.PlayerHistories[state.AuthorId]
		if history and history:CountFuture() > 0 then
			board:ProcessRedo(state.AuthorId)
		end
	end

	function actions.setFreeHand()
		state.DrawingTask = FreeHand.new(HttpService:GenerateGUID(false), state.Color, state.Thickness)
		state.DrawingTask.Verified = true
	end
	function actions.setStraightLine()
		state.DrawingTask = StraightLine.new(HttpService:GenerateGUID(false), state.Color, state.Thickness)
		state.DrawingTask.Verified = true
	end
	function actions.setErase()
		-- state.DrawingTask = FreeHand.new(HttpService:GenerateGUID(false), Color3.new(0,0,1), state.EraserThickness)
		state.DrawingTask = Erase.new(HttpService:GenerateGUID(false), state.EraserThickness)
		state.DrawingTask.Verified = true
	end

	local ClassProperties = {
		["Part"] = {
			"Shape",
			"Size",
			"CFrame",
			"Color",
			"Material",
			"TopSurface",
			"BottomSurface",
			"Anchored",
			"CanCollide",
			"CastShadow",
			"CanTouch",
			"CanQuery",
		},
		["Folder"] = {
		},
	}

	local function hasDuplicates(items: {any}): boolean
		local foundSet = {}
		for _, item in items do
			if foundSet[item] then
				return true
			end
			foundSet[item] = true
		end
		return false
	end

	local function deepAssertEqInstances(a: Instance, b: Instance?, ignoreName: boolean?)
		if ignoreName == nil then
			ignoreName = false
		end
		assert(b, `Failed Comparison of {a:GetFullName()} to nil instance`)
		if not ignoreName then
			assert(a.Name == b.Name, `Name mismatch: {a.Name} vs {b.Name}`)
		end
		assert(a.ClassName == b.ClassName, `Class name mismatch: {a.ClassName} vs {b.ClassName}`)

		if ClassProperties[a.ClassName] then
			for _, propName in ClassProperties[a.ClassName] do
				assert(a[propName] == b[propName], `Mismatch.\n{a:GetFullName()}\n.{propName} = {a[propName]}\n{b:GetFullName()}\n.{propName} = {b[propName]}`)
			end
		end

		local aChildren = a:GetChildren()
		local bChildren = b:GetChildren()
		assert(not hasDuplicates(aChildren), `{a:GetFullName()} has duplicates names in children`)
		assert(not hasDuplicates(bChildren), `{b:GetFullName()} has duplicates names in children`)

		for _, aChild in aChildren do
			deepAssertEqInstances(aChild, b:FindFirstChild(aChild.Name))
		end
		for _, bChild in bChildren do
			deepAssertEqInstances(bChild, a:FindFirstChild(bChild.Name))
		end
	end

	local function verifyBoardState()
		print("Verifying")
		-- local freshBoard = Board.new({
		-- 	BoardRemotes = remotes,
		-- 	Instance = instance,
		-- })
		-- destructor:Add(freshBoard)
		-- freshBoard:LoadData({
		-- 	Figures = board:CommitAllDrawingTasks(),
		-- 	DrawingTasks = {},
		-- 	PlayerHistories = {},
		-- 	NextFigureZIndex = 0,
		-- })
		local freshSurfaceCanvas = SurfaceCanvas.new(board)
		destructor:Add(freshSurfaceCanvas)
		freshSurfaceCanvas.Loading = false
		freshSurfaceCanvas:LoadMore()
		freshSurfaceCanvas.CanvasTree.root.result[1].Name = "FreshSurfaceCanvas"

		deepAssertEqInstances(freshSurfaceCanvas.CanvasTree.root.result[1], surfaceCanvas.CanvasTree.root.result[1], true)
	end

	local function prettyToString(data: any): string
		if typeof(data) == "table" and #data > 0 then
			local recData = {}
			for key, value in data do
				assert(typeof(key) == "number", "Bad table")
				table.insert(recData, prettyToString(value))
			end
			return "{"..table.concat(recData, ",").."}"
		elseif typeof(data) == "table" then
			local recData = {}
			for key, value in data do
				recData[key] = prettyToString(value)
			end
			return "{"..table.concat(recData, ",").."}"
		elseif table.find({"number", "boolean"}, typeof(data)) then
			return tostring(data)
		elseif typeof(data) == "string" then
			return '"'..tostring(data)..'"'
		else
			return typeof(data)..".new("..tostring(data)..")"
		end
	end

	local function doAction(recordList, actionName, ...)
		local args = {...}
		local argsPretty = prettyToString(args)
		local str = `actions.{actionName}({argsPretty:sub(2,#argsPretty-1)})`
		table.insert(recordList, str)
		actions[actionName](...)
	end

	local function randomChoice<T>(items: {T}): T
		return items[math.random(1, #items)]
	end

	local function randomPoint(aspectRatio: number): Vector2
		return Vector2.new(aspectRatio*math.random(), math.random())
	end

	do -- Test
		instance.Parent = workspace

		local rec = {}
		doAction(rec, "setFreeHand")
		for i=1, 1000 do
			local actionName = randomChoice({"dragBetween", "undo", "redo", "setFreeHand", "setErase"})
			local repeats = math.random(1, 1)
			for r=1, repeats do
				if actionName == "dragBetween" then
					doAction(rec, actionName, randomPoint(16/12), randomPoint(16/12), 20, true, true)
				else
					doAction(rec, actionName)
				end
			end
		end

		local co = task.delay(0.2, function()
			print("Actions")
			print("-------")
			for _, action in rec do
				print(action)
			end
			local success, msg = pcall(verifyBoardState)
			if not success then
				warn(msg)
			end
			print("Done")
		end)
		destructor:Add(co)
	end

	return function()
		destructor:Destroy()
	end
end