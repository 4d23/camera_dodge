# camera_dodging

A small Godot 4 top-down survival prototype. Cross a crowded museum from the entrance to the Mona Lisa without being caught in other tourists' photos.

## Play

1. Open this folder in Godot 4.x.
2. Run the project (`F6`/`F5`).
3. Move with WASD or the arrow keys.
4. Press `Space` to dash in your movement direction.
5. Yellow cones show a camera being aimed. Leave the frame before it flashes red.
6. Three photo exposures end the run. Reach the exit to finish. Press `R` to restart.

Museum artwork textures are stored under `res://assets/artworks`; characters and environment shapes remain procedurally drawn.

## Editing the museum in Godot

Open either floor scene directly in the Godot editor:

- `res://levels/level_0.tscn`
- `res://levels/level_1.tscn`

Under `Walls`, select and drag a wall in the 2D viewport. Change its `Wall Size` in the Inspector to resize it.

Under `Artworks`, select and drag an artwork. Its name, room, and texture are editable in the Inspector. Duplicate an artwork node to add another featured room, then assign a different texture and metadata.

Gameplay tuning values are centralized in `res://config/game_params.json`. Edit this file to change player speed, artwork viewing duration, crowd density and spacing, tourist movement speed, camera radius/FOV, and camera timing.

Tourists have four configurable archetypes: regular photographers, fast children that knock the player back, influencers with long selfie camera zones, and synchronized elderly tour groups that photograph the same artwork. Their spawn weights and behavior overrides are under `crowd.type_weights` and `tourist_types` in `game_params.json`.

## Tests

Run the automated gameplay checks headlessly:

```bash
godot --headless --path . --log-file ./godot-tests.log --script res://tests/test_runner.gd
```

The suite checks every tourist archetype, movement and dash controls, artwork viewing, and entrance/exit behavior. Pull requests run the same suite through GitHub Actions.

Under `Markers`, drag the entrance, exit, or stairs. The running game reads these scene positions automatically.

## Demo
Webpage: https://4d23.github.io/camera_dodge/ 
Control: W A S D Space (dash)
