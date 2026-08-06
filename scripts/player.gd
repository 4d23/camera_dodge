extends CharacterBody2D

var speed: float
var acceleration: float
var deceleration: float
var controller_deadzone: float
var invulnerability_duration: float
var dash_speed: float
var dash_duration: float
var dash_cooldown: float
var invulnerable := false
var invulnerability_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_was_pressed := false
var last_move_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var knockback_timer := 0.0
var knockback_velocity := Vector2.ZERO

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		direction = wasd.normalized()
	var analog_direction := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if analog_direction.length() >= controller_deadzone:
		direction = analog_direction.limit_length(1.0)
	if direction.length_squared() > 0.0:
		last_move_direction = direction.normalized()
	# The named action makes dash testable and remappable while preserving the
	# existing Space-key control for projects without an explicit input mapping.
	var dash_pressed := Input.is_physical_key_pressed(KEY_SPACE) or (InputMap.has_action("dash") and Input.is_action_pressed("dash"))
	if dash_pressed and not dash_was_pressed and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0:
		dash_direction = last_move_direction
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
	dash_was_pressed = dash_pressed
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = knockback_velocity
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
	else:
		var target_velocity := direction * speed
		var change_rate := acceleration if direction.length_squared() > 0.0 else deceleration
		velocity = velocity.move_toward(target_velocity, change_rate * delta)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	move_and_slide()
	if invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			invulnerable = false
	queue_redraw()

func hit() -> void:
	invulnerable = true
	invulnerability_timer = invulnerability_duration
	queue_redraw()

func apply_knockback(source_position: Vector2, knockback_speed: float, duration: float) -> void:
	var away := global_position - source_position
	if away.length_squared() < 0.01:
		away = -last_move_direction
	knockback_velocity = away.normalized() * knockback_speed
	knockback_timer = duration

func configure(params: Dictionary) -> void:
	speed = float(params.speed)
	acceleration = float(params.acceleration)
	deceleration = float(params.deceleration)
	controller_deadzone = float(params.controller_deadzone)
	invulnerability_duration = float(params.invulnerability_duration)
	dash_speed = float(params.dash_speed)
	dash_duration = float(params.dash_duration)
	dash_cooldown = float(params.dash_cooldown)

func _draw() -> void:
	if invulnerable and int(invulnerability_timer * 12.0) % 2 == 0:
		return
	draw_circle(Vector2.ZERO, 18.0, Color("#f4d35e"))
	draw_circle(Vector2(0, -16), 9.0, Color("#f2c6a0"))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color.WHITE, 3.0)
	draw_line(Vector2(-9, 2), Vector2(9, 2), Color("#ee964b"), 5.0)
	if dash_timer > 0.0:
		draw_line(-dash_direction * 22.0, -dash_direction * 48.0, Color(1.0, 0.85, 0.3, 0.7), 8.0)
