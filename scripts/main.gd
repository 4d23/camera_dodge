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
var artwork_density_bias: float
var minimum_crowd_spacing: float
var start_exclusion_radius: float
var attraction_exclusion_radius: float
var exit_exclusion_radius: float
var artwork_view_duration: float
var sanity_maximum: float
var sanity_minimum: float
var sanity_photo_loss: float
var sanity_recovery_per_second: float
var sanity_impaired_threshold: float
var sanity_impaired_speed_multiplier: float
var sanity_reverse_controls: bool

var player: CharacterBody2D
var exposures := 0
var sanity: float
var game_over := false
var won := false
var status_label: Label
var sanity_label: Label
var sanity_bar: ProgressBar
var flash_overlay: ColorRect
var visited_attractions: Array[bool] = []
var artwork_view_progress: Array[float] = []
var ui_layer: CanvasLayer
var art_label: Label
var floor_label: Label
var minimap: MuseumMinimap
var has_map := false
var collectible_popup: PanelContainer
var collectible_texture: TextureRect
var collectible_name: Label
var collectible_tween: Tween
var energy_bar: ProgressBar
var energy_value_label: Label
var coin_label: Label
var coin_icon: Label
var shop_prompt: Label
var water_progress_bar: ProgressBar
var water_shop: Node2D
var ice_cream_shop: Node2D
var coins := 0
var shop_purchase_progress := 0.0
var shop_purchase_available := true
var active_shop := ""
var current_floor := 0
var stair_cooldown := 0.0
var crowd_nodes: Array[Node] = []
var tourist_navigation: AStarGrid2D

func _ready() -> void:
	view_size = get_viewport_rect().size
	if not _load_game_params():
		return
	_load_scene_layout()
	_find_water_shop()
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
		"player": ["speed", "acceleration", "deceleration", "controller_deadzone", "invulnerability_duration", "dash_speed", "dash_duration", "dash_cooldown", "energy_maximum", "energy_recovery_per_second", "dash_energy_cost"],
		"sanity": ["maximum", "minimum", "photo_loss", "recovery_per_second", "impaired_threshold", "impaired_speed_multiplier", "reverse_controls"],
		"artwork": ["view_duration"],
		"shop": ["starting_coins", "water_price", "water_energy_restore", "water_purchase_duration", "ice_cream_price", "ice_cream_sanity_restore", "ice_cream_purchase_duration"],
		"crowd": ["tourists_per_100k_pixels", "artwork_density_bias", "minimum_spacing", "start_exclusion_radius", "artwork_exclusion_radius", "exit_exclusion_radius", "type_weights"],
		"tourist": ["view_radius", "fov_degrees", "speed_min", "speed_max", "separation_radius", "separation_strength", "artwork_aim_bias", "aim_jitter_degrees", "aim_retarget_min", "aim_retarget_max", "destination_arrival_radius", "pathfinding_cell_size", "pathfinding_clearance", "travel_photo_min", "travel_photo_max", "aim_duration", "flash_duration", "cooldown_min", "cooldown_max"]
	}
	for section_name: String in required:
		if not game_params.has(section_name) or not game_params[section_name] is Dictionary:
			push_error("game_params.json is missing section: %s" % section_name)
			return false
		for key: String in required[section_name]:
			if not game_params[section_name].has(key):
				push_error("game_params.json is missing: %s.%s" % [section_name, key])
				return false
	if not game_params.has("tourist_types") or not game_params.tourist_types is Dictionary:
		push_error("game_params.json is missing section: tourist_types")
		return false
	for type_name in game_params.crowd.type_weights:
		if not game_params.tourist_types.has(type_name):
			push_error("Missing tourist_types configuration for: %s" % type_name)
			return false
	var artwork: Dictionary = game_params.artwork
	var crowd: Dictionary = game_params.crowd
	sanity_maximum = float(game_params.sanity.maximum)
	sanity_minimum = float(game_params.sanity.minimum)
	sanity_photo_loss = float(game_params.sanity.photo_loss)
	sanity_recovery_per_second = float(game_params.sanity.recovery_per_second)
	sanity_impaired_threshold = float(game_params.sanity.impaired_threshold)
	sanity_impaired_speed_multiplier = float(game_params.sanity.impaired_speed_multiplier)
	sanity_reverse_controls = bool(game_params.sanity.reverse_controls)
	sanity = sanity_maximum
	artwork_view_duration = float(artwork.view_duration)
	artwork_density_bias = float(crowd.artwork_density_bias)
	minimum_crowd_spacing = float(crowd.minimum_spacing)
	start_exclusion_radius = float(crowd.start_exclusion_radius)
	# The entrance must begin outside every camera and child detection range,
	# even if a smaller exclusion is accidentally configured later.
	var longest_initial_range := float(game_params.tourist.view_radius)
	for type_config in game_params.tourist_types.values():
		longest_initial_range = maxf(longest_initial_range, float(type_config.get("view_radius", 0.0)))
		longest_initial_range = maxf(longest_initial_range, float(type_config.get("dash_detection_radius", 0.0)))
	start_exclusion_radius = maxf(start_exclusion_radius, longest_initial_range + 40.0)
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
	player.set_script(load("res://scripts/player.gd"))
	player.configure(game_params.get("player", {}))
	add_child(player)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = player.FOOT_COLLISION_RADIUS
	collision.shape = shape
	player.add_child(collision)
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)

