extends CharacterBody2D

var speed: float
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

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		direction = wasd.normalized()
	if direction.length_squared() > 0.0:
		last_move_direction = direction.normalized()
	var dash_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if dash_pressed and not dash_was_pressed and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0:
		dash_direction = last_move_direction
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
	dash_was_pressed = dash_pressed
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
	else:
		velocity = direction * speed
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

func configure(params: Dictionary) -> void:
	speed = float(params.speed)
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
