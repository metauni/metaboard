# metaboard

Interactive drawing boards in Roblox.

## Installation

Get the latest [release files](https://github.com/metauni/metaboard/releases)
and drag `metaboard.rbxmx` into `ServerScriptService`. This contains
the ServerScripts, LocalScripts and Guis for handling all metaboard interaction,
and are automatically distributed when you start your Roblox game.

Then you can create as many boards as you like, either by copying `Whiteboard.rbxmx`,
`BrickWallBoard.rbxmx` into `Workspace`, or creating your own by following the
[board structure](##-board-structure).

### Sync via Rojo

Download the latest release of [foreman](https://github.com/Roblox/foreman).
Move it somewhere within your `$PATH` (e.g. `/usr/local/bin`), and make it executable (`chmod +x /path/to/foreman`).

Then in the directory of this repository,
run
```bash
foreman install
```
You may get an error if you are running Mac OS X, in which case check Security & Privacy under System Preferences and click `Allow Anyway` for foreman. This should install Rojo, but perhaps not in your `$PATH`. It's up to you to fix that, but for example on Mac OS X it might be in `~/.foreman/bin`.

To build and sync the demo world:
```bash
rojo build --output "demo.rbxlx" demo.project.json
rojo plugin install
rojo serve demo.project.json
```
Then open `demo.rbxlx` in Roblox Studio and click `Connect` in the Rojo window.
Now you can edit any of the files in `src` with your favourite editor and your
changes will be synced into Roblox Studio.

To sync just the backend code (scripts + gui) run `rojo serve`.
This uses the `default.project.json` file, and can be synced into any
place file without making any `Workspace` changes.

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Board Structure

You can make pretty much any flat surface into a drawing board.
To turn a Part into a board, use the [Tag Editor](https://devforum.roblox.com/t/tag-editor-plugin/101465)
plugin to give it the tag `"metaboard"`. Then add any of the following optional
values as children.

| Object      | Name        | Value | Description |
| ----------- | ----------- | ----------- | ----- |
| ColorValue  | Color       | `Color3`| The colour of the canvas Gui when a player clicks on this board |
| StringValue | Face        | `String` (one of "Front", "Back", "Left", "Right", "Top", "Bottom") | The surface of the part that should be used as the board |
| BoolValue   | Clickable   | `Bool` | Set to false to prevent opening this board in the gui |

For more customised positioning of the board, make an invisible part for the board and size/position on your model however you like.

## Subscriber Boards

Any metaboard can be a subscriber of another board (the broadcaster), meaning anything that appears on the broadcaster board is replicated onto the subscriber board.

There are two ways of setting up this link
1. Create a folder called "Subscribers" as a child of the broadcaster, then make an `ObjectValue` called "Subscriber" and set its `Value` to the subscriber. You can make any number of subscribers in this folder.
2. Create an `ObjectValue` under the subscriber called "SubscribedTo" and set its `Value` to the broadcaster.
	You can make any number of these to subscribe to multiple boards (they must all be called "SubscribedTo").

When you start your world, any links made with the second method will be converted according to use the first method.

## Persistent Boards

Any metaboard can be synced to a DataStore so that it retains its contents across server restarts. To enable persistence for a board, create an `IntValue` under the board called "PersistId" and set it it to the subkey used to store the board contents.

## TODO
- [x] Fix line intersection algorithm (tends to not recognise intersection with long lines)
	- Check for numerical errors (or just bad logic)
	- Make a test Gui that highlights a line when it is intersected?
	- Check intersection with Frame properties instead of lineInfo?
	- Separation Axis Theorem? Maybe not the best, our lines are not polygons.

- [ ] Make erasing work between mouse movements (intersection of eraser path and line)

- [ ] Other shape tools
	- Guis
		- Make everything out of lines? (circles can be squares with UICorners)
		- Or use images

- [ ] Undo and erase tool

- [ ] VR support

- [ ] Select lines and move them tool.
	- What happens while being moved. Can those lines be erased by other players?

- [ ] Line smoothing
	- Apply CatRom smoothing just to long lines above some threshold

- [ ] Google docs style indicators in GUI to show which player is currently drawing

- [ ] Board textures/images for gui.

## Module descriptions

### Client module scripts (StarterPlayerScripts)
- `CanvasState`
	- Maintains the lines drawn on the canvas while the Gui is open
	- Listens to the currently opened boards Curves folder (the in-world curves)
		to add and remove lines when other players modify the board
	- `Drawing` and `ClientDrawingTasks` access `CanvasState`'s function to update
		the lines that are on the board gui
- `Drawing`
	- Tracks the currently equipped tool, pen mode, current drawing task and curve index of the local player
	- Responds to mouse movement and triggers `ClientDrawingTasks` to tell them when to update some task.
- `ClientDrawingTasks`
	- Creates short-term "Drawing Tasks: for each tool/pen mode which describes their behaviour
		over the lifetime of a tool-down, tool-move, tool-move,..., tool-lift.
- `Buttons`
	- Connect all the buttons in the toolbar
- `PersonalBoardTool`
	- Creates and adds tool to backpack which triggers personal board events.

### Server module scripts (ServerScriptService)
- `MetaBoard`
	- Maintains the boards that exist in the workspace
	- Reacts to drawing task events from the clients by triggering the associated task
		from `ServerDrawingTasks`
- `ServerDrawingTasks`
	- Creates short term drawing tasks to synchronise with the client's drawing tasks.
- `PersonalBoardManager`
	- Creates personal board clones for each player when they join, and responds to
		requests to show/hide a players personal board.

## Generating a Release

The `metaboard.rbxmx` file is generated like this
```bash
rojo build --output "build.rbxlx"
remodel run metaboard_packager.lua
```

The first command builds a place file according to `default.project.json`.
The second command uses [remodel](https://github.com/rojo-rbx/remodel) to extract all of the components of metaboard,
and packages them all within the `MetaBoardServer` folder, and exports this 
as a `metaboard.rbxmx` file. The startup server script then redistributes these
components on world boot..
