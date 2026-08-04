extends CharacterBody2D

var speed := 205.0
var invulnerable := false
var invulnerability_timer := 0.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		direction = wasd.normalized()
	velocity = direction * speed
	move_and_slide()
	if invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			invulnerable = false
	queue_redraw()

func hit() -> void:
	invulnerable = true
	invulnerability_timer = 1.0
	queue_redraw()

func _draw() -> void:
	if invulnerable and int(invulnerability_timer * 12.0) % 2 == 0:
		return
	draw_circle(Vector2.ZERO, 18.0, Color("#f4d35e"))
	draw_circle(Vector2(0, -16), 9.0, Color("#f2c6a0"))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color.WHITE, 3.0)
	draw_line(Vector2(-9, 2), Vector2(9, 2), Color("#ee964b"), 5.0)
