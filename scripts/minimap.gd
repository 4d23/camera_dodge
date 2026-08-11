class_name MuseumMinimap
extends Control

const WORLD_SIZE := Vector2(2400, 1800)
const REGISTRATION_COLOR := Color("#ff8c61")

var player: CharacterBody2D
var level: MuseumLevel
var floor_number := 0

func configure(player_node: CharacterBody2D, level_node: MuseumLevel, floor: int) -> void:
	player = player_node
	set_level(level_node, floor)

func set_level(level_node: MuseumLevel, floor: int) -> void:
	level = level_node
	floor_number = floor
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null or level == null:
		return

	var available_rect := Rect2(Vector2.ZERO, size)
	var scale_factor := minf(available_rect.size.x / WORLD_SIZE.x, available_rect.size.y / WORLD_SIZE.y)
	var map_size := WORLD_SIZE * scale_factor
	var map_rect := Rect2(available_rect.position + (available_rect.size - map_size) * 0.5, map_size)
	draw_rect(map_rect, Color(0.08, 0.10, 0.12, 0.58), true)

	for wall: Rect2 in level.wall_rects():
		var map_wall := Rect2(map_rect.position + wall.position * scale_factor, wall.size * scale_factor)
		draw_rect(map_wall, Color(0.88, 0.82, 0.71, 0.9), true)

	# Show the portion of the floor currently visible through the game camera.
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size * 0.5
	var camera_center := Vector2(
		clampf(player.global_position.x, half_view.x, WORLD_SIZE.x - half_view.x),
		clampf(player.global_position.y, half_view.y, WORLD_SIZE.y - half_view.y)
	)
	var visible_world_rect := Rect2(camera_center - half_view, viewport_size)
	var visible_map_rect := Rect2(map_rect.position + visible_world_rect.position * scale_factor, visible_world_rect.size * scale_factor)
	draw_rect(visible_map_rect, Color(0.21, 0.84, 1.0, 0.12), true)
	draw_rect(visible_map_rect, Color("#36d7ff"), false, 2.0)

	for artwork in level.artwork_nodes():
		# Match the framed rectangular artwork pattern used on the museum floor.
		var point := _map_point(artwork.global_position, map_rect, scale_factor)
		draw_rect(Rect2(point - Vector2(3.5, 4.5), Vector2(7.0, 9.0)), Color("#5b4636"), true)
		draw_rect(Rect2(point - Vector2(2.0, 3.0), Vector2(4.0, 6.0)), Color("#f4d35e"), true)
	for wall in level.get_node("Walls").get_children():
		if wall.structure_type == "registration_desk":
			var point := _map_point(wall.global_position, map_rect, scale_factor)
			draw_rect(Rect2(point - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), REGISTRATION_COLOR, true)
	_draw_location_marker("Markers/Stairs", map_rect, scale_factor)
	_draw_location_marker("Markers/Entrance", map_rect, scale_factor)
	_draw_location_marker("Markers/Exit", map_rect, scale_factor)

	var player_point := map_rect.position + player.global_position * scale_factor
	draw_circle(player_point, 3.5, Color("#ffffff"))
	draw_rect(map_rect, Color(1, 1, 1, 0.22), false, 1.0)

func _map_point(world_point: Vector2, map_rect: Rect2, scale_factor: float) -> Vector2:
	return map_rect.position + world_point * scale_factor

func _draw_location_marker(path: String, map_rect: Rect2, scale_factor: float) -> void:
	var marker := level.get_node_or_null(path) as MuseumLocationMarker
	if marker == null:
		return
	var point := _map_point(marker.global_position, map_rect, scale_factor)
	draw_circle(point, 4.0, Color(0.04, 0.05, 0.06, 0.9))
	draw_circle(point, 2.8, marker.marker_color())