func _find_water_shop() -> void:
	water_shop = $Level0/Walls/WaterShop
	ice_cream_shop = $Level0/Walls/IceCreamShop
	coins = int(game_params.shop.starting_coins)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	var title := Label.new()
	title.text = "CAMERA DODGING • LOUVRE"
	title.position = Vector2(18, 16)
	title.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(title)

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

	minimap = MuseumMinimap.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(view_size.x - 238.0, 20.0)
	minimap.size = Vector2(220.0, 165.0)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.configure(player, _current_level(), current_floor)
	minimap.visible = false
	ui_layer.add_child(minimap)

	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(18, 80)
	energy_bar.size = Vector2(220, 22)
	energy_bar.min_value = 0.0
	energy_bar.max_value = player.maximum_energy
	energy_bar.show_percentage = false
	var energy_background := StyleBoxFlat.new()
	energy_background.bg_color = Color(0.07, 0.09, 0.12, 0.9)
	energy_background.set_corner_radius_all(5)
	energy_bar.add_theme_stylebox_override("background", energy_background)
	var energy_fill := StyleBoxFlat.new()
	energy_fill.bg_color = Color("#47c9a2")
	energy_fill.set_corner_radius_all(5)
	energy_bar.add_theme_stylebox_override("fill", energy_fill)
	ui_layer.add_child(energy_bar)
	energy_value_label = Label.new()
	energy_value_label.position = Vector2(26, 81)
	energy_value_label.add_theme_font_size_override("font_size", 13)
	ui_layer.add_child(energy_value_label)

	sanity_bar = ProgressBar.new()
	sanity_bar.position = Vector2(420, 80)
	sanity_bar.size = Vector2(220, 22)
	sanity_bar.min_value = 0.0
	sanity_bar.max_value = sanity_maximum
	sanity_bar.show_percentage = false
	var sanity_background := StyleBoxFlat.new()
	sanity_background.bg_color = Color(0.07, 0.09, 0.12, 0.9)
	sanity_background.set_corner_radius_all(5)
	sanity_bar.add_theme_stylebox_override("background", sanity_background)
	var sanity_fill := StyleBoxFlat.new()
	sanity_fill.bg_color = Color("#b68cff")
	sanity_fill.set_corner_radius_all(5)
	sanity_bar.add_theme_stylebox_override("fill", sanity_fill)
	ui_layer.add_child(sanity_bar)
	sanity_label = Label.new()
	sanity_label.position = Vector2(428, 81)
	sanity_label.add_theme_font_size_override("font_size", 13)
	ui_layer.add_child(sanity_label)

	coin_icon = Label.new()
	coin_icon.text = "●"
	coin_icon.position = Vector2(250, 80)
	coin_icon.add_theme_font_size_override("font_size", 16)
	coin_icon.add_theme_color_override("font_color", Color("#f4d35e"))
	ui_layer.add_child(coin_icon)
	coin_label = Label.new()
	coin_label.position = Vector2(269, 81)
	coin_label.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(coin_label)
	_update_sanity_ui()
	_update_energy_ui()

	shop_prompt = Label.new()
	shop_prompt.position = Vector2(0, view_size.y - 90.0)
	shop_prompt.size = Vector2(view_size.x, 35)
	shop_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_prompt.add_theme_font_size_override("font_size", 18)
	shop_prompt.add_theme_color_override("font_color", Color("#d9f2f2"))
	shop_prompt.visible = false
	ui_layer.add_child(shop_prompt)
	water_progress_bar = ProgressBar.new()
	water_progress_bar.position = Vector2((view_size.x - 260.0) * 0.5, view_size.y - 52.0)
	water_progress_bar.size = Vector2(260.0, 12.0)
	water_progress_bar.min_value = 0.0
	water_progress_bar.max_value = float(game_params.shop.water_purchase_duration)
	water_progress_bar.show_percentage = false
	var water_progress_background := StyleBoxFlat.new()
	water_progress_background.bg_color = Color(0.05, 0.08, 0.1, 0.9)
	water_progress_background.set_corner_radius_all(4)
	water_progress_bar.add_theme_stylebox_override("background", water_progress_background)
	var water_progress_fill := StyleBoxFlat.new()
	water_progress_fill.bg_color = Color("#64d8ff")
	water_progress_fill.set_corner_radius_all(4)
	water_progress_bar.add_theme_stylebox_override("fill", water_progress_fill)
	water_progress_bar.visible = false
	ui_layer.add_child(water_progress_bar)

	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.size = view_size
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)
	_build_collectible_popup()

