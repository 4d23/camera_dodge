class_name IceCreamShop
extends StaticBody2D

const COLLISION_SIZE := Vector2(110.0, 78.0)
const COLLISION_OFFSET := Vector2(0.0, -10.0)
const PURCHASE_DISTANCE := 48.0
var structure_type := "ice_cream_shop"

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
	# Striped canopy and serving cart.
	draw_rect(Rect2(-57, -55, 114, 14), Color("#fff3db"), true)
	for stripe_x in range(-57, 57, 28):
		draw_rect(Rect2(stripe_x, -55, 14, 14), Color("#ef7598"), true)
	draw_rect(Rect2(-51, -41, 102, 68), Color("#f6c8d5"), true)
	draw_rect(Rect2(-45, -32, 90, 36), Color("#fff8ed"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-39, -10), "ICE CREAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#793b56"))
	# Cone display on the counter.
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -58), Vector2(7, -58), Vector2(0, -35)]), Color("#d99b54"))
	draw_circle(Vector2(0, -65), 10.0, Color("#f5a7c2"))
	draw_circle(Vector2(-31, 31), 10.0, Color("#34313b"))
	draw_circle(Vector2(31, 31), 10.0, Color("#34313b"))
	draw_circle(Vector2(-31, 31), 4.0, Color("#c4c1c8"))
	draw_circle(Vector2(31, 31), 4.0, Color("#c4c1c8"))
