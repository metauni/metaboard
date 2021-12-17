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

For more customised positioning of the board, make an invisible part for the board and size/position on your model however you like.

## TODO
- [ ] Fix line intersection algorithm (tends to not recognise intersection with long lines)
  - Check for numerical errors (or just bad logic)
  - Make a test Gui that highlights a line when it is intersected?
  - Check intersection with Frame properties instead of lineInfo?
  - Separation Axis Theorem? Maybe not the best, our lines are not polygons.

- [ ] Make erasing work between mouse movements (intersection of eraser path and line)

- [ ] Other shape tools
  - Guis
    - Make everything out of lines? (circles can be squares with UICorners)
    - Or use images
  - WorldBoard
    - Ideally make out of handle adornments
    
- [ ] Make smart/robust machine for detecting kinds of changes to the world board and updating the board gui

- [ ] Subscriber boards
  - Make a collection service tag for subscriber boards
  - ObjectValue which links to the board its subscribed
  - Account for cycles
  - BoolValue for whether a subscriber board can be opened in Gui

- [ ] VR support

- [ ] Select lines and move them tool.
  - What happens while being moved. Can those lines be erased by other players?

- [ ] Board persistence
  - Board pages (players store page in backpack and apply it to a board later)
  - Save boards to datastore before server closes

- [ ] Line smoothing
  - Apply CatRom smoothing just to long lines above some threshold

- [ ] Cache gui lines

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
  