func _build_collectible_popup() -> void:
	collectible_popup = PanelContainer.new()
	collectible_popup.name = "CollectiblePopup"
	collectible_popup.position = Vector2((view_size.x - 360.0) * 0.5, 105.0)
	collectible_popup.size = Vector2(360.0, 145.0)
	collectible_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collectible_popup.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.065, 0.08, 0.94)
	panel_style.border_color = Color(1, 1, 1, 0.28)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(9)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 12.0
	collectible_popup.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(collectible_popup)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	collectible_popup.add_child(row)
	collectible_texture = TextureRect.new()
	collectible_texture.custom_minimum_size = Vector2(120.0, 120.0)
	collectible_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	collectible_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	collectible_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(collectible_texture)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text_column)
	var collected_label := Label.new()
	collected_label.text = "COLLECTED"
	collected_label.add_theme_font_size_override("font_size", 12)
	collected_label.add_theme_color_override("font_color", Color("#f4d35e"))
	text_column.add_child(collected_label)
	collectible_name = Label.new()
	collectible_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collectible_name.add_theme_font_size_override("font_size", 19)
	collectible_name.add_theme_color_override("font_color", Color.WHITE)
	text_column.add_child(collectible_name)

func _show_collectible(texture: Texture2D, item_name: String) -> void:
	if collectible_tween != null and collectible_tween.is_valid():
		collectible_tween.kill()
	collectible_texture.texture = texture
	collectible_name.text = item_name
	collectible_popup.modulate.a = 1.0
	collectible_popup.visible = true
	collectible_tween = create_tween()
	collectible_tween.tween_interval(2.4)
	collectible_tween.tween_property(collectible_popup, "modulate:a", 0.0, 0.35)
	collectible_tween.tween_callback(func(): collectible_popup.visible = false)

