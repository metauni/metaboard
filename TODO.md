## Now

### UI/Drawing Tools
- [ ] Clear Button
	- [ ] Add button to UI
	- [ ] Set up remote events
- [ ] Store tool state with board on UI close (and restore on open) 
- [ ] Allow default color palette per-board
	- [ ] Cleanup Config File (colors)
- [ ] Attention Pen Tool
- [ ] Palm rejection
- [ ] Circle Tool
- [ ] Rectangle Tool


### Clientside canvas stuff
- [x] Send board to client on demand
	- [x] When they join the game
	- [ ] When they "stream" the board in
	- Remember that the client should receive the board in a state that they can
		apply the next drawing task remote events to, and remain in sync with everyone else
- [x] Make it possible to add multiple canvases to a board, simulating "subscriber boards"
- [x] Make verified drawing tasks invisible until they are finished, and then show them
	- IMPORTANT: this counts as desync between what clients have on the "true canvas", so
		it'd be ideal if this didn't affect the drawing task data itself. Perhaps I'm being
		paranoid.
	- Maybe only applicable for non-erasing drawing tasks.
- [ ] What should happen to old drawing tasks?
	- Answer. Drawing Task queue + finalised "figures"
- [ ] Make low detail canvas
	- [ ] Limited lines per curve canvas
	- [ ] Greedycanvas canvas
	- [x] GUI based canvases (better resolution than parts in viewport)
	- [ ] Distance logic to dump far canvases (and board?), and restore when close enough.
				At a medium distance, the board should re-render after enough changes have been made

## Other
- [ ] Persistence
	- [x] Make a curve serialisation method
	- [x] Make drawing task serialisation methods
	- [ ] Get startup and shutdown working (especially with lots of full boards)
- [x] Erase Grid
- [ ] Make board permissions work (Admin commands)
	- [ ] Make UI dependent on permission
- [ ] Animate board moving in front of camera when opening board
- [ ] Personal boards

## Future
- [ ] Lockable boards
- [ ] Fast cups (?)
- [ ] Show "pending" status in drawing UI when the board is catching up on something
- [ ] Speaker/audience UI
	- [ ] See who is watching the board
	- [ ] See who is drawing on the board
	- [ ] See who has their hand raised
	- [ ] See who has permission to draw on the board and buttons to give draw access
- [ ] Enable drawing on board in "Normal" mode with zooming/moving camera
- [ ] Discount VR mode.
- [ ] Board viewing in Studio edit mode.
- [ ] Web app board viewing
- [ ] Screenshot Mode https://github.com/metauni/metaboard/issues/49
- [ ] Info display and delete button for historical boards https://github.com/metauni/metaboard/issues/51

{string} -> {number} -> {number}
