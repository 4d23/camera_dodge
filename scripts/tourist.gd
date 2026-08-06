class_name CameraTourist
extends Node2D

signal photographed

enum CameraState { WANDER, AIM, FLASH, COOLDOWN }

var player: CharacterBody2D
var attractions: PackedVector2Array
var bounds := Rect2(55, 105, 1042, 485)
var walls: Array
var velocity := Vector2.ZERO
var desired_velocity := Vector2.ZERO
var avoidance_timer := 0.0
var state := CameraState.WANDER
var timer := 0.0
var aim_angle := 0.0
var rng := RandomNumberGenerator.new()
var body_color := Color("#5b6ee1")
var view_radius: float
var fov_degrees: float
var params: Dictionary = {}
var type_params: Dictionary = {}
var tourist_type := "regular"
var collision_cooldown := 0.0
var video_hit_timer := 0.0
var is_tour_guide := false
var group_guide: Node2D
var formation_offset := Vector2.ZERO
var follow_wobble := Vector2.ZERO
var group_slot := 0
var group_size := 1
var previous_group_member: Node2D
var line_barrier: StaticBody2D
var line_barrier_shape: RectangleShape2D

func setup(target: CharacterBody2D, attraction_positions: PackedVector2Array, seed_value: int, movement_bounds := Rect2(55, 105, 1042, 485), blocking_walls: Array = [], tourist_params: Dictionary = {}, archetype := "regular", archetype_params: Dictionary = {}, guide := false, guide_node: Node2D = null, group_offset := Vector2.ZERO, slot := 0, member_count := 1, previous_member: Node2D = null) -> void:
	player = target
	attractions = attraction_positions
	bounds = movement_bounds
	walls = blocking_walls
	params = tourist_params
	tourist_type = archetype
	type_params = archetype_params
	is_tour_guide = guide
	group_guide = guide_node
	formation_offset = group_offset
	group_slot = slot
	group_size = member_count
	previous_group_member = previous_member
	view_radius = _param("view_radius")
	fov_degrees = _param("fov_degrees")
	rng.seed = seed_value
	if tourist_type == "elderly" and not is_tour_guide:
		# Each follower keeps an imperfect place in the group instead of
		# marching in an exact formation.
		follow_wobble = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(2.0, 7.0)
		_build_line_barrier()
	body_color = {"regular": Color("#5b6ee1"), "kid": Color("#ff8c42"), "influencer": Color("#ed5db1"), "elderly": Color("#758c72")}.get(tourist_type, Color("#5b6ee1"))
	_choose_velocity()
	if bool(type_params.get("takes_video", false)):
		state = CameraState.AIM
		aim_angle = global_position.angle_to_point(_closest_attraction())
		video_hit_timer = 0.0
	else:
		timer = rng.randf_range(_param("initial_wander_min"), _param("initial_wander_max"))
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	collision_cooldown = maxf(collision_cooldown - delta, 0.0)
	avoidance_timer = maxf(avoidance_timer - delta, 0.0)
	if tourist_type == "kid":
		_check_kid_collision()
	timer -= delta
	match state:
		CameraState.WANDER:
			if tourist_type == "elderly" and not is_tour_guide and is_instance_valid(group_guide):
				_follow_guide(delta)
			else:
				_move_with_current_velocity(delta)
			if timer <= 0.0 and bool(type_params.get("takes_photos", true)):
				state = CameraState.AIM
				aim_angle = global_position.angle_to_point(_closest_attraction())
				timer = _param("aim_duration")
		CameraState.AIM:
			if bool(type_params.get("takes_video", false)):
				_move_with_current_velocity(delta)
				aim_angle = global_position.angle_to_point(_closest_attraction())
				video_hit_timer = maxf(video_hit_timer - delta, 0.0)
				if video_hit_timer <= 0.0 and _player_is_in_frame():
					photographed.emit()
					video_hit_timer = float(type_params.video_hit_interval)
			if timer <= 0.0 and not bool(type_params.get("takes_video", false)):
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
	if line_barrier != null:
		_update_line_barrier()
	queue_redraw()

func _choose_velocity() -> void:
	var multiplier := float(type_params.get("speed_multiplier", 1.0))
	desired_velocity = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(_param("speed_min"), _param("speed_max")) * multiplier
	if velocity.length_squared() < 1.0:
		velocity = desired_velocity

func _move_with_current_velocity(delta: float) -> void:
	var target_speed := desired_velocity.length()
	if target_speed > 0.1:
		var current_angle := velocity.angle() if velocity.length_squared() > 0.1 else desired_velocity.angle()
		var turned_angle := rotate_toward(current_angle, desired_velocity.angle(), delta * 1.7)
		var smoothed_speed := move_toward(velocity.length(), target_speed, delta * 45.0)
		velocity = Vector2.from_angle(turned_angle) * smoothed_speed
	var next_position := position + velocity * delta
	if _inside_wall(next_position):
		_choose_wall_detour()
		# Slow down while turning instead of instantly reversing direction.
		velocity *= maxf(1.0 - delta * 3.5, 0.65)
	else:
		position = next_position
	_bounce_inside_bounds()