func _spawn_crowd() -> void:
	crowd_count = _crowd_count_for_current_floor()
	tourist_navigation = _build_tourist_navigation()
	var rng := RandomNumberGenerator.new()
	var configured_seed := int(game_params.crowd.get("seed", -1))
	if configured_seed >= 0:
		# Offset by floor so each floor is reproducible but visually distinct.
		rng.seed = configured_seed + current_floor
	else:
		rng.randomize()
	var attraction_positions := PackedVector2Array()
	for attraction in attractions:
		if attraction.floor == current_floor:
			attraction_positions.append(attraction.position)
	var positions: Array[Vector2] = []
	var elderly_members_left := 0
	var elderly_member_index := 0
	var elderly_group_anchor := Vector2.ZERO
	var elderly_group_direction := Vector2.LEFT
	var elderly_group_seed := 0
	var elderly_guide: CameraTourist
	var elderly_previous_member: CameraTourist
	var regulars_spawned := 0
	var minimum_regulars := int(game_params.crowd.get("minimum_regular_photographers", 0))
	for index in crowd_count:
		var elderly_params: Dictionary = game_params.tourist_types.elderly
		var elderly_minimum_size := int(elderly_params.get("group_size_min", elderly_params.group_size))
		var remaining_slots := crowd_count - index
		var regulars_needed := maxi(minimum_regulars - regulars_spawned, 0)
		var has_room_for_full_group := remaining_slots - elderly_minimum_size >= regulars_needed
		var must_spawn_regular := elderly_members_left <= 0 and remaining_slots <= regulars_needed
		var tourist_type := "elderly" if elderly_members_left > 0 else ("regular" if must_spawn_regular else _pick_tourist_type(rng, has_room_for_full_group))
		var spawn_position: Vector2
		var tourist_seed := rng.randi()
		if tourist_type == "elderly":
			if elderly_members_left <= 0:
				var available_group_slots := remaining_slots - regulars_needed
				elderly_members_left = _sample_elderly_group_size(rng, elderly_params, available_group_slots)
				elderly_member_index = 0
				var group_layout := _sample_elderly_group_layout(rng, positions, elderly_members_left, 36.0)
				elderly_group_anchor = group_layout.anchor
				elderly_group_direction = group_layout.direction
				elderly_group_seed = rng.randi()
			spawn_position = elderly_group_anchor + elderly_group_direction * 36.0 * elderly_member_index
			tourist_seed = elderly_group_seed
			elderly_member_index += 1
			elderly_members_left -= 1
		else:
			spawn_position = _sample_crowd_position(rng, positions)
		if tourist_type == "regular":
			regulars_spawned += 1
		positions.append(spawn_position)
		var tourist := Tourist.new()
		crowd_nodes.append(tourist)
		tourist.position = spawn_position
		var is_tour_guide := tourist_type == "elderly" and elderly_member_index == 1
		var spawn_config := {
			"player": player,
			"attractions": attraction_positions,
			"seed": tourist_seed,
			"bounds": Rect2(80, 110, 2240, 1580),
			"walls": _current_level().wall_rects(),
			"params": game_params.tourist,
			"archetype": tourist_type,
			"type_params": game_params.tourist_types[tourist_type],
			"is_tour_guide": is_tour_guide,
			"group_guide": elderly_guide,
			"previous_group_member": elderly_previous_member,
			"crowd": crowd_nodes,
			"navigation": tourist_navigation
		}
		tourist.setup(spawn_config)
		if is_tour_guide:
			elderly_guide = tourist
			elderly_previous_member = tourist
		elif tourist_type == "elderly":
			elderly_previous_member = tourist
		tourist.photographed.connect(_on_photographed)
		add_child(tourist)

func _crowd_count_for_current_floor() -> int:
	var movement_area := Rect2(80, 110, 2240, 1580)
	var usable_area := movement_area.size.x * movement_area.size.y
	for wall: Rect2 in _current_level().wall_rects():
		var covered_area := movement_area.intersection(wall)
		usable_area -= covered_area.size.x * covered_area.size.y
	var density := float(game_params.crowd.tourists_per_100k_pixels)
	return maxi(roundi(maxf(usable_area, 0.0) / 100000.0 * density), 0)

func _build_tourist_navigation() -> AStarGrid2D:
	var movement_area := Rect2(80, 110, 2240, 1580)
	var cell_size := float(game_params.tourist.pathfinding_cell_size)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, ceili(movement_area.size.x / cell_size), ceili(movement_area.size.y / cell_size))
	grid.cell_size = Vector2(cell_size, cell_size)
	grid.offset = movement_area.position + Vector2.ONE * cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var clearance := float(game_params.tourist.pathfinding_clearance)
	var walls := _current_level().wall_rects()
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			var cell := Vector2i(x, y)
			var point := grid.get_point_position(cell)
			for wall: Rect2 in walls:
				if wall.grow(clearance).has_point(point):
					grid.set_point_solid(cell)
					break
	return grid

