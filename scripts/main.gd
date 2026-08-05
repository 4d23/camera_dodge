extends Node2D

const Tourist := preload("res://scripts/tourist.gd")
const WORLD_SIZE := Vector2(2400, 1800)
var view_size: Vector2
var start_position := Vector2.ZERO
var exit_position := Vector2.ZERO
var stairs_position := Vector2.ZERO
var attractions: Array[Dictionary] = []
var game_params: Dictionary = {}

var crowd_count: int
var goal_density_bias: float
var minimum_crowd_spacing: float
var start_exclusion_radius: float
var attraction_exclusion_radius: float
var exit_exclusion_radius: float
var artwork_view_duration: float

var player: CharacterBody2D
var exposures := 0
var game_over := false
var won := false
var status_label: Label
var exposure_label: Label
var flash_overlay: ColorRect
var visited_attractions: Array[bool] = []
var artwork_view_progress: Array[float] = []
var ui_layer: CanvasLayer
var art_label: Label
var floor_label: Label
var current_floor := 0
var stair_cooldown := 0.0
var crowd_nodes: Array[Node] = []

func _ready() -> void:
	view_size = get_viewport_rect().size
	if not _load_game_params():
		return
	_load_scene_layout()
	visited_attractions.resize(attractions.size())
	visited_attractions.fill(false)
	artwork_view_progress.resize(attractions.size())
	artwork_view_progress.fill(0.0)
	_build_player()
	_build_ui()
	_spawn_crowd()
	queue_redraw()

func _load_game_params() -> bool:
	var file := FileAccess.open("res://config/game_params.json", FileAccess.READ)
	if file == null:
		push_error("Unable to open res://config/game_params.json")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("game_params.json must contain a JSON object")
		return false
	game_params = parsed
	var required := {
		"player": ["speed", "acceleration", "deceleration", "controller_deadzone", "invulnerability_duration", "dash_speed", "dash_duration", "dash_cooldown"],
		"artwork": ["view_duration"],
		"crowd": ["count", "goal_density_bias", "minimum_spacing", "start_exclusion_radius", "artwork_exclusion_radius", "exit_exclusion_radius"],
		"tourist": ["view_radius", "fov_degrees", "speed_min", "speed_max", "initial_wander_min", "initial_wander_max", "aim_duration", "flash_duration", "cooldown_min", "cooldown_max", "wander_min", "wander_max"]
	}
	for section_name: String in required:
		if not game_params.has(section_name) or not game_params[section_name] is Dictionary:
			push_error("game_params.json is missing section: %s" % section_name)
			return false
		for key: String in required[section_name]:
			if not game_params[section_name].has(key):
				push_error("game_params.json is missing: %s.%s" % [section_name, key])
				return false
	var artwork: Dictionary = game_params.artwork
	var crowd: Dictionary = game_params.crowd
	artwork_view_duration = float(artwork.view_duration)
	crowd_count = int(crowd.count)
	goal_density_bias = float(crowd.goal_density_bias)
	minimum_crowd_spacing = float(crowd.minimum_spacing)
	start_exclusion_radius = float(crowd.start_exclusion_radius)
	attraction_exclusion_radius = float(crowd.artwork_exclusion_radius)
	exit_exclusion_radius = float(crowd.exit_exclusion_radius)
	return true

