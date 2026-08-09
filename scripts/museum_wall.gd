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
@export_range(0.0, 200.0, 1.0) var visual_height := 44.0:
	set(value):
		visual_height = maxf(value, 0.0)
		queue_redraw()

func _ready() -> void:
	z_as_relative = false
	_update_static_z_index()
	_update_collision()
	queue_redraw()

func _update_static_z_index() -> void:
	# All world objects share the same depth scale. The footprint's bottom edge
	# is the wall or structure's contact point with the floor.
	z_index = int(round(global_position.y + wall_size.y * 0.5))

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
			var desk_height := minf(visual_height, 48.0)
			var desk_front := _draw_extruded_box(rect, desk_height, Color("#594638"), Color("#6c513b"), Color("#49372c"))
			draw_line(Vector2(desk_front.position.x, desk_front.position.y + 9.0), Vector2(desk_front.end.x, desk_front.position.y + 9.0), Color("#d8b081"), 4.0)
			_draw_centered_label_at(structure_label if structure_label != "" else "REGISTRATION", desk_front.get_center() + Vector2(0, 5), Color.WHITE)
		"information_kiosk":
			draw_rect(rect, Color("#315d73"), true)
			draw_rect(rect.grow(-6.0), Color("#78a9b8"), true)
			_draw_centered_label(structure_label if structure_label != "" else "i", Color.WHITE, 22)
		"column":
			var radius := minf(wall_size.x, wall_size.y) * 0.5
			draw_circle(Vector2.ZERO, radius, Color("#746b61"))
			draw_circle(Vector2.ZERO, radius * 0.72, Color("#aaa093"))
		_:
			_draw_extruded_box(rect, visual_height, Color("#655d54"), Color("#9f8e7b"), Color("#786958"))

func _draw_extruded_box(rect: Rect2, height: float, top_color: Color, front_color: Color, side_color: Color) -> Rect2:
	if height <= 0.0:
		draw_rect(rect, top_color, true)
		return rect
	var raised_rect := Rect2(rect.position - Vector2(0, height), rect.size)
	var front_rect := Rect2(Vector2(rect.position.x, raised_rect.end.y), Vector2(rect.size.x, height))
	var right_side := PackedVector2Array([
		raised_rect.position + Vector2(raised_rect.size.x, 0),
		raised_rect.end,
		rect.end,
		Vector2(rect.end.x, rect.position.y)
	])
	draw_colored_polygon(right_side, side_color)
	draw_rect(front_rect, front_color, true)
	draw_rect(raised_rect, top_color, true)
	draw_line(raised_rect.position, Vector2(raised_rect.end.x, raised_rect.position.y), top_color.lightened(0.16), 2.0)
	draw_line(Vector2(front_rect.position.x, front_rect.end.y), front_rect.end, front_color.darkened(0.2), 3.0)
	return front_rect

func _draw_centered_label(text: String, color: Color, font_size := 12) -> void:
	_draw_centered_label_at(text, Vector2.ZERO, color, font_size)

func _draw_centered_label_at(text: String, center: Vector2, color: Color, font_size := 12) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(ThemeDB.fallback_font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