func _sample_elderly_group_size(rng: RandomNumberGenerator, elderly_params: Dictionary, available_slots: int) -> int:
	var mean := float(elderly_params.group_size)
	var standard_deviation := float(elderly_params.get("group_size_stddev", 0.0))
	var minimum_size := int(elderly_params.get("group_size_min", maxi(roundi(mean), 1)))
	var maximum_size := mini(int(elderly_params.get("group_size_max", roundi(mean))), available_slots)
	if maximum_size <= minimum_size:
		return maxi(minimum_size, mini(maximum_size, available_slots))
	# Box-Muller transform converts two uniform samples into a normal sample.
	var uniform_a := maxf(rng.randf(), 0.000001)
	var uniform_b := rng.randf()
	var normal_sample := sqrt(-2.0 * log(uniform_a)) * cos(TAU * uniform_b)
	return clampi(roundi(mean + normal_sample * standard_deviation), minimum_size, maximum_size)

func _sample_elderly_group_layout(rng: RandomNumberGenerator, existing_positions: Array[Vector2], group_size: int, spacing: float) -> Dictionary:
	for attempt in 80:
		var anchor := _sample_crowd_position(rng, existing_positions)
		var base_angle := rng.randf_range(0.0, TAU)
		# Try several orientations at the same anchor before sampling a new one.
		for direction_index in 8:
			var direction := Vector2.from_angle(base_angle + direction_index * TAU / 8.0)
			if _elderly_line_fits(anchor, direction, group_size, spacing, existing_positions):
				return {"anchor": anchor, "direction": direction}
	# The map has ample open space, so this should only be reached with invalid
	# level geometry. Keep the fallback together instead of flipping individuals.
	return {"anchor": _sample_crowd_position(rng, existing_positions), "direction": Vector2.LEFT}

func _elderly_line_fits(anchor: Vector2, direction: Vector2, group_size: int, spacing: float, existing_positions: Array[Vector2]) -> bool:
	# Check the continuous line as well as member centers so a thin wall cannot
	# slip through a gap between two tourists.
	var line_length := spacing * maxi(group_size - 1, 0)
	var sample_count := maxi(ceili(line_length / 10.0), 1)
	for sample_index in sample_count + 1:
		if _inside_wall(anchor + direction * line_length * sample_index / sample_count):
			return false
	for member_index in group_size:
		var point := anchor + direction * spacing * member_index
		if point.x < 110.0 or point.x > WORLD_SIZE.x - 110.0 or point.y < 140.0 or point.y > WORLD_SIZE.y - 140.0:
			return false
		if _inside_wall(point):
			return false
		if point.distance_to(start_position) < start_exclusion_radius or point.distance_to(exit_position) < exit_exclusion_radius:
			return false
		for destination in attractions:
			if destination.floor == current_floor and point.distance_to(destination.position) < attraction_exclusion_radius:
				return false
		for other_position in existing_positions:
			if point.distance_to(other_position) < minimum_crowd_spacing:
				return false
	return true

func _pick_tourist_type(rng: RandomNumberGenerator, allow_elderly := true) -> String:
	var weights: Dictionary = game_params.crowd.type_weights
	var total := 0.0
	for type_name: String in weights:
		if type_name != "elderly" or allow_elderly:
			total += float(weights[type_name])
	var roll := rng.randf() * total
	for type_name: String in weights:
		if type_name == "elderly" and not allow_elderly:
			continue
		roll -= float(weights[type_name])
		if roll <= 0.0:
			return type_name
	return "regular"

func _sample_crowd_position(rng: RandomNumberGenerator, existing_positions: Array[Vector2]) -> Vector2:
	var candidate := Vector2(start_position.x + start_exclusion_radius, start_position.y)
	var valid_fallback := candidate
	for attempt in 100:
		# Higher bias values shift more of the crowd toward an attraction.
		var progress := 1.0 - pow(rng.randf(), artwork_density_bias)
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
	if not game_over:
		sanity = minf(sanity + sanity_recovery_per_second * delta, sanity_maximum)
	_update_sanity_ui()
	_update_energy_ui()
	if game_over:
		return
	_check_map_pickup()
	_update_water_shop(delta)
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
				_show_collectible(artwork_node.artwork_texture, attractions[index].name)
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

func _update_energy_ui() -> void:
	if player == null or energy_bar == null:
		return
	energy_bar.value = player.energy
	energy_value_label.text = "ENERGY  %d / %d" % [roundi(player.energy), roundi(player.maximum_energy)]
	coin_label.text = "COINS  %d" % coins

