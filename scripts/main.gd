extends Node2D

const Tourist := preload("res://scripts/tourist.gd")
const WORLD_SIZE := Vector2(2400, 1800)
const VIEW_SIZE := Vector2(720, 720)
const START := Vector2(150, 900)
const EXIT := Vector2(2250, 900)
const STAIRS := Vector2(1200, 900)
const ATTRACTIONS := [
	{"name": "CODE OF HAMMURABI", "room": "SULLY 227", "floor": 0, "position": Vector2(410, 310), "texture": preload("res://assets/artworks/code_of_hammurabi.jpg")},
	{"name": "THE SEATED SCRIBE", "room": "SULLY 321", "floor": 0, "position": Vector2(410, 1430), "texture": preload("res://assets/artworks/seated_scribe.jpg")},
	{"name": "DYING SLAVE", "room": "DENON 403", "floor": 0, "position": Vector2(1170, 350), "texture": preload("res://assets/artworks/dying_slave.jpg")},
	{"name": "VENUS DE MILO", "room": "SULLY 345", "floor": 0, "position": Vector2(1980, 350), "texture": preload("res://assets/artworks/venus_de_milo.jpg")},
	{"name": "MONA LISA", "room": "DENON 711", "floor": 1, "position": Vector2(410, 310), "texture": preload("res://assets/artworks/mona_lisa.jpg")},
	{"name": "LIBERTY LEADING THE PEOPLE", "room": "DENON 700", "floor": 1, "position": Vector2(410, 1430), "texture": preload("res://assets/artworks/liberty_leading_the_people.jpg")},
	{"name": "WINGED VICTORY", "room": "DENON 703", "floor": 1, "position": Vector2(1170, 1430), "texture": preload("res://assets/artworks/winged_victory.jpg")},
	{"name": "CORONATION OF NAPOLEON", "room": "DENON 702", "floor": 1, "position": Vector2(1980, 350), "texture": preload("res://assets/artworks/coronation_of_napoleon.jpg")},
	{"name": "RAFT OF THE MEDUSA", "room": "DENON 700B", "floor": 1, "position": Vector2(1980, 1430), "texture": preload("res://assets/artworks/raft_of_the_medusa.jpg")},
]
const WALLS := [
	Rect2(50,80,2300,30), Rect2(50,1690,2300,30), Rect2(50,80,30,1640), Rect2(2320,80,30,1640),
	Rect2(690,110,32,390), Rect2(690,660,32,430), Rect2(690,1260,32,430),
	Rect2(1460,110,32,560), Rect2(1460,830,32,380), Rect2(1460,1370,32,320),
	Rect2(722,610,280,30), Rect2(1160,610,300,30), Rect2(80,1190,250,30),
	Rect2(500,1190,190,30), Rect2(1492,1260,300,30), Rect2(1960,1260,360,30),
]

@export var crowd_count := 18
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
var ui_layer: CanvasLayer
var art_label: Label
var floor_label: Label
var current_floor := 0
var stair_cooldown := 0.0
var crowd_nodes: Array[Node] = []

func _ready() -> void:
	visited_attractions.resize(ATTRACTIONS.size())
	visited_attractions.fill(false)
	_build_walls()
	_build_player()
	_build_ui()
	_spawn_crowd()
	queue_redraw()

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = START
	player.z_index = 6
	player.set_script(load("res://scripts/player.gd"))
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

func _build_walls() -> void:
	for rect in WALLS:
		var wall := StaticBody2D.new()
		wall.position = rect.get_center()
		wall.z_index = 5
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		wall.add_child(collision)
		var visual := Polygon2D.new()
		var half: Vector2 = rect.size * 0.5
		visual.polygon = PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)])
		visual.color = Color("#8f8170")
		wall.add_child(visual)
		add_child(wall)

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
	flash_overlay.size = VIEW_SIZE
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)

func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var attraction_positions := PackedVector2Array()
	for attraction in ATTRACTIONS:
		if attraction.floor == current_floor:
			attraction_positions.append(attraction.position)
	var positions: Array[Vector2] = []
	for index in crowd_count:
		var spawn_position := _sample_crowd_position(rng, positions)
		positions.append(spawn_position)
		var tourist := Tourist.new()
		crowd_nodes.append(tourist)
		tourist.position = spawn_position
		tourist.setup(player, attraction_positions, rng.randi(), Rect2(80,110,2240,1580), WALLS)
		tourist.photographed.connect(_on_photographed)
		add_child(tourist)

