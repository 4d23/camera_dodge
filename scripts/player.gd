extends CharacterBody2D

const PLAYER_TEXTURE := preload("res://assets/player/player_cutout.png")
const FOOT_COLLISION_RADIUS := 17.0
const SPRITE_SCALE := 0.14
# The visible character ends at y=416 in the 447px source image. Offset it so
# the CharacterBody2D origin and collision circle sit at the character's feet.
const SPRITE_FOOT_OFFSET := Vector2(0, -27)

var speed: float
var acceleration: float
var deceleration: float
var controller_deadzone: float
var invulnerability_duration: float
var dash_speed: float
var dash_duration: float
var dash_cooldown: float
var debug_show_foot_circle := false
var invulnerable := false
var invulnerability_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_was_pressed := false
var last_move_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var knockback_timer := 0.0
var knockback_velocity := Vector2.ZERO
var character_sprite: Sprite2D

func _ready() -> void:
	z_as_relative = false
	_update_depth_z_index()
	character_sprite = Sprite2D.new()
	character_sprite.texture = PLAYER_TEXTURE
	character_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	character_sprite.position = SPRITE_FOOT_OFFSET
	add_child(character_sprite)

func _process(_delta: float) -> void:
	_update_depth_z_index()

func _update_depth_z_index() -> void:
	# The player's origin is already aligned with the character's feet.
	z_index = int(round(global_position.y))

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
	character_sprite.visible = not invulnerable or int(invulnerability_timer * 12.0) % 2 != 0
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
	debug_show_foot_circle = bool(params.get("debug_show_foot_circle", false))

func _draw() -> void:
	if debug_show_foot_circle:
		draw_circle(Vector2.ZERO, FOOT_COLLISION_RADIUS, Color(0.1, 1.0, 0.25, 0.2))
		draw_arc(Vector2.ZERO, FOOT_COLLISION_RADIUS, 0.0, TAU, 32, Color(0.1, 1.0, 0.25, 0.95), 2.0, true)
	if invulnerable and int(invulnerability_timer * 12.0) % 2 == 0:
		return
	if dash_timer > 0.0:
		draw_line(-dash_direction * 22.0, -dash_direction * 48.0, Color(1.0, 0.85, 0.3, 0.7), 8.0)