func _load_scene_layout() -> void:
	start_position = $Level0/Markers/Entrance.global_position
	exit_position = $Level0/Markers/Exit.global_position
	stairs_position = $Level0/Markers/Stairs.global_position
	for floor_index in 2:
		var level: MuseumLevel = get_node("Level%d" % floor_index)
		for artwork: MuseumArtwork in level.artwork_nodes():
			attractions.append({"name": artwork.artwork_name, "room": artwork.room_name, "floor": floor_index, "position": artwork.global_position, "node": artwork})
	$Level0.set_active(true)
	$Level1.set_active(false)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = start_position
	player.z_index = 6
	player.set_script(load("res://scripts/player.gd"))
	player.configure(game_params.get("player", {}))
	add_child(player)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0
	collision.shape = shape
	player.add_child(collision)
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	var title := Label.new()
	title.text = "CAMERA DODGING • LOUVRE"
	title.position = Vector2(18, 16)
	title.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(title)

	exposure_label = Label.new()
	exposure_label.position = Vector2(500, 18)
	exposure_label.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(exposure_label)
	_update_exposure_text()

	status_label = Label.new()
	status_label.text = "Explore, visit art, then find the EXIT"
	status_label.position = Vector2(230, 52)
	status_label.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(status_label)
	art_label = Label.new()
	art_label.position = Vector2(18, 50)
	art_label.add_theme_font_size_override("font_size", 15)
	ui_layer.add_child(art_label)
	_update_art_text()
	floor_label = Label.new()
	floor_label.text = "LEVEL 0"
	floor_label.position = Vector2(620, 50)
	floor_label.add_theme_font_size_override("font_size", 15)
	ui_layer.add_child(floor_label)

	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.size = view_size
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)

func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var attraction_positions := PackedVector2Array()
	for attraction in attractions:
		if attraction.floor == current_floor:
			attraction_positions.append(attraction.position)
	var positions: Array[Vector2] = []
	for index in crowd_count:
		var spawn_position := _sample_crowd_position(rng, positions)
		positions.append(spawn_position)
		var tourist := Tourist.new()
		crowd_nodes.append(tourist)
		tourist.position = spawn_position
		tourist.setup(player, attraction_positions, rng.randi(), Rect2(80,110,2240,1580), _current_level().wall_rects(), game_params.get("tourist", {}))
		tourist.photographed.connect(_on_photographed)
		add_child(tourist)

func _sample_crowd_position(rng: RandomNumberGenerator, existing_positions: Array[Vector2]) -> Vector2:
	var candidate := Vector2(start_position.x + start_exclusion_radius, start_position.y)
	var valid_fallback := candidate
	for attempt in 100:
		# Higher bias values shift more of the crowd toward an attraction.
		var progress := 1.0 - pow(rng.randf(), goal_density_bias)
		var floor_attractions := attractions.filter(func(item): return item.floor == current_floor)
		var attraction: Dictionary = floor_attractions[rng.randi_range(0, floor_attractions.size() - 1)]
		candidate = start_position.lerp(attraction.position, progress)
		candidate += Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(80.0, 330.0)
		candidate.x = clampf(candidate.x, 110.0, WORLD_SIZE.x - 110.0)
		candidate.y = clampf(candidate.y, 140.0, WORLD_SIZE.y - 140.0)
		# Entrance and destination are hard no-spawn zones.
		if candidate.distance_to(start_position) < start_exclusion_radius:
			continue
		if candidate.distance_to(exit_position) < exit_exclusion_radius or _inside_wall(candidate):
			continue
		var inside_attraction := false
		for destination in attractions:
			if destination.floor != current_floor:
				continue
			if candidate.distance_to(destination.position) < attraction_exclusion_radius:
				inside_attraction = true
				break
		if inside_attraction:
			continue
		valid_fallback = candidate
		var has_enough_space := true
		for other_position in existing_positions:
			if candidate.distance_to(other_position) < minimum_crowd_spacing:
				has_enough_space = false
				break
		if has_enough_space:
			return candidate
	return valid_fallback

func _inside_wall(point: Vector2) -> bool:
	for wall in _current_level().wall_rects():
		if wall.grow(20.0).has_point(point):
			return true
	return false

