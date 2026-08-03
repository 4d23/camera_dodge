extends Node2D

const Tourist := preload("res://scripts/tourist.gd")
const WORLD_SIZE := Vector2(1152, 648)
const START := Vector2(92, 325)
const ATTRACTIONS := [
	{"name": "VENUS DE MILO", "position": Vector2(520, 205), "color": Color("#b7c9d3")},
	{"name": "WINGED VICTORY", "position": Vector2(760, 470), "color": Color("#c7b7d3")},
	{"name": "MONA LISA", "position": Vector2(1055, 310), "color": Color("#d8b566")},
]

@export var crowd_count := 12
@export_range(1.0, 5.0, 0.1) var goal_density_bias := 2.0
@export var minimum_crowd_spacing := 55.0
@export var start_exclusion_radius := 125.0
@export var attraction_exclusion_radius := 90.0

var player: CharacterBody2D
var exposures := 0
var game_over := false
var won := false
var status_label: Label
var exposure_label: Label
var flash_overlay: ColorRect
var visited_attractions: Array[bool] = []

func _ready() -> void:
	visited_attractions.resize(ATTRACTIONS.size())
	visited_attractions.fill(false)
	_build_player()
	_build_ui()
	_spawn_crowd()
	queue_redraw()

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = START
	player.set_script(load("res://scripts/player.gd"))
	add_child(player)

func _build_ui() -> void:
	var title := Label.new()
	title.text = "OUT OF FRAME  •  LOUVRE RUN"
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	exposure_label = Label.new()
	exposure_label.position = Vector2(860, 24)
	exposure_label.add_theme_font_size_override("font_size", 20)
	add_child(exposure_label)
	_update_exposure_text()

	status_label = Label.new()
	status_label.text = "Visit all 3 attractions • Avoid camera frames • WASD / ARROWS to move"
	status_label.position = Vector2(275, 604)
	status_label.add_theme_font_size_override("font_size", 17)
	add_child(status_label)

	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.size = WORLD_SIZE
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.z_index = 50
	add_child(flash_overlay)

func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var attraction_positions := PackedVector2Array()
	for attraction in ATTRACTIONS:
		attraction_positions.append(attraction.position)
	var positions: Array[Vector2] = []
	for index in crowd_count:
		var spawn_position := _sample_crowd_position(rng, positions)
		positions.append(spawn_position)
		var tourist := Tourist.new()
		tourist.position = spawn_position
		tourist.setup(player, attraction_positions, rng.randi())
		tourist.photographed.connect(_on_photographed)
		add_child(tourist)

func _sample_crowd_position(rng: RandomNumberGenerator, existing_positions: Array[Vector2]) -> Vector2:
	var candidate := Vector2(START.x + start_exclusion_radius, START.y)
	var valid_fallback := candidate
	for attempt in 60:
		# Higher bias values shift more of the crowd toward an attraction.
		var progress := 1.0 - pow(rng.randf(), goal_density_bias)
		var attraction: Dictionary = ATTRACTIONS[rng.randi_range(0, ATTRACTIONS.size() - 1)]
		candidate = START.lerp(attraction.position, progress)
		candidate += Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(25.0, 150.0)
		candidate.x = clampf(candidate.x, 130.0, 1080.0)
		candidate.y = clampf(candidate.y, 125.0, 570.0)
		# Entrance and destination are hard no-spawn zones.
		if candidate.distance_to(START) < start_exclusion_radius:
			continue
		var inside_attraction := false
		for destination in ATTRACTIONS:
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

func _process(delta: float) -> void:
	flash_overlay.color.a = move_toward(flash_overlay.color.a, 0.0, delta * 3.8)
	if game_over:
		return
	for index in ATTRACTIONS.size():
		if not visited_attractions[index] and player.position.distance_to(ATTRACTIONS[index].position) < 42.0:
			visited_attractions[index] = true
			status_label.text = "%s visited!  %d / %d attractions complete" % [ATTRACTIONS[index].name, _visited_count(), ATTRACTIONS.size()]
			queue_redraw()
	if _visited_count() == ATTRACTIONS.size():
		won = true
		game_over = true
		player.set_physics_process(false)
		_show_celebration_page()
		queue_redraw()

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
	page.size = WORLD_SIZE
	page.z_index = 100
	add_child(page)

	var heading := Label.new()
	heading.text = "DESTINATION REACHED!"
	heading.position = Vector2(0, 65)
	heading.size = Vector2(WORLD_SIZE.x, 55)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color("#f4d35e"))
	page.add_child(heading)

	var summary := Label.new()
	summary.text = "You appeared in %d photo%s." % [exposures, "" if exposures == 1 else "s"]
	summary.position = Vector2(0, 130)
	summary.size = Vector2(WORLD_SIZE.x, 40)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 24)
	page.add_child(summary)

	var result := Label.new()
	result.position = Vector2(0, 245)
	result.size = Vector2(WORLD_SIZE.x, 70)
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
	restart_hint.size = Vector2(WORLD_SIZE.x, 35)
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_hint.add_theme_font_size_override("font_size", 20)
	page.add_child(restart_hint)

func _update_exposure_text() -> void:
	var remaining := 3 - exposures
	exposure_label.text = "PRIVACY  " + "●".repeat(maxi(remaining, 0)) + "○".repeat(mini(exposures, 3))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#171923"))
	draw_rect(Rect2(35, 86, 1082, 520), Color("#e8dfcf"), true)
	for x in range(125, 1040, 145):
		draw_rect(Rect2(x, 105, 8, 480), Color("#c9bdac"), true)
	for y in [145, 505]:
		draw_line(Vector2(45, y), Vector2(1107, y), Color("#d5c9b7"), 3.0)
	draw_rect(Rect2(45, 265, 70, 120), Color("#304b63"), true)
	draw_string(ThemeDB.fallback_font, Vector2(49, 255), "ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for index in ATTRACTIONS.size():
		var attraction: Dictionary = ATTRACTIONS[index]
		var spot: Vector2 = attraction.position
		draw_rect(Rect2(spot - Vector2(30, 40), Vector2(60, 80)), Color("#5b4636"), true)
		draw_rect(Rect2(spot - Vector2(22, 32), Vector2(44, 64)), attraction.color, true)
		draw_string(ThemeDB.fallback_font, spot + Vector2(-58, -50), attraction.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#222536"))
		if visited_attractions[index]:
			draw_circle(spot, 50.0, Color(0.25, 0.85, 0.5, 0.24))
			draw_string(ThemeDB.fallback_font, spot + Vector2(-8, 7), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#174b32"))
