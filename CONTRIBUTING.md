## Sync via Rojo

Generating a new release to test your changes can be tedious, so it's best
to use Rojo to continuously update your changes from your editor to Roblox Studio.

Download the latest release of [foreman](https://github.com/Roblox/foreman).
Move it somewhere within your `$PATH` (e.g. `/usr/local/bin`), and make it executable (`chmod +x /path/to/foreman`).

Then in the directory of this repository,
run
```bash
foreman install
```
You may get an error if you are running Mac OS X, in which case check Security & Privacy under System Preferences and click `Allow Anyway` for foreman. This should install Rojo, but perhaps not in your `$PATH`. It's up to you to fix that, but for example on Mac OS X it might be in `~/.foreman/bin`.

Run the following terminal commands from the directory of this repository.
This installs the Rojo plugin in Roblox Studio and starts the Rojo server (using `default.project.json`).
```bash
rojo plugin install
rojo serve
```
Then open any place file in Roblox Studio and click `Connect` in the Rojo window (you may need to show Rojo via the Plugins tab).
Now you can edit any of the files in `src` with your favourite editor and your
changes will be synced into Roblox Studio.

Make sure to add an example board for testing (see [Adding boards to your game](README.md##-Adding-boards-to-your-game))

It's recommended to keep the Rojo window visible as a confirmation that your changes are still being synced,
in case the Rojo server crashes for any reason.

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Generating a Release

To generate a release, run
```bash
rojo build --output metaboard.rbxmx release.project.json
```

This packages the `src/common`, `src/client` and `src/gui` code inside the server folder (`src/server`) called `metaboard`. 

`src/server/Startup.server.lua` will redistribute this code into the appropriate client folders when the game starts.

## Source Code Overview

The primary object of metaboard is a `Board`, which is a class-object with the following primary data.
```lua
{
	_instance: Model | Part,
	Remotes: BoardRemotes,
	PersistId: string,
	Loaded: boolean,
	PlayerHistories: {[userId]: History},
	DrawingTasks: {[taskId]: DrawingTask},
	Figures: {[figureId]: Figure},
	NextFigureZIndex: number,
}
```

`BoardClient` and `BoardServer` are derivatives of the `Board` class and add behaviour specific to the client/server.

It is the job of the server (in `init.server.lua`) to decide which instances should become a `Board` object (through CollectionService).
The instance is stored in the `_instance` key (see `TODO: link to heading`).
There is some back and forth exchange between the client and server while the server is retrieving persistent board data from the
datastore, but eventually the client has a `BoardClient` object corresponding to each `BoardServer` object that the server has.

## Client-Server Communication

All communication between client and server takes place via the `BoardRemotes` object. It is created by the server **for each board**, and contains
a folder of remote events, which are parented to the board instance. The client retrieves this object from the server, because it must connect to the exact same remote event instances.

`BoardRemotes.lua` also contains a function (`BoardRemotes:Connect`) for connecting to both `OnServerEvent` and `OnClientEvent` for each of the remote events. There are some slightly different behaviour depending on whether its the server-side or client-side logic, but the majority of the code (which manipulates Figures, Drawing Tasks and Histories) is the same for the client and server. The client and server code were previously separate, but this introduced too many bugs when forgetting to make a change in both files.

## Figures, DrawingTasks, PlayerHistories

These three tables, plus `NextFigureZIndex` are referred to as the `state` of the board. It is comprised purely of tables and `DataType` objects (i.e. `number`, `Vector2`, `Color3` etc), which can then be "rendered" by different means in order to see what's on the board. We make use of [Roact](https://roblox.github.io/roact/) to create instances from the state and then reconcile differences when the state changes. We refer to a particualr rendering of the board state as a `Canvas` (see `src/client/FrameCanvas` and `src/client/PartCanvas`).

[This talk](https://www.youtube.com/watch?v=NQxE4H6JmQI) on metaboard explains the motivation for dividing the board state across these three tables. 
Here we will give more implementation specific details.

### Figures

A `Figure` is a table with a `Type: string` entry specifying what kind of figure it is, along with the necessary defining data. The protoypical example is a curve, which has the following format.
```lua
{
	Type: "Curve",
	Points: {Vector2},
	Width: number,
	Color: number,
	ZIndex: number,
	Mask: {[string]: boolean}?
}
```

This data represents a [polyline](https://en.wikipedia.org/wiki/Polygonal_chain) of line segments (each of the given width, color, z-Index) joining the consecutive points in the Points array. The optional Mask table has entries of the form `[tostring(i)] = true`, where `1 <= i <= #Points-1`, which indicate that the line segment between `Points[i]` and `Points[i+1]`.

In ideal form, this data actually represents some smooth curve that passes through the points, i.e. the smooth path traced out by the pen that generated the points. The polyline is just a simple choice of representation. Other "renderers" can take this same data and render a smoother polyline with more intermediate points, or a coarser one that skips points, or even render to a pixel-based canvas.

Other types of figures are `Line` and `Circle` though these are currently not in use. `Line` is not in use because we subdivide straight lines into line segments (see `StraightLine.Finish`), so `Curve` is more suitable, and `Circle` is not in use because there is no Circle tool yet, though it could also be implemented as a Curve.

There's an argument that `Curve` should be the only kind of figure, because erasing is expected to erase only part of the figure, so it makes sense to reuse the mask structure that curves have.

However we might also want very different kinds of figures that aren't curve-like. For example inserting images. Or maybe filled-in shapes. The choices made here affect/are-affected-by how erasing behaves, how undo/redo behaves, and how clientside prediction behaves.

### Drawing Tasks

A drawing task represents a contribution-to or modification of the board state. A basic drawing task is just a container for a figure, e.g. `FreeHand` and `StraightLine` just contain a curve. A drawing task evolves over the lifetime of a "touch-and-drag" user-input, after which it becomes a discrete action that can be undone and redone (in theory) simply by removing/adding it to `board.DrawingTasks`.

Here are the primary methods of the `FreeHand` drawing task (not all of them).

```lua
function FreeHand.new(taskId: string, color: Color3, thicknessYScale: number)

	return {
		Id = taskId,
		Type = script.Name,
		Curve = {
			Type = "Curve",
			Points = nil, -- Not sure if this value has any consequences
			Width = thicknessYScale,
			Color = color,
		} :: Figure.Curve
	}
end

function FreeHand.Render(drawingTask): Figure.AnyFigure

	return drawingTask.Curve
end

function FreeHand.Init(drawingTask, board, canvasPos: Vector2)

	local zIndex = board.NextFigureZIndex

	if drawingTask.Verified then
		board.NextFigureZIndex += 1
	end

	local newCurve = merge(drawingTask.Curve, {
		
		Points = {canvasPos, canvasPos},
		ZIndex = zIndex,

	})

	return set(drawingTask, "Curve", newCurve)
end

function FreeHand.Update(drawingTask, board, canvasPos: Vector2)

	-- This means that the points array cannot be treated as immutable
	-- We still return a new drawingTask with a new curve in it.
	local newPoints = drawingTask.Curve.Points
	table.insert(newPoints, canvasPos)

	local newCurve = set(drawingTask.Curve, "Points", newPoints)

	return set(drawingTask, "Curve", newCurve)
end

function FreeHand.Finish(drawingTask, board)
	
	if drawingTask.Verified then
		board.EraseGrid:AddCurve(drawingTask.Id, drawingTask.Curve)
	end

	return drawingTask
end
```

It stores an identifier, a type string, and a figure. As with any other drawing task, the `Init` function is called when the client begins touching the screen (e.g. `MouseButton1Down`), then `Update` is called for every subsequent movement (e.g. `MouseMoved`) and then `Finish` when the client stops touching the screen (e.g. `MouseButton1Up`).

- What's this set/merge business? These functions are from the immutability data library [Sift](https://csqrl.github.io/sift/). They clone the first argument, then return that clone with the given key/keys changed. Why immutability? See immutability section (TODO).
- What's `drawingTask.Verified`? This is a flag set by the server so that side-effects are only performed when safe to do so (i.e. in the same order w.r.t. other drawing tasks). This allows clients to perform and manage their own "unverified" drawing tasks without affecting the board state. In `FreeHand`, the `NextFigureZIndex` of the board is incremented in the `Init` stage, and the resulting figure is added to the EraseGrid in the `Finish` stage.
- Why does every curve begin with two of the same point? This simplifies the logic in other areas of the code (EraseGrid, rendering) because they can assume every curve has length 2. This could change.

### Erasing

Erasing throws a spanner in the works because it is quite different to the "draw a figure" drawing tasks. It is hard to treat it as a standalone/removable contribution to the board state, since its high-level purpose is to modify the appearance of other figures. The solution we employ is to just record what is being erased from each figure within the drawing task itself. It is then the responsibility of the renderer to hide any parts of figures that have been erased by some drawing task in `board.DrawingTasks` (see rendering section TODO)

### The EraseGrid
In the [Drawing Tasks](#drawing-tasks) section it says
> A drawing task evolves over the lifetime of a "touch-and-drag" user-input, after which it becomes a discrete action that can be undone and redone (in theory) simply by removing/adding it to `board.DrawingTasks`.

The reason for the "in theory" clause is due to the EraseGrid. The EraseGrid is a grid of cells which records which parts of which figures are visible in which cells of the canvas. It's purpose is to enable fast, localised lookups of which parts of figures are being intersected by the eraser. Instead of looping over every line segment of every figure on the board, we can just calculate which cells are being touched, and only check for intersection with the figures that appear in that cell.

It can be thought of as a pixel based "rendering" of the canvas, because it must only store "non-erased" things in each cell. Therefore it must be kept in sync with the board state, and any modifications of the board state must be accompanied by an ad-hoc modification of the EraseGrid that matches the result of re-rendering the new state. This is precisely why you cannot just add and remove things from the DrawingTasks and Figures tables.

Failing to keep the EraseGrid in sync has already been the source of multiple, very noticeable bugs, in which the rendered board shows a curve that cannot be erased because it does not exist in the erase grid. The process of erasing is also complicated by the fact that its behaviour when encountering a sub-figure (e.g. a line segment in a curve) must depend on what figure the subfigure is a part of, and encoding and retrieving the figure is rather awkward. It might be better to store this subfigure-cell-location data within the figure itself, and erasing would involve looping over every figure and checking if there are any subfigures in the figures own erase grid. Then their would be no "keeping the erase grid in sync" and it would be impossible to see a figure that couldn't be erased. Also it would remove the need for figure-type-polymorphism in the erase grid (which is a hassle to maintain).

## PlayerHistories

Each player gets a `History`, which is an ordered list of drawing tasks which is partitioned into a past and a future. Everything in the past is also present in `board.DrawingTasks` and everything in the future is not. When a client hits undo or redo, the dividing line of this partition is shifted forwards or backwards, and the exchanged drawing tasks are added/removed from `board.DrawingTasks` (the Undo/Redo drawing task functions are also called to handle EraseGrid related side-effects).

Each history has a capacity (currently set to 15), so that when a drawing task becomes too "old" it is removed from the history, and its effects are permanently "committed" to `board.Figures`. This is because each drawing task necessitates some computation to be performed every time a render is triggered, so having too many of them will accumulate performance issues.

Old drawing tasks can not always be immediately committed. For example, you cannot commit an `Erase` drawing task if any of the figures it affects are not yet committed to the Figures table (i.e. they live inside another DrawingTask). There is some logic in the `InitDrawingTask` event connection of `BoardRemotes:Connect` that accounts for this.


## Rendering

Rendering the state of the board from scratch every time a change happens would be disastrous performance-wise. So we need some way of efficiently turning `render(state1)` into `render(state2)`. We make use of [Roact](https://roblox.github.io/roact/), which maintains virtual copies of each instance as a tree of lua-tables (matching the hierarchy of rendered instances), and compares those to the old virtual tree as it goes, in order to find which properties need to be made to which instances in the DataModel.

Doing this computation and comparison on the pure-lua side is orders of magnitude faster than querying/iterating-over instances. But once the tree gets big enough, the cost of recomputing the entire tree affects performance, even if only a few instances get created/updated as a result. The solution is to shortcut the render process as much as possible. Roact components have a method called `shouldUpdate`, for exactly this purpose. The tree is updated "top-down", re-rendering each component in the tree, and then moving on to the children of that node. Before rendering a component, `shouldUpdate` is called, and if it returns false, then neither that component, nor its children are re-rendered.

We make use of `shouldUpdate` in every figure component, which is a very fast equality check between the new and old figure data. This is why our use of immutability is critical, because we are relying on `==` to check if the contents of the tables are equal. This does still mean that we have to call `shouldUpdate` on every single figure every time we render, but the scale of numbers matters here. Typically we're dealing with *hundreds* of figures, and the *low-tens-of-thousands* of lines. As a rule of thumb, O(#figures) should be considered "fast enough", and O(#lines) is likely to incur a performance issue (O as in [Big-O notation](https://en.wikipedia.org/wiki/Big_O_notation)).

This poses a challenge when involving masks from `Erase` drawing tasks. Each figure needs to take into account all of the drawing tasks that erased part of it when rendering, but if we gather all of those masks and merge them into the figure data, we will either need to mutate the figure data (bad!) or we will have to create a new table for the modified figure, which will always be non-equal to the one created in the last render, even if it was the same resulting mask. Then the only way to shortcut the render process will be to check that all of the contents of the mask are the same as the mask from the previous render. This becomes an O(#lines) in the worst case (when most figures are at least partially erased).

Instead we rely on the immutability of the mask generated by each erase drawing task, and keep them all separately in a table of masks for that figure. Then our `shouldUpdate` method just needs to check whether we have the same collection of masks as the previous render, which is only O(#drawingTasks).

All of the above wisdom is present in the `PureFigure` component (here is the one from `src/client/PartCanvas`).

```lua
local PureFigure = Roact.PureComponent:extend("PureFigure")

function PureFigure:render()
	local figure = self.props.Figure

	local cummulativeMask = Figure.MergeMask(figure.Type, figure.Mask)

	for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
		cummulativeMask = Figure.MergeMask(figure.Type, cummulativeMask, figureMask)
	end

	return e(FigureComponent[self.props.Figure.Type],


		merge(self.props.Figure, {
			CanvasSize = self.props.CanvasSize,
			CanvasCFrame = self.props.CanvasCFrame,

			Mask = cummulativeMask,
		})

	)
end

function PureFigure:shouldUpdate(nextProps, nextState)
	local shortcut =
	nextProps.Figure ~= self.props.Figure or
	nextProps.CanvasSize ~= self.props.CanvasSize or
	nextProps.CanvasCFrame ~= self.props.CanvasCFrame or
	nextProps.ZIndexOffset ~= self.props.ZIndexOffset

	if shortcut then
		return true
	else
		-- Check if any new figure masks are different or weren't there before
		for eraseTaskId, figureMask in pairs(nextProps.FigureMasks) do
			if figureMask ~= self.props.FigureMasks[eraseTaskId] then
				return true
			end
		end

		-- Check if any old figure masks are now different or gone
		for eraseTaskId, figureMask in pairs(self.props.FigureMasks) do
			if figureMask ~= nextProps.FigureMasks[eraseTaskId] then
				return true
			end
		end

		return false
	end
end
```