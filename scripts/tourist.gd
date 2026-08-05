class_name CameraTourist
extends Node2D

signal photographed

enum CameraState { WANDER, AIM, FLASH, COOLDOWN }

var player: CharacterBody2D
var attractions: PackedVector2Array
var bounds := Rect2(55, 105, 1042, 485)
var walls: Array
var velocity := Vector2.ZERO
var state := CameraState.WANDER
var timer := 0.0
var aim_angle := 0.0
var rng := RandomNumberGenerator.new()
var body_color := Color("#5b6ee1")
var view_radius: float
var fov_degrees: float
var params: Dictionary = {}

func setup(target: CharacterBody2D, attraction_positions: PackedVector2Array, seed_value: int, movement_bounds := Rect2(55, 105, 1042, 485), blocking_walls: Array = [], tourist_params: Dictionary = {}) -> void:
	player = target
	attractions = attraction_positions
	bounds = movement_bounds
	walls = blocking_walls
	params = tourist_params
	view_radius = float(params.view_radius)
	fov_degrees = float(params.fov_degrees)
	rng.seed = seed_value
	body_color = [Color("#5b6ee1"), Color("#e07a5f"), Color("#7f5af0"), Color("#2a9d8f")][seed_value % 4]
	_choose_velocity()
	timer = rng.randf_range(_param("initial_wander_min"), _param("initial_wander_max"))
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	timer -= delta
	match state:
		CameraState.WANDER:
			var next_position := position + velocity * delta
			if _inside_wall(next_position):
				velocity *= -1.0
			else:
				position = next_position
			_bounce_inside_bounds()
			if timer <= 0.0:
				state = CameraState.AIM
				aim_angle = global_position.angle_to_point(_closest_attraction())
				timer = _param("aim_duration")
		CameraState.AIM:
			if timer <= 0.0:
				state = CameraState.FLASH
				timer = _param("flash_duration")
				if _player_is_in_frame():
					photographed.emit()
		CameraState.FLASH:
			if timer <= 0.0:
				state = CameraState.COOLDOWN
				timer = rng.randf_range(_param("cooldown_min"), _param("cooldown_max"))
		CameraState.COOLDOWN:
			if timer <= 0.0:
				state = CameraState.WANDER
				_choose_velocity()
				timer = rng.randf_range(_param("wander_min"), _param("wander_max"))
	queue_redraw()

func _choose_velocity() -> void:
	velocity = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(_param("speed_min"), _param("speed_max"))

func _param(key: String) -> float:
	return float(params[key])

func _closest_attraction() -> Vector2:
	var closest := attractions[0]
	var closest_distance := global_position.distance_squared_to(closest)
	for attraction in attractions:
		var distance := global_position.distance_squared_to(attraction)
		if distance < closest_distance:
			closest = attraction
			closest_distance = distance
	return closest

func _inside_wall(point: Vector2) -> bool:
	for wall in walls:
		if wall.grow(18.0).has_point(point):
			return true
	return false

func _bounce_inside_bounds() -> void:
	if position.x < bounds.position.x or position.x > bounds.end.x:
		velocity.x *= -1.0
	if position.y < bounds.position.y or position.y > bounds.end.y:
		velocity.y *= -1.0
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)

func _player_is_in_frame() -> bool:
	var relative := (player.global_position - global_position).rotated(-aim_angle)
	var half_fov := deg_to_rad(fov_degrees * 0.5)
	var angle_to_player := absf(relative.angle())
	return relative.length() > 18.0 and relative.length() < view_radius and angle_to_player < half_fov and not _view_blocked()

func _view_blocked() -> bool:
	for step in range(1, 12):
		if _inside_wall(global_position.lerp(player.global_position, step / 12.0)):
			return true
	return false

func _draw() -> void:
	if state == CameraState.AIM or state == CameraState.FLASH:
		var color := Color(1.0, 0.82, 0.18, 0.22) if state == CameraState.AIM else Color(1.0, 0.18, 0.12, 0.55)
		var half_fov := deg_to_rad(fov_degrees * 0.5)
		var points := PackedVector2Array([Vector2(18, 0).rotated(aim_angle)])
		var arc_segments := 24
		for index in range(arc_segments + 1):
			var arc_angle := aim_angle - half_fov + (half_fov * 2.0 * index / arc_segments)
			points.append(Vector2.from_angle(arc_angle) * view_radius)
		draw_colored_polygon(points, color)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, color.lightened(0.35), 2.0)
	draw_circle(Vector2.ZERO, 16.0, body_color)
	draw_circle(Vector2(0, -15), 9.0, Color("#f2c6a0"))
	var camera_direction := Vector2.from_angle(aim_angle if state != CameraState.WANDER else velocity.angle())
	draw_line(camera_direction * 7.0, camera_direction * 21.0, Color("#222536"), 7.0)
	if state == CameraState.AIM:
		draw_arc(Vector2.ZERO, 23.0, -PI / 2.0, -PI / 2.0 + TAU * (timer / _param("aim_duration")), 24, Color.WHITE, 3.0)