func _sample_crowd_position(rng: RandomNumberGenerator, existing_positions: Array[Vector2]) -> Vector2:
	var candidate := Vector2(START.x + start_exclusion_radius, START.y)
	var valid_fallback := candidate
	for attempt in 100:
		# Higher bias values shift more of the crowd toward an attraction.
		var progress := 1.0 - pow(rng.randf(), goal_density_bias)
		var floor_attractions := ATTRACTIONS.filter(func(item): return item.floor == current_floor)
		var attraction: Dictionary = floor_attractions[rng.randi_range(0, floor_attractions.size() - 1)]
		candidate = START.lerp(attraction.position, progress)
		candidate += Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(80.0, 330.0)
		candidate.x = clampf(candidate.x, 110.0, WORLD_SIZE.x - 110.0)
		candidate.y = clampf(candidate.y, 140.0, WORLD_SIZE.y - 140.0)
		# Entrance and destination are hard no-spawn zones.
		if candidate.distance_to(START) < start_exclusion_radius:
			continue
		if candidate.distance_to(EXIT) < 135.0 or _inside_wall(candidate):
			continue
		var inside_attraction := false
		for destination in ATTRACTIONS:
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
	for wall in WALLS:
		if wall.grow(20.0).has_point(point):
			return true
	return false

func _process(delta: float) -> void:
	flash_overlay.color.a = move_toward(flash_overlay.color.a, 0.0, delta * 3.8)
	stair_cooldown = maxf(stair_cooldown - delta, 0.0)
	if game_over:
		return
	for index in ATTRACTIONS.size():
		if ATTRACTIONS[index].floor == current_floor and not visited_attractions[index] and player.position.distance_to(ATTRACTIONS[index].position) < 55.0:
			visited_attractions[index] = true
			status_label.text = "%s visited!" % ATTRACTIONS[index].name
			_update_art_text()
			queue_redraw()
	if player.position.distance_to(STAIRS) < 55.0 and stair_cooldown <= 0.0:
		_switch_floor()
	if current_floor == 0 and player.position.distance_to(EXIT) < 60.0:
		game_over = true
		player.set_physics_process(false)
		_show_celebration_page()
		queue_redraw()

func _switch_floor() -> void:
	current_floor = 1 - current_floor
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
	page.size = VIEW_SIZE
	ui_layer.add_child(page)

	var heading := Label.new()
	heading.text = "MUSEUM VISIT COMPLETE"
	heading.position = Vector2(0, 65)
	heading.size = Vector2(VIEW_SIZE.x, 55)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color("#f4d35e"))
	page.add_child(heading)

	var summary := Label.new()
	summary.text = "Art visited: %d / %d\nCaught in photos: %d" % [_visited_count(), ATTRACTIONS.size(), exposures]
	summary.position = Vector2(0, 130)
	summary.size = Vector2(VIEW_SIZE.x, 80)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 24)
	page.add_child(summary)

	var result := Label.new()
	result.position = Vector2(0, 245)
	result.size = Vector2(VIEW_SIZE.x, 70)
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
	restart_hint.size = Vector2(VIEW_SIZE.x, 35)
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_hint.add_theme_font_size_override("font_size", 20)
	page.add_child(restart_hint)

func _update_exposure_text() -> void:
	var remaining := 3 - exposures
	exposure_label.text = "PRIVACY  " + "●".repeat(maxi(remaining, 0)) + "○".repeat(mini(exposures, 3))

func _update_art_text() -> void:
	art_label.text = "ART %d / %d" % [_visited_count(), ATTRACTIONS.size()]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#d8cebc"))
	draw_rect(Rect2(80,110,610,1580), Color("#e9e1d3"))
	draw_rect(Rect2(722,110,738,1580), Color("#ded5c6"))
	draw_rect(Rect2(1492,110,828,1580), Color("#e9e1d3"))
	for x in range(180, 2300, 220):
		draw_line(Vector2(x,110), Vector2(x,1690), Color(0.72,0.67,0.59,0.22), 2.0)
	for y in range(190, 1690, 220):
		draw_line(Vector2(80,y), Vector2(2320,y), Color(0.72,0.67,0.59,0.22), 2.0)
	if current_floor == 0:
		draw_rect(Rect2(80, START.y - 65, 85, 130), Color("#304b63"), true)
		draw_string(ThemeDB.fallback_font, START + Vector2(-40,-80), "PYRAMID ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#222536"))
		draw_rect(Rect2(EXIT - Vector2(45,65), Vector2(90,130)), Color("#2d7654"), true)
		draw_string(ThemeDB.fallback_font, EXIT + Vector2(-20,6), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_circle(STAIRS, 48.0, Color("#667d8d"))
	draw_string(ThemeDB.fallback_font, STAIRS + Vector2(-26,6), "STAIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	for index in ATTRACTIONS.size():
		var attraction: Dictionary = ATTRACTIONS[index]
		if attraction.floor != current_floor:
			continue
		var spot: Vector2 = attraction.position
		var frame_rect := Rect2(spot - Vector2(35, 47), Vector2(70, 94))
		var image_rect := Rect2(spot - Vector2(29, 41), Vector2(58, 82))
		draw_rect(frame_rect, Color("#5b4636"), true)
		draw_texture_rect(attraction.texture, image_rect, false)
		draw_string(ThemeDB.fallback_font, spot + Vector2(-65, -57), "%s • %s" % [attraction.room, attraction.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#222536"))
		if visited_attractions[index]:
			draw_circle(spot, 50.0, Color(0.25, 0.85, 0.5, 0.24))
			draw_string(ThemeDB.fallback_font, spot + Vector2(-8, 7), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#174b32"))
