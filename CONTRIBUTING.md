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

## DataStore

[Notes](https://devforum.roblox.com/t/details-on-datastoreservice-for-advanced-developers/175804)

## Module descriptions

> WARNING: OUT OF DATE

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

## TODO

- [ ] Make erasing work between mouse movements (intersection of eraser path and line)

- [ ] Other shape tools
	- Guis
		- Make everything out of lines? (circles can be squares with UICorners)
		- Or use images

- [ ] VR support

- [ ] Select lines and move them tool.
	- What happens while being moved. Can those lines be erased by other players?

- [ ] Line smoothing
	- Apply CatRom smoothing just to long lines above some threshold

- [ ] Google docs style indicators in GUI to show which player is currently drawing
