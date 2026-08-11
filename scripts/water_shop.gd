class_name WaterShop
extends StaticBody2D

const COLLISION_SIZE := Vector2(104.0, 76.0)
const COLLISION_OFFSET := Vector2(0.0, -10.0)
const PURCHASE_DISTANCE := 48.0
var structure_type := "water_shop"

func _ready() -> void:
	z_as_relative = false
	z_index = int(global_position.y)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = COLLISION_SIZE
	collision.shape = shape
	collision.position = COLLISION_OFFSET
	add_child(collision)
	queue_redraw()

func player_is_next_to(player_position: Vector2) -> bool:
	return world_rect().grow(PURCHASE_DISTANCE).has_point(player_position)

func world_rect() -> Rect2:
	return Rect2(global_position + COLLISION_OFFSET - COLLISION_SIZE * 0.5, COLLISION_SIZE)

func _draw() -> void:
	# Blue canopy, stocked display, serving counter, and cart wheels.
	draw_rect(Rect2(-54, -55, 108, 14), Color("#e6fbff"), true)
	for stripe_x in range(-54, 54, 27):
		draw_rect(Rect2(stripe_x, -55, 13.5, 14), Color("#42b8d4"), true)
	draw_rect(Rect2(-48, -41, 96, 69), Color("#236b78"), true)
	draw_rect(Rect2(-52, -45, 104, 10), Color("#d9f2f2"), true)
	draw_rect(Rect2(-42, -31, 84, 38), Color("#174c57"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-38, -14), "WATER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	for bottle_x in [-24.0, 0.0, 24.0]:
		draw_rect(Rect2(bottle_x - 4, -39, 8, 19), Color("#64d8ff"), true)
		draw_rect(Rect2(bottle_x - 3, -43, 6, 5), Color.WHITE, true)
	draw_circle(Vector2(-31, 31), 9.0, Color("#263238"))
	draw_circle(Vector2(31, 31), 9.0, Color("#263238"))
	draw_circle(Vector2(-31, 31), 3.5, Color("#aebbc0"))
	draw_circle(Vector2(31, 31), 3.5, Color("#aebbc0"))