func _update_water_shop(delta: float) -> void:
	var shop_kind := ""
	if current_floor == 0 and water_shop.player_is_next_to(player.global_position):
		shop_kind = "water"
	elif current_floor == 0 and ice_cream_shop.player_is_next_to(player.global_position):
		shop_kind = "ice_cream"
	shop_prompt.visible = shop_kind != ""
	water_progress_bar.visible = shop_kind != ""
	if shop_kind == "":
		shop_purchase_progress = 0.0
		water_progress_bar.value = 0.0
		shop_purchase_available = true
		active_shop = ""
		return
	if active_shop != shop_kind:
		active_shop = shop_kind
		shop_purchase_progress = 0.0
		shop_purchase_available = true
	var is_water := shop_kind == "water"
	var item_name := "Water" if is_water else "Ice cream"
	var price := int(game_params.shop.water_price if is_water else game_params.shop.ice_cream_price)
	var duration := float(game_params.shop.water_purchase_duration if is_water else game_params.shop.ice_cream_purchase_duration)
	water_progress_bar.max_value = duration
	if not shop_purchase_available:
		water_progress_bar.value = water_progress_bar.max_value
		shop_prompt.text = "%s collected — step away to buy again" % item_name
		return
	if coins < price:
		shop_purchase_progress = 0.0
		water_progress_bar.value = 0.0
		shop_prompt.text = "Not enough coins"
		return
	shop_purchase_progress += delta
	water_progress_bar.value = shop_purchase_progress
	var remaining := maxf(duration - shop_purchase_progress, 0.0)
	shop_prompt.text = "Getting %s… %.1fs  •  %d coin%s" % [item_name.to_lower(), remaining, price, "" if price == 1 else "s"]
	if shop_purchase_progress >= duration:
		coins -= price
		if is_water:
			player.restore_energy(float(game_params.shop.water_energy_restore))
			status_label.text = "Water purchased — energy restored!"
		else:
			sanity = minf(sanity + float(game_params.shop.ice_cream_sanity_restore), sanity_maximum)
			_update_sanity_ui()
			status_label.text = "Ice cream purchased — sanity restored!"
		shop_purchase_progress = 0.0
		shop_purchase_available = false
		shop_prompt.text = "%s collected!" % item_name
		_update_energy_ui()

func _check_map_pickup() -> void:
	if has_map:
		return
	for wall in _current_level().get_node("Walls").get_children():
		if wall.structure_type == "registration_desk" and wall.world_rect().grow(55.0).has_point(player.global_position):
			has_map = true
			minimap.visible = true
			_show_collectible(load("res://assets/scene_reference/museum-trifold-brochure-template-design.png") as Texture2D, "INFORMATION BROCHURE")
			status_label.text = "Museum map collected!"
			return

func _switch_floor() -> void:
	_current_level().set_active(false)
	current_floor = 1 - current_floor
	_current_level().set_active(true)
	stairs_position = _current_level().get_node("Markers/Stairs").global_position
	stair_cooldown = 1.5
	player.position += Vector2(0, 75)
	floor_label.text = "LEVEL %d" % current_floor
	minimap.set_level(_current_level(), current_floor)
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
	sanity = maxf(sanity - sanity_photo_loss, sanity_minimum)
	player.hit()
	flash_overlay.color = Color(1, 0.25, 0.2, 0.35)
	_update_sanity_ui()

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
	summary.text = "Art visited: %d / %d\nCamera exposures: %d" % [_visited_count(), attractions.size(), exposures]
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

func _update_sanity_ui() -> void:
	if sanity_label == null or player == null:
		return
	var impaired := sanity < sanity_impaired_threshold
	player.set_sanity_effect(impaired, sanity_impaired_speed_multiplier, sanity_reverse_controls)
	sanity_bar.value = maxf(sanity, 0.0)
	sanity_label.text = "SANITY  %d" % roundi(sanity)
	sanity_label.add_theme_color_override("font_color", Color("#ff6b6b") if impaired else Color.WHITE)

func _update_art_text() -> void:
	art_label.text = "ART %d / %d" % [_visited_count(), attractions.size()]

func _draw() -> void:
	pass
