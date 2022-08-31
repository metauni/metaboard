# metaboard

Multiplayer drawing boards for sharing knowledge in Roblox.

![](./metaboard-cover.png)

## Installation

There are two components to install: the metaboard backend code, and a metaboard model to draw on.

<!-- ### From Roblox - WARNING: NOT UP TO DATE
You can find [metaboard](https://www.roblox.com/library/8573087394/metaboard) in Roblox Studio by searching "metaboard" in the Toolbox.
Double-click it to insert it (it will appear under `Workspace`) and then move it to `ServerScriptService`. This contains the Scripts,
LocalScripts and Guis for handling all metaboard interaction, which are automatically
distributed when you start your Roblox game.
You will need to manually update this file if you want the newest release. -->

### From Github Releases
Download the [latest release](https://github.com/metauni/metaboard/releases/latest) (look for `metaboard-v*.rbxm`). In Roblox Studio, right click on `ServerScriptService`, click `Insert from File` and insert the `metaboard-v*.rbxm` file. This contains the Scripts,
LocalScripts and Guis for handling all metaboard interaction and DataStore persistence.
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

A metaboard can be either a `Part` or a `Model` with a `PrimaryPart` (the latter is recommended).
To turn a `Part`/`Model` into a metaboard, use the [Tag Editor](https://devforum.roblox.com/t/tag-editor-plugin/101465)
plugin to give it the tag `"metaboard"`. Then add any of the following optional
values as children.

| Object      | Name        | Value | Description |
| ----------- | ----------- | ----------- | ----- |
| StringValue | Face        | `String` (one of "Front" (default), "Back", "Left", "Right", "Top", "Bottom") | The surface of the part that should be used as the board |

If the metaboard is a `Model`, the `PrimaryPart` should be set to the part which defines the drawing surface of the model (make sure the right `Face : StringValue` is configured).

For more customised positioning of the board, make an invisible part for the board and size/position it on your model however you like (you should tag the parent model as the metaboard, not the invisible part, and remember to set the invisible part as the `PrimaryPart`).

## Custom Configuration

All of the configuration values used in metaboard are stored in a ModuleScript at `metaboard -> metaboardCommon -> Config`. There are cases where you may want to
use different config values on a per-place basis. Instead of modifying the `Config` script, you can copy the ModuleScript called `metaboardPlaceConfig` from `metaboard` to `ReplicatedStorage`. This ModuleScript returns a function which takes the config table as its argument and modifies the keys (no return value). All scripts that import the original Config file will receive the table with these edits applied (but only if `metaboardPlaceConfig` is a child of `ReplicatedStorage`).

You can keep this same config file around when you update the metaboard package.

## Persistent Boards

Any metaboard can be synced to a DataStore so that it retains its contents across server restarts.

By default, metaboard uses a datastore called `"MetaboardPersistence"` to save and restore board data. You can configure which datastore is used in `metaboardPlaceConfig`. For example you could use a different datastore for each place. There you can also set `Config.Persistence.ReadOnly` to `true`, so that you can see and draw on the existing boards in Studio without modifying anything in the datastore.

Note that `Config.Persistence.DataStoreName` is ignored in pockets, where automatic naming is used.

To enable persistence for a board, create an `IntValue` under the board called `PersistId` and choose a unique value. This value is used to determine the key in the datastore where the board data will be saved, so it must be unique to prevent overwriting another board's data. You should also keep track of keys you've used in the past for the same reason.

Since persistent boards use the Roblox DataStore API there are several limitations you should be aware of:

<!-- * In private servers the DataStore key for a board is of the form "ps<ownerId>:metaboard<PersistId>". Since keys for DataStores cannot exceed `50` characters in length, and player Ids are (currently) eight digits, that means that you should keep `PersistId`'s to `30` digits or less. -->

* The DataStore keys for persistent boards are the same in any live server, and `SetAsync` is currently used rather than `UpdateAsync`, so there is a risk of data corruption if two players in different servers attempt to the use the "same" persistent board. We strongly recommend therefore that you reserve use of persistent boards to *private servers*.

* Changed persistent boards are autosaved by default every `30sec` - this can be modified (see [Custom Configuration](#custom-configuration)).

* On server shutdown there is a 30sec hard limit, within which all boards which have changed after the last autosave must be saved if we are to avoid dataloss. A full board costs about 1.2sec to save under adversarial conditions (i.e. many other full boards). So if we assume we have 20 of those 30 seconds for metaboard shutdown, we can afford at most 16 changed boards per autosave period. There is a budget for datastore requests, but the more likely bottleneck is save time per-board.

## License

metaboard uses the MPL-2.0 License. See [LICENSE](./LICENSE).

External packages used in metaboard can be found under [packages](./packages/), and license information for those packages in [packages/LICENSES.md](packages/LICENSES.md).