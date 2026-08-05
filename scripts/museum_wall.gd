@tool
class_name MuseumWall
extends StaticBody2D

@export var wall_size := Vector2(200, 30):
	set(value):
		wall_size = value
		queue_redraw()
		_update_collision()

func _ready() -> void:
	_update_collision()
	queue_redraw()

func _update_collision() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	collision.shape = shape

func world_rect() -> Rect2:
	return Rect2(global_position - wall_size * 0.5, wall_size)

func _draw() -> void:
	draw_rect(Rect2(-wall_size * 0.5, wall_size), Color("#8f8170"), true)

