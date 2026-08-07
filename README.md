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

Tourists have four configurable archetypes: regular photographers, fast children that knock the player back, influencers with long selfie camera zones, and elderly groups that follow a flag-carrying guide. They spawn around the floor, travel between artworks with smooth wall steering, and avoid nearby visitors. Regular photographers take pictures both along the route and after reaching an artwork. Their spawn weights and behavior overrides are under `crowd.type_weights` and `tourist_types` in `game_params.json`.

Artwork travel uses a shared A* grid per floor. `tourist.pathfinding_cell_size` controls route resolution, while `tourist.pathfinding_clearance` controls how far planned paths stay from walls and cover.

`crowd.start_exclusion_radius` defines the safe entrance area. At runtime it is automatically increased when necessary so it remains larger than every camera and child detection range.

Set `crowd.seed` to a non-negative integer for a reproducible crowd layout, which is useful when tuning or reproducing bugs. Keep it at `-1` for a different layout each run.

`crowd.minimum_regular_photographers` guarantees that every floor retains some still photographers even when a large elderly group consumes much of the crowd budget.

Crowd size is calculated from usable floor area using `crowd.tourists_per_100k_pixels`; walls, desks, kiosks, and columns reduce that area. `crowd.artwork_density_bias` controls how strongly initial tourist placement clusters toward artwork while retaining random spread across the floor.

## Tests

Run the automated gameplay suite headlessly:

```bash
godot --headless --path . --log-file ./godot-tests.log --script res://tests/test_runner.gd
```

Pull requests run the same suite through GitHub Actions.

Under `Markers`, drag the entrance, exit, or stairs. The running game reads these scene positions automatically.

## Demo
Webpage: https://4d23.github.io/camera_dodge/ 
Control: W A S D Space (dash)
