# camera_dodging

A small Godot 4 top-down survival prototype. Cross a crowded museum from the entrance to the Mona Lisa without being caught in other tourists' photos.

## Play

1. Open this folder in Godot 4.x.
2. Run the project (`F6`/`F5`).
3. Move with WASD or the arrow keys.
4. Yellow cones show a camera being aimed. Leave the frame before it flashes red.
5. Three photo exposures end the run. Reach the Mona Lisa to win. Press `R` to restart.

Museum artwork textures are stored under `res://assets/artworks`; characters and environment shapes remain procedurally drawn.

## Editing the museum in Godot

Open either floor scene directly in the Godot editor:

- `res://levels/level_0.tscn`
- `res://levels/level_1.tscn`

Under `Walls`, select and drag a wall in the 2D viewport. Change its `Wall Size` in the Inspector to resize it.

Under `Artworks`, select and drag an artwork. Its name, room, texture, and visit radius are editable in the Inspector. Duplicate an artwork node to add another featured room, then assign a different texture and metadata.

Under `Markers`, drag the entrance, exit, or stairs. The running game reads these scene positions automatically.

## Demo
Webpage: https://4d23.github.io/camera_dodge/ 
