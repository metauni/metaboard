# metaboard

Interactive drawing boards in Roblox.

## Installation

There are two components to install: the metaboard backend code, and a metaboard model to draw on.

### From Roblox

You can find [metaboard](https://www.roblox.com/library/8573087394/metaboard) in Roblox Studio by searching "metaboard" in the Toolbox.
Double-click it to insert it (it will appear under `Workspace`) and then move it to `ServerScriptService`. This contains the Scripts,
LocalScripts and Guis for handling all metaboard interaction, which are automatically
distributed when you start your Roblox game.
You will need to manually update this file if you want the newest release.

### From Github Releases

Download the [latest release](https://github.com/metauni/metaboard/releases/latest). In Roblox Studio, right click on `ServerScriptService`, click `Insert from File` and insert the `metaboard-v*.rbxmx` file. This contains the Scripts,
LocalScripts and Guis for handling all metaboard interaction, which are automatically
distributed when you start your Roblox game.
You will need to manually update this file if you want the newest release.

## Adding boards to your game

[metauni](https://www.roblox.com/groups/13108882/metauni#!/about) maintains a few example boards you can use.
The easiest method to add these in Roblox Studio is to go to `Toolbox > Marketplace` and search "metaboard".

- [WhiteBoard](https://www.roblox.com/library/8543134618/metaboard-WhiteBoard)
- [BlackBoard](https://www.roblox.com/library/8542483968/metaboard-BlackBoard)
- [TechBoard](https://www.roblox.com/library/8543176248/metaboard-TechBoard)
  - This is really two boards, both the `FrontBoard` and `BackBoard` are tagged as metaboards.

Don't be afraid to resize and stretch these boards as you please!

## Board Structure

A metaboard can be either a `BasePart` or a `Model` with a `PrimaryPart`.
To turn a `BasePart`/`Model` into a metaboard, use the [Tag Editor](https://devforum.roblox.com/t/tag-editor-plugin/101465)
plugin to give it the tag `"metaboard"`. Then add any of the following optional
values as children.

| Object      | Name        | Value | Description |
| ----------- | ----------- | ----------- | ----- |
| StringValue | Face        | `String` (one of "Front" (default), "Back", "Left", "Right", "Top", "Bottom") | The surface of the part that should be used as the board |
| BoolValue   | Clickable   | `Bool` | Set to false to prevent opening this board in the gui |
| StringValue | DefaultPenAColor | `String` (one of "Black", "Blue", "Green", "Orange", "Pink", "Purple", "Red", "White") | Overrides Config.Drawing.Defaults.PenAColor |
| StringValue | DefaultPenBColor | `String` (one of "Black", "Blue", "Green", "Orange", "Pink", "Purple", "Red", "White") | Overrides Config.Drawing.Defaults.PenBColor |

If the metaboard is a `Model`, the `PrimaryPart` should be set to the part which defines the drawing surface of the model (make sure the right `Face : StringValue` is configured).

For more customised positioning of the board, make an invisible part for the board and size/position it on your model however you like (you should tag the parent model as the metaboard, not the invisible part, and remember to set the invisible part as the `PrimaryPart`).

## Persistent Boards

Any metaboard can be synced to a DataStore so that it retains its contents across server restarts. To enable persistence for a board, create an `IntValue` under the board called "PersistId" and set the value to an integer specific to that board. If you want the persistent board to work in Roblox Studio, make sure to `Enable Studio Access to API Services` under `Game Settings > Security`.

Since persistent boards use the Roblox DataStore API there are several limitations you should be aware of:

- In private servers the DataStore key for a board is of the form "ps\<ownerId>:metaboard\<PersistId>". Since keys for DataStores cannot exceed `50` characters in length, and player Ids are (currently) eight digits, that means that you should keep `PersistId`'s to `30` digits or less.

- The DataStore keys for persistent boards are the same in any live server, and `SetAsync` is currently used rather than `UpdateAsync`, so there is a risk of data corruption if two players in different servers attempt to the use the "same" persistent board. We strongly recommend therefore that you reserve use of persistent boards to *private servers*.

- The `GetAsync` [rate limit](https://developer.roblox.com/en-us/articles/Data-store) on DataStores has been handled by throttling the loading of persistent boards so that they never hit this limit (the throttling is conservative).
