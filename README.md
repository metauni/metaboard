# metaboard

Interactive drawing boards in Roblox.

## Getting Started
Clone this repo, or download it via `Code -> Download ZIP`.

### Play the demo
To try out the demo, just open `demo.rbxlx` in Roblox Studio.

### Add metaboard to your own Roblox game

Open your place file Roblox Studio and drag `metaboard.rbxmx` into
`ServerScriptService`. Then drag `WhiteboardModel.rbxmx` into the `Workspace`.
You can rename and clone this whiteboard model as you wish.

### Via Rojo

Download the latest release of [foreman](https://github.com/Roblox/foreman),
and add it to your path.

Then in the directory of this repository,
run
```bash
foreman install
rojo plugin install
rojo serve
```

Then go to the Rojo plugin in Roblox Studio and click `Connect`.
This will add all of the backend code. Finally, copy the `WhiteboardModel.rbxmx`
file into your Workspace (make copies and edit this board as you please).

Further configuration can be found in `ReplicatedStorage.MetaBoardCommon.MetaBoardConfig`.

For more help, check out [the Rojo documentation](https://rojo.space/docs).