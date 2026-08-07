@tool
class_name MuseumWall
extends StaticBody2D

@export var wall_size := Vector2(200, 30):
	set(value):
		wall_size = value
		queue_redraw()
		_update_collision()
@export_enum("wall", "registration_desk", "information_kiosk", "column") var structure_type := "wall":
	set(value):
		structure_type = value
		queue_redraw()
@export var structure_label := "":
	set(value):
		structure_label = value
		queue_redraw()

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
	var rect := Rect2(-wall_size * 0.5, wall_size)
	match structure_type:
		"registration_desk":
			draw_rect(rect, Color("#51473f"), true)
			draw_rect(rect.grow(-7.0), Color("#8f6f50"), true)
			draw_line(Vector2(rect.position.x, rect.position.y + 9.0), Vector2(rect.end.x, rect.position.y + 9.0), Color("#d8b081"), 4.0)
			_draw_centered_label(structure_label if structure_label != "" else "REGISTRATION", Color.WHITE)
		"information_kiosk":
			draw_rect(rect, Color("#315d73"), true)
			draw_rect(rect.grow(-6.0), Color("#78a9b8"), true)
			_draw_centered_label(structure_label if structure_label != "" else "i", Color.WHITE, 22)
		"column":
			var radius := minf(wall_size.x, wall_size.y) * 0.5
			draw_circle(Vector2.ZERO, radius, Color("#746b61"))
			draw_circle(Vector2.ZERO, radius * 0.72, Color("#aaa093"))
		_:
			draw_rect(rect, Color("#8f8170"), true)

func _draw_centered_label(text: String, color: Color, font_size := 12) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(ThemeDB.fallback_font, Vector2(-text_size.x * 0.5, text_size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
