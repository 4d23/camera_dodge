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
	# A compact museum refreshment cart.
	draw_rect(Rect2(-48, -42, 96, 70), Color("#236b78"), true)
	draw_rect(Rect2(-52, -48, 104, 12), Color("#d9f2f2"), true)
	draw_rect(Rect2(-42, -31, 84, 38), Color("#174c57"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-38, -14), "WATER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_circle(Vector2(-31, 31), 9.0, Color("#263238"))
	draw_circle(Vector2(31, 31), 9.0, Color("#263238"))
	draw_rect(Rect2(-7, -67, 14, 27), Color("#64d8ff"), true)
	draw_rect(Rect2(-5, -72, 10, 6), Color.WHITE, true)