func _choose_wall_detour() -> void:
	var speed := maxf(desired_velocity.length(), _param("speed_min"))
	var forward_angle := velocity.angle()
	var turn_sign := -1.0 if rng.randf() < 0.5 else 1.0
	# Prefer a modest turn, widening it only when the nearby route is blocked.
	for angle_degrees in [28.0, 48.0, 72.0, 105.0, 140.0]:
		for side in [turn_sign, -turn_sign]:
			var direction := Vector2.from_angle(forward_angle + deg_to_rad(angle_degrees) * side)
			if not _inside_wall(position + direction * 34.0):
				desired_velocity = direction * speed
				avoidance_timer = 0.65
				return
	# Only reverse when every gentler direction is obstructed.
	desired_velocity = -velocity.normalized() * speed
	avoidance_timer = 0.8

func _follow_guide(delta: float) -> void:
	var guide_velocity: Vector2 = group_guide.velocity
	var facing := guide_velocity.angle() if guide_velocity.length_squared() > 1.0 else 0.0
	var target := group_guide.global_position + _moving_formation_offset().rotated(facing) + follow_wobble
	var distance := global_position.distance_to(target)
	var desired_speed := clampf(distance * 1.8, 12.0, _param("speed_max") * 1.35)
	if avoidance_timer <= 0.0:
		desired_velocity = global_position.direction_to(target) * desired_speed
	_move_with_current_velocity(delta)

func _moving_formation_offset() -> Vector2:
	# Single-file queue behind the guide. A small sideways wobble keeps it organic.
	return Vector2(-group_slot * 36.0, 0.0)

func _build_line_barrier() -> void:
	line_barrier = StaticBody2D.new()
	line_barrier.collision_layer = 1
	line_barrier.collision_mask = 0
	var collision := CollisionShape2D.new()
	line_barrier_shape = RectangleShape2D.new()
	line_barrier_shape.size = Vector2(44.0, 32.0)
	collision.shape = line_barrier_shape
	line_barrier.add_child(collision)
	add_child(line_barrier)

func _update_line_barrier() -> void:
	if not is_instance_valid(previous_group_member):
		line_barrier.collision_layer = 0
		return
	var link := to_local(previous_group_member.global_position)
	line_barrier.position = link * 0.5
	line_barrier.rotation = link.angle()
	line_barrier_shape.size.x = maxf(link.length() + 8.0, 32.0)

func _param(key: String) -> float:
	return float(type_params.get(key, params[key]))

func _check_kid_collision() -> void:
	if collision_cooldown > 0.0:
		return
	if global_position.distance_to(player.global_position) <= float(type_params.collision_radius):
		player.apply_knockback(global_position, float(type_params.knockback_speed), float(type_params.knockback_duration))
		collision_cooldown = float(type_params.knockback_cooldown)

func _closest_attraction() -> Vector2:
	# Elderly tour groups synchronize around the same featured artwork.
	if tourist_type == "elderly" and bool(type_params.get("synchronized", false)):
		return attractions[0]
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
		var inward_x := 1.0 if position.x < bounds.position.x else -1.0
		desired_velocity.x = inward_x * maxf(absf(desired_velocity.x), 12.0)
		avoidance_timer = 0.5
	if position.y < bounds.position.y or position.y > bounds.end.y:
		var inward_y := 1.0 if position.y < bounds.position.y else -1.0
		desired_velocity.y = inward_y * maxf(absf(desired_velocity.y), 12.0)
		avoidance_timer = 0.5
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
		var is_video := bool(type_params.get("takes_video", false)) and state == CameraState.AIM
		var color := Color(0.95, 0.12, 0.55, 0.36) if is_video else (Color(1.0, 0.82, 0.18, 0.22) if state == CameraState.AIM else Color(1.0, 0.18, 0.12, 0.55))
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
	var type_label: String = {"kid": "KID", "influencer": "LIVE", "elderly": "GROUP"}.get(tourist_type, "")
	if is_tour_guide:
		type_label = "GUIDE"
	if type_label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-18, 35), type_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#222536"))
	if is_tour_guide:
		# A short pole and bright triangular flag keep the guide readable at a glance.
		draw_line(Vector2(11, -13), Vector2(11, -52), Color("#5a4632"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(12, -51), Vector2(34, -44), Vector2(12, -37)]), Color("#f04f4f"))
	if bool(type_params.get("takes_video", false)) and state == CameraState.AIM:
		draw_circle(Vector2(-25, -30), 5.0, Color("#ff1744"))
		draw_string(ThemeDB.fallback_font, Vector2(-17, -26), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ff1744"))
	if state == CameraState.AIM and not bool(type_params.get("takes_video", false)):
		draw_arc(Vector2.ZERO, 23.0, -PI / 2.0, -PI / 2.0 + TAU * (timer / _param("aim_duration")), 24, Color.WHITE, 3.0)
