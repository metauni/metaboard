# metaboard

Interactive drawing boards in Roblox.

## Installation

### From Roblox
Grab the [metaboard package]() (COMING SOON) from Roblox, go to Roblox Studio and
drag it into `ServerScriptService`. This contains the ServerScripts,
LocalScripts and Guis for handling all metaboard interaction, and are automatically
distributed when you start your Roblox game. This package will update automatically
to the latest release of metaboard.

### From Github Releases

Download the [latest release](https://github.com/metauni/metaboard/releases/latest)
and drag the `metaboard.rbxmx` file into `ServerScriptService`. You will need
to manually update this file if you want the newest release.

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

If the metaboard is a `Model`, the `PrimaryPart` should be set to the part which defines the drawing surface of the model (make sure the right `Face : StringValue` is configured).

For more customised positioning of the board, make an invisible part for the board and size/position it on your model however you like (you should tag the parent model as the metaboard, not the invisible part, and remember to set the invisible part as the `PrimaryPart`).

## Subscriber Boards

Any metaboard can be a subscriber of another board (the broadcaster), meaning anything that appears on the broadcaster board is replicated onto the subscriber board.

There are two ways of setting up this link
1. Create a folder called "Subscribers" as a child of the broadcaster, then make an `ObjectValue` called "Subscriber" and set its `Value` to the subscriber. You can make any number of subscribers in this folder.
2. Create an `ObjectValue` under the subscriber called "SubscribedTo" and set its `Value` to the broadcaster.
	You can make any number of these to subscribe to multiple boards (they must all be called "SubscribedTo").

When you start your world, any links made with the second method will be converted according to use the first method.

### WARNING
> Subscriber boards can have undefined behaviour, and can introduce performance strains if used liberally.

## Persistent Boards

Any metaboard can be synced to a DataStore so that it retains its contents across server restarts. To enable persistence for a board, create an `IntValue` under the board called "PersistId" and set it it to the subkey used to store the board contents.

Since persistent boards use the Roblox DataStore API there are several limitations you should be aware of:

* In private servers the DataStore key for a board is of the form "ps<ownerId>:metaboard<PersistId>". Since keys for DataStores cannot exceed `50` characters in length, and player Ids are (currently) eight digits, that means that you should keep `PersistId`'s to `30` digits or less.

* The DataStore keys for persistent boards are the same in any live server, and `SetAsync` is currently used rather than `UpdateAsync`, so there is a risk of data corruption if two players in different servers attempt to the use the "same" persistent board. We strongly recommend therefore that you reserve use of persistent boards to *private servers*.

* Persistent boards will be locked and only Clear allowed if the board reaches a threshold where it would exceed the storage requirement for the DataStore.

* The `GetAsync` [rate limit](https://developer.roblox.com/en-us/articles/Data-store) on DataStores has been handled by throttling the loading of persistent boards so that they never hit this limit (the throttling is conservative).

* Changed persistent boards are autosaved by default every `30sec`.

* On server shutdown there is a `30sec` hard limit, within which all boards which have changed after the last autosave must be saved if we are to avoid dataloss. Given that `SetAsync` has a rate limit of `60 + numPlayers * 10` calls per minute, and assuming we can spend at most `20sec` on boards, that means we can support at most `20 + numPlayers * 3` changed boards since the last autosave if we are to avoid dataloss, purely due to rate limits. A full board costs about `1.2sec` to save under adversarial conditions (i.e. many other full boards). So to be safe we can afford at most `16` changed boards per autosave period.