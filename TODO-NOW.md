- [ ] Admin controls
	- [ ] Set up events and DrawingUI state
	- [ ] Deny user input when not allowed
	- [ ] Show/hide toolbar based on state

- [ ] Drawing Task cancelling
	- [ ] Set up DrawingTaskCancelled event
	- [ ] Server fire cancel when admin controls stop someone drawing
	- [ ] Server fire cancel when client is kicked or leaves while drawing
	- [ ] Server fire cancel when new drawing task starts after old one finishes
	- [ ] Client remove unverified drawing task if it was cancelled
	- [ ] Server fire cancel after 5s without update/finish
	- [ ] Does erase grid or undo/redo require any changes to account for cancel?

- [ ] Persistence
	- [ ] Test multiple chunk storing/retrieving
	- [ ] Make it work with pockets
	- [ ] Add format version # to /info
	- [ ] Write version converter
	- [ ] Convert old boards

- [ ] Personal boards
	- [ ] Reintegrate

- [ ] Performance
	- [ ] Debug performance slow down after lots of lines

- [ ] ViewController (Distance rendering)
	- [ ] Design line/curve -> memory usage heuristic -> Num boards viewable
	- [x] Debug active -> dead -> active bug from last week

- [ ] 