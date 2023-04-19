## Sync via Rojo

Generating a new release to test your changes can be tedious, so it's best
to use Rojo to continuously update your changes from your editor to Roblox Studio.

Download and install the latest release of [aftman](https://github.com/LPGhatguy/aftman).

Then in the directory of this repository,
run
```bash
aftman install
```
You may get an error if you are running Mac OS X, in which case check Security & Privacy under System Preferences and click `Allow Anyway` for foreman. This should install Rojo, but perhaps not in your `$PATH`. It's up to you to fix that, but for example on Mac OS X it might be in `~/.aftman/bin`.

It will also install [wally](https://wally.run), which you will now use to install the package dependencies. You must call this again whenever dependencies change in wally.toml.
```bash
wally install
```

Run the following terminal commands from the directory of this repository.
This installs the Rojo plugin in Roblox Studio and starts the Rojo server (using `dev.project.json`).
```bash
rojo plugin install
rojo serve dev.project.json
```
Then open any place file in Roblox Studio and click `Connect` in the Rojo window (you may need to show Rojo via the Plugins tab). You may need to run the serve command again
if the rojo server crashes. Always ensure your Roblox Studio is connected to the rojo server by keeping the plugin window visible.

Now you can edit any of the files in `lib` with your favourite editor and your
changes will be synced into Roblox Studio.

Make sure to add an example board for testing (see [Adding boards to your game](README.md##-Adding-boards-to-your-game))

It's recommended to keep the Rojo window visible as a confirmation that your changes are still being synced,
in case the Rojo server crashes for any reason.

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Generating a Release

To generate a release, run (with the intended version number in the file name)
```bash
rojo build --output metaboard-vX.X.X.rbxmx release.project.json
```

## Source Code Overview
> WARNING: Information below here is outdated. The file paths are broken
> and some things about metaboard have changed, e.g. using Feather for figure
> rendering instead of Roact.

> What is init.lua?
This is a Rojo concept. When a folder contains such a named file, that folder will become a ModuleScript with its contents,
and the children of the folder will be the children of the ModuleScript.
Similarly for `init.client.lua` (parent folder becomes a `LocalScript`) and `init.server.lua` and (parent folder becomes a `Script`).


- [Board](src/common/Board.lua), [BoardServer](src/server/BoardServer.lua), [BoardClient](src/client/BoardClient/init.lua)
	- The board class and the two derived classes for the client and server.
	- Maintains the state of the board (Figures, DrawingTasks, PlayerHistories) and any other relevant properties (instance, persistId, remotes).
- [BoardRemotes](src/common/BoardRemotes.lua)
	- The channel of communication between client and server for altering the board contents via drawing tasks.
- [Figure](src/common/Figure.lua)
	- The types and associated functions for the different kinds of figures that can be drawn to the board (e.g. `Curve`, `Line`, `Circle`)
- [DrawingTask](src/common/DrawingTask/)
	- Interface for calling the associated functions for the [FreeHand](src/common/DrawingTask/FreeHand.lua), [StraightLine](src/common/DrawingTask/StraightLine.lua) and [Erase](src/common/DrawingTask/Erase.lua) drawing tasks.
	- These methods control how the drawing task evolves during a touch-and-drag user input (Init/Update/Finish), what to add to the table of figures when rendering (Render), what side effects to perform when undoing and redoing (Undo/Redo), and how to permanently commit their changes to the table of Figures (Commit).
- [History](src/common/History.lua)
	- A queue with a concept of past and future, which is used to store each player's most recent drawing tasks, and for retrieving the most recent or most imminent drawing task for undo and redo. It is has a capacity which prevents it from storing drawing tasks which are *too old*.
	- Every operation is O(1) because it uses cyclic indexing :)
- [EraseGrid](src/common/EraseGrid/)
	- Divides the canvas of the board into a square-grid of cells, each of which is a set that indicates which (parts of) figures intersects that cell.
	- The [Erase](src/common/DrawingTask/Erase.lua) drawing task queries the EraseGrid to find which (parts of) figures are *nearby* to the eraser, for performance gains (avoids looping over every single line in every figure).
- [Persistence](src/server/Persistence.lua)
	- Stores and restores the contents of a board to/from a datastore.
- [PartCanvas](src/client/PartCanvas/)
	- A reusable Roact component for rendering the contents of a board with `Part` instances relative to a particular `CanvasCFrame` and `CanvasSize`
	- Used in [SurfaceCanvas](src/client/ViewStateManager/SurfaceCanvas.lua)
- [FrameCanvas](src/client/FrameCanvas/)
	- A reusable Roact component for rendering the contents of a board with `Frame` instances inside `ScreenGui`s
	- Used in [GuiBoardViewer](src/client/DrawingUI/Components/GuiBoardViewer/) for the [DrawingUI](src/client/DrawingUI/)
- [DrawingUI](src/client/DrawingUI/)
	- Sets up and tears down the drawing UI [App](src/client/DrawingUI/App.lua) component, which is the primary interface for drawing in metaboard.
- [App](src/client/DrawingUI/App.lua)
	- Roact component for viewing and editing the contents of a chosen board. Some important components are listed.
		- [Toolbar](src/client/DrawingUI/Components/Toolbar/), for equipping and configuring different tools for drawing and erasing figures on the board. Also other menu buttons like undo/redo, and a close button.
		- [GuiBoardViewer](src/client/DrawingUI/Components/GuiBoardViewer/), renders the board state as a [FrameCanvas](src/client/FrameCanvas/), and shows a clone of the board instance underneath with a viewport frame.
		- [CanvasIO](src/client/DrawingUI/Components/CanvasIO.lua), handles user input by positioning a correctly sized button over the canvas.
	- The App component manages *state* for tools (which one is selected and what are the stroke-widths/color etc), as well as *state* for "UnverifiedDrawingTasks", which allows the client to see their own changes immediately without affecting the state of the board (which is kept consistent with the server's version of the board state)
	- There is also a [ToolQueue](src/client/UserInput/ToolQueue.lua) involved, which gathers all of the user inputs that occurred that frame and combines them into a single re-render for performance gains (otherwise can happen 2-3 times a frame).
- [ViewStateManager](src/client/ViewStateManager/)
	- Handles Board streaming - i.e. figures on far-away boards disappear to save on memory-usage.
	- [SurfaceCanvas](src/client/ViewStateManager/SurfaceCanvas.lua), uses [PartCanvas](src/client/PartCanvas/) to render the board state onto the surface of the board instance. Supports gradual loading of lines (instead of all in the same frame), so that board streaming works smoothly. Also handles VR drawing onto its surface, with UnverifiedDrawingTasks in the component state to see changes instantly (just like the DrawingUI App).

## Board, BoardClient, BoardServer

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
The instance is stored in the `_instance` key (see [Board Instance](#board-instance)).
There is some back and forth exchange between the client and server while the server is retrieving persistent board data from the
datastore, but eventually the client has a `BoardClient` object corresponding to each `BoardServer` object that the server has.

## Client-Server Communication

All communication between client and server takes place via the `BoardRemotes` object. It is created by the server **for each board**, and contains
a folder of remote events, which are parented to the board instance. The client retrieves this object from the server, because it must connect to the exact same remote event instances.

`BoardRemotes.lua` also contains a function (`BoardRemotes:Connect`) for connecting to both `OnServerEvent` and `OnClientEvent` for each of the remote events. There are some slightly different behaviour depending on whether its the server-side or client-side logic, but the majority of the code (which manipulates Figures, Drawing Tasks and Histories) is the same for the client and server. The client and server code were previously separate, but this introduced too many bugs when forgetting to make a change in both files.

## Board Instance

`Board.new` accepts either a `Model` or a `Part` for its `instance` argument, and stores it at `self._instance`.
If it's a `Part`, we treat that as the rectangular surface where figures should be placed. If it's a `Model`, then
we use the `PrimaryPart` of the model as the rectangular surface where figures should be placed. In both cases, we
refer to that surface as the surface part.

The underscore in `board._instance` is a convention which indicates *you should not interface directly with this piece of the Board object*.
The reason is the difference in behaviour if it's a `Model` vs if it's a `Part`, which should be an internal concern
of the board object. Instead we provide methods for uniform access to the surface part.

```lua
function Board:SurfacePart()
	return self._instance:IsA("Model") and self._instance.PrimaryPart or self._instance
end
```

The only other reason we might want to touch the `_instance` key is to grab a name for debugging/logging purposes.
We provide methods for doing this.

```lua
function Board:Name()
	return self._instance.Name
end

function Board:FullName()
	return self._instance:GetFullName()
end
```

Note that having too many of these kinds of methods should be considered an [anti-pattern](https://en.wikipedia.org/wiki/Anti-pattern), especially getter and setter methods. Instead of `Board:GetX()` and `Board:SetX(newX)`, it's better to just have `X` as a key in the board table. If there is a behaviour that is supposed to be triggered when the `X` key changes, then make a simple interface for external code to manually trigger that behaviour after modifying `X`. An example of this is the `Loaded` key and the `LoadedSignal` in `BoardServer`, which should be fired whenever `board.Loaded` becomes true. We could make a `:GetLoaded()` and `:SetLoaded(isLoaded)` method, where the `SetLoaded` method also fires the signal, with the intention of keeping that behaviour a responsibility of the board object, but this just obscures what's going on to the caller of `SetLoaded` and introduces two extra methods. Better to just write these two lines of code each time.

```lua
board.Loaded = true
board.LoadedSignal:Fire()
```

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

This data represents a [polyline](https://en.wikipedia.org/wiki/Polygonal_chain) of line segments (each of the given width, color, z-Index) joining the consecutive points in the Points array. The optional Mask table has entries of the form `[tostring(i)] = true`, where `1 <= i <= #Points-1`, which indicate that the line segment between `Points[i]` and `Points[i+1]` is hidden.

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

- What's this set/merge business? These functions are from the immutability data library [Sift](https://csqrl.github.io/sift/). They clone the first argument, then return that clone with the given key/keys changed. Why immutability? See the [Immutability section](#immutability).
- What's `drawingTask.Verified`? This is a flag set by the server so that side-effects are only performed when safe to do so (i.e. in the same order w.r.t. other drawing tasks). This allows clients to perform and manage their own "unverified" drawing tasks without affecting the board state. In `FreeHand`, the `NextFigureZIndex` of the board is incremented in the `Init` stage, and the resulting figure is added to the EraseGrid in the `Finish` stage.
- Why does every curve begin with two of the same point? This simplifies the logic in other areas of the code (EraseGrid, rendering) because they can assume every curve has length 2. This could change.

### Erasing

Erasing throws a spanner in the works because it is quite different to the "draw a figure" drawing tasks. It is hard to treat it as a standalone/removable contribution to the board state, since its high-level purpose is to modify the appearance of other figures. The solution we employ is to just record what is being erased from each figure within the drawing task itself. It is then the responsibility of the renderer to hide any parts of figures that have been erased by some drawing task in `board.DrawingTasks` (see [Rendering](#rendering)).

An erase drawing tasks has the following format
```lua
{
	Type: "Erase",
	Id: string,
	ThicknessYScale: number, -- the size of the eraser,
	FigureIdToMask: { [string]: FigureMask }
}
```

Here `FigureMask` depends on what kind of figure it is. For a `Curve`, a mask is a table indicating which line segments should be hidden. In general, the structure of the figure mask determines how parts of the figure can be erased. If it was just a boolean value, we could only erase all or none of the figure.

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

This poses a challenge when involving masks from `Erase` drawing tasks. Each figure needs to take into account all of the drawing tasks that erased part of it when rendering, but if we gather all of those masks and merge them into the figure data, we will either need to mutate the figure data (bad!) or we will have to create a new table for the modified figure, which will always be non-equal to the one created in the last render, even if it was the same resulting mask. Then the only way to shortcut the render process will be to check that all of the contents of the mask are the same as the mask from the previous render. This becomes an O(#lines) operation in the worst case (when most figures are at least partially erased).

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

### Combining board state into PureFigures

Here is the relevant code for producing these `PureFigure` components from the board state.

```lua
local figureMaskBundles = {}
local allFigures = table.clone(self.props.Figures)

for taskId, drawingTask in pairs(self.props.DrawingTasks) do

	if drawingTask.Type == "Erase" then
		local figureIdToFigureMask = DrawingTask.Render(drawingTask)
		for figureId, figureMask in pairs(figureIdToFigureMask) do
			local bundle = figureMaskBundles[figureId] or {}
			bundle[taskId] = figureMask
			figureMaskBundles[figureId] = bundle
		end

	else

		allFigures[taskId] = DrawingTask.Render(drawingTask)
	end
end
```

We create a new table, `allFigures` which will contain figures from `board.Figures` as well as figures from any drawing tasks that create figures.
At the same time we bundle together all of the masks for the same figure from every `Erase` drawing task.

We then create all of the PureFigures as follows.

```lua
local pureFigures = {}

for figureId, figure in pairs(allFigures) do

	pureFigures[figureId] = e(PureFigure, {

		Figure = figure,
		FigureMasks = self.props.FigureMaskBundles[figureId] or {},
		CanvasSize = self.props.CanvasSize,
		CanvasCFrame = self.props.CanvasCFrame,

	})
end
```

### Comment (Billy)

This is a fairly ad-hoc treatment of the different types of drawing tasks. Notice that `FreeHand` and `StraightLine` drawing tasks return a figure from their `Render` method (not a figureId -> figure entry), whereas `Erase` drawing tasks return a table with figureIds as keys and masks as values. Erasing is a very different beast from figure-drawing, so there's no *obvious* way of making the output of `DrawingTask.Render` uniform across different types of drawing tasks, while preserving the ability to quickly recognise when we don't need to update a `PureFigure`. This doesn't mean there's no natural way to do it.

If we don't have to preserve the ability to shortcut updates, then the behaviour of all types of drawing tasks could be made uniform by making them store a function that takes the figure table as an argument and returns a new one with whatever changes it wants to make (adding a new figure, or replacing a figure with one that has a different mask). Checking for equality between the new function and the old one will only tell us that either no figures need to be changed (if functions are equal) or some of them do but we can't know which.

So perhaps a drawing task should explicitly store a function *per-FigureId*. So every time a render occurs, for each figureId, we gather all of the functions for that figureId from all of the drawing tasks, and if they are equal to all of the previous functions, then we know we can shortcut the update.

What's the point of fussing over this? Well currently the behaviour of the Erase drawing task is fragmented between `src/common/DrawingTasks/Erase.lua`, and all of the various renderers that have to gather and apply the right mask to each figure when they encounter `drawingTask.Type == "Erase"`. So if you want to implement another type of drawing task that affects other figures (not just drawing a new figure), then you have to implement the render stage behaviour and shortcut detection in every `PureFigure` component in the repo under an `elseif drawingTask.Type == "OtherType"` clause.

In summary, I think a drawing task should tell you which figureIds it affects, and for each figureId:
1. How to update the figure at that figureId in the render step
2. Some kind of reference for this updater (or its generating data) which is changed whenever the drawing task modifies it, and is unchanged when the drawing task only modifies the updaters for other figureIds.

## Immutability

We make frequent use of the immutable data library, [Sift](https://csqrl.github.io/sift/), in order to know when and where a large data structure has changed.

For example, say we have a table `figures` stored at `board.Figures`, and `figures["abc"] = f1`, but we want to update `board.Figures` so that `"abc` points to a different figure `f2`. If we just modify `figures` by doing
```lua
figures["abc"] = f2
```
then the information of what was previously stored at this key is lost. So if another code context needs to check for differences to see what necessarily needs a re-render it has no way of detecting that something changed here. Of course, we could record as we go, all of the keys that changed in a separate table, but now we must pass this additional data around with the table (like `board.Figures` + `board.ChangedFigures`). But how do we know when to clear this changed figures table? What if we have multiple dependent systems that don't all update at the same time (and therefore should have different ideas of whats been changed).

The solution is to never modify the original table of figures, and instead create a new one with all the same entries, except for whatever changes to keys you want to make.
```lua
-- table.clone is extremely fast
local newFigures = table.clone(figures)
newFigures["abc"] = f2
```
Now we can tell that `newFigures` has different contents to `oldFigures` simply because `newFigures ~= oldFigures` returns `true`, and furthermore if we compared all of their keys we'd find that `newFigures["abc"] ~= oldFigures["abc"]`. This is exactly what we need for the render-shortcutting technique explained above (see [Rendering](#rendering)). Note that this also requires us to treat each figure as immutable.

### Sift

Essentially every operation in the sift library that returns a table starts with a `table.clone`, followed by some edit to the cloned table. The available functions are split between Arrays, Dictionaries, and Sets. These all operate on native lua tables, and the distinction is just about what kind of key-value pairs you have in the table. Arrays are just tables with contiguous integer keys starting at 1, dictionaries are just tables thought of as a key -> value mapping, and sets are just dictionaries where the value of any key is either `true` or `nil`.

For example. If we wanted to make a new figure table where the figure stored at key `"abc"` is the same as before, except its color changed to black and z-index changed to 3, we can make use of `Dictionary.set` and `Dictionary.merge` as follows.

```lua
f1 = newFigures["abc"]
local newFigures = Dictionary.set(figures, "abc", Dictionary.merge(f1, {

	Color = Color3.new(0,0,0),
	ZIndex = 3,

}))
```

After this code executes, the following is true
- `newFigures["abc"].Color == Color3.new(0,0,0)`
- `newFigures["abc"].ZIndex == 3`
- `figures["abc"] == f1`
- `newFigures["abc"] ~= f1`
- `newFigures ~= figures`

## Drawing UI

### ScreenGui caching

The `FrameCanvas` renders the board state using `Frame` instances, which are each assigned a `ZIndex` so that the figures are layered in the appropriate order. Putting all of the frames into the one `ScreenGui` would be the natural way to do things (grouped into folders per figure of course). However this introduces a performance issue, since every time a new frame is added, the Roblox Engine recalculates the z-order that it must render all of the frames in.

To solve this problem, we take advantage of the caching behaviour for [ScreenGuis](https://developer.roblox.com/en-us/api-reference/class/ScreenGui) (read the caching note at the top of the page). We can use one `ScreenGui` per figure, and so we're only every recomputing the appearance of one `ScreenGui` at a time while drawing.

In the current code (see [FrameCanvas/SectionedCurve.lua](src/client/FrameCanvas/SectionedCurve.lua)), we actually use a new `ScreenGui` for every 50 frames. This may not be necessary, and was written early on when Roact and its performance behaviour was a bit of a mystery (to me, Billy).
Performance while drawing is being worked on, so [FrameCanvas](src/client/FrameCanvas) may change a lot.

### Canvas positioning/sizing

An annoying consequence of using ScreenGuis per figure is that this resets the hierarchical positioning/sizing of GuiObjects. When you put Frames inside other Frames, you can set the position and size of the child Frame relative to the parent frame by using scalar values in the `UDim2` objects. However if this hierarchy is interrupted by a ScreenGui (i.e. Frame > ScreenGui > Frame), the inner Frames will be positioned relative to the entire viewport, not the frame containing the ScreenGui.

This is a problem because the lines need to appear within the board, which we are displaying in a particular sub-region of the board. A natural solution would be to simply apply some numeric transformation of the viewport's coordinates to the canvas region's coordinates. This is complicated a little by the fact that the position and size of the canvas uses aspectRatio and margin contraints, but it seems possible in principle.

Historically, we have instead solved this by placing a copy of the invisible canvas region Frame (along with its sizing/positioning constraints). This has the benefit of not being ruined when you resize the Roblox window, but there is suspicion of this solution incurring a performance cost, so we might dump this benefit in favor of better performance.

### Unverified DrawingTasks (clientside prediction)

TODO

## ViewStateManager

TODO

## Persistence

TODO