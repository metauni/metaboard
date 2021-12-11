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