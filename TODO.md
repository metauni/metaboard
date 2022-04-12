## Now
- [ ] Clear Button
  - [ ] Add button to UI
  - [ ] Set up remote events
- [ ] Store tool state with board on UI close (and restore on open) 
- [ ] Allow default color palette per-board (how?)
  - [ ] Cleanup Config File (colors)
- [ ] Erase Grid
  - [ ] Decide between general drawing task grid insertion vs figure based insertion
  - [ ] Get ghost figures to work on provisional canvas
- [ ] Send board to client on demand
  - [ ] When they join the game
  - [ ] When they "stream" the board in
  - Remember that the client should receive the board in a state that they can
    apply the next drawing task remote events to, and remain in sync with everyone else
- [ ] Make multi-canvas
  - Replacement for subscriber boards. It's just a module which abstracts over
  multiple canvases, and echos every interaction to all of the canvases
- [ ] Make verified drawing tasks invisible until they are finished, and then show them
  - IMPORTANT: this counts as desync between what clients have on the "true canvas", so
    it'd be ideal if this didn't affect the drawing task data itself. Perhaps I'm being
    paranoid.
  - Maybe only applicable for non-erasing drawing tasks.
- [ ] What should happen to old drawing tasks?
- [ ] Make low detail canvas
  - [ ] Limited lines per curve canvas
  - [ ] Greedycanvas canvas
  - [ ] GUI based canvases (better resolution than parts in viewport)
  - [ ] Distance logic to dump far canvases (and board?), and restore when close enough.
        At a medium distance, the board should re-render after enough changes have been made
- [ ] Attention Pen Tool
- [ ] Palm rejection
- [ ] Persistence
  - [ ] Make a curve serialisation method
  - [ ] Make drawing task serialisation methods
- [ ] Make board permissions work (Admin commands)
  - [ ] Make UI dependent on permission
- [ ] Animate board moving in front of camera when opening board
- [ ] Personal boards

## Future
- [ ] Show "pending" status in drawing UI when the board is catching up on something
- [ ] Circle Tool
- [ ] Rectangle Tool
- [ ] Speaker/audience UI
  - [ ] See who is watching the board
  - [ ] See who is drawing on the board
  - [ ] See who has their hand raised
  - [ ] See who has permission to draw on the board and buttons to give draw access