func _process(delta: float) -> void:
	flash_overlay.color.a = move_toward(flash_overlay.color.a, 0.0, delta * 3.8)
	stair_cooldown = maxf(stair_cooldown - delta, 0.0)
	if game_over:
		return
	for index in attractions.size():
		if visited_attractions[index]:
			continue
		var artwork_node: MuseumArtwork = attractions[index].node
		var is_viewing: bool = attractions[index].floor == current_floor and artwork_node.contains_world_point(player.global_position)
		if is_viewing:
			artwork_view_progress[index] += delta
			var remaining := maxf(artwork_view_duration - artwork_view_progress[index], 0.0)
			artwork_node.set_view_progress(artwork_view_progress[index] / artwork_view_duration, remaining)
			status_label.text = "Viewing %s… %.1fs" % [attractions[index].name, remaining]
			if artwork_view_progress[index] >= artwork_view_duration:
				visited_attractions[index] = true
				artwork_node.set_view_progress(0.0, 0.0)
				artwork_node.set_visited(true)
				status_label.text = "%s visited!" % attractions[index].name
				_update_art_text()
				queue_redraw()
		else:
			artwork_view_progress[index] = 0.0
			artwork_node.set_view_progress(0.0, 0.0)
	if player.position.distance_to(stairs_position) < 55.0 and stair_cooldown <= 0.0:
		_switch_floor()
	if current_floor == 0 and player.position.distance_to(exit_position) < 60.0:
		game_over = true
		player.set_physics_process(false)
		_show_celebration_page()
		queue_redraw()

func _switch_floor() -> void:
	_current_level().set_active(false)
	current_floor = 1 - current_floor
	_current_level().set_active(true)
	stairs_position = _current_level().get_node("Markers/Stairs").global_position
	stair_cooldown = 1.5
	player.position += Vector2(0, 75)
	floor_label.text = "LEVEL %d" % current_floor
	status_label.text = "Entered Level %d" % current_floor
	for tourist in crowd_nodes:
		if is_instance_valid(tourist):
			tourist.queue_free()
	crowd_nodes.clear()
	_spawn_crowd()
	queue_redraw()

func _current_level() -> MuseumLevel:
	return get_node("Level%d" % current_floor) as MuseumLevel

func _visited_count() -> int:
	var count := 0
	for visited in visited_attractions:
		if visited:
			count += 1
	return count

func _unhandled_key_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _on_photographed() -> void:
	if game_over or player.invulnerable:
		return
	exposures += 1
	player.hit()
	flash_overlay.color = Color(1, 0.25, 0.2, 0.35)
	_update_exposure_text()
	if exposures >= 3:
		game_over = true
		player.set_physics_process(false)
		status_label.text = "CAUGHT IN TOO MANY PHOTOS!  Press R to try again"
		status_label.position.x = 350

func _show_celebration_page() -> void:
	var page := ColorRect.new()
	page.color = Color("#171923")
	page.size = view_size
	ui_layer.add_child(page)

	var heading := Label.new()
	heading.text = "MUSEUM VISIT COMPLETE"
	heading.position = Vector2(0, 65)
	heading.size = Vector2(view_size.x, 55)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color("#f4d35e"))
	page.add_child(heading)

	var summary := Label.new()
	summary.text = "Art visited: %d / %d\nCaught in photos: %d" % [_visited_count(), attractions.size(), exposures]
	summary.position = Vector2(0, 130)
	summary.size = Vector2(view_size.x, 80)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 24)
	page.add_child(summary)

	var result := Label.new()
	result.position = Vector2(0, 245)
	result.size = Vector2(view_size.x, 70)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 28)
	if exposures == 0:
		result.text = "PERFECT RUN — YOU STAYED OUT OF EVERY FRAME!"
		result.add_theme_color_override("font_color", Color("#70e0a1"))
	else:
		result.text = "You made it, but the cameras caught you %d time%s." % [exposures, "" if exposures == 1 else "s"]
	page.add_child(result)

	var restart_hint := Label.new()
	restart_hint.text = "Press R to travel again"
	restart_hint.position = Vector2(0, 525)
	restart_hint.size = Vector2(view_size.x, 35)
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_hint.add_theme_font_size_override("font_size", 20)
	page.add_child(restart_hint)

func _update_exposure_text() -> void:
	var remaining := 3 - exposures
	exposure_label.text = "PRIVACY  " + "●".repeat(maxi(remaining, 0)) + "○".repeat(mini(exposures, 3))

func _update_art_text() -> void:
	art_label.text = "ART %d / %d" % [_visited_count(), attractions.size()]

func _draw() -> void:
	pass
