@tool
class_name MuseumLevel
extends Node2D

@export var floor_number := 0:
	set(value): floor_number = value; queue_redraw()

func set_active(value: bool) -> void:
	visible = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	for wall in get_node("Walls").get_children():
		wall.collision_layer = 1 if value else 0

func wall_rects() -> Array:
	var result: Array = []
	for wall in get_node("Walls").get_children():
		result.append(wall.world_rect())
	return result

func artwork_nodes() -> Array:
	return get_node("Artworks").get_children()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(2400, 1800)), Color("#d8cebc"))
	draw_rect(Rect2(80,110,610,1580), Color("#e9e1d3"))
	draw_rect(Rect2(722,110,738,1580), Color("#ded5c6"))
	draw_rect(Rect2(1492,110,828,1580), Color("#e9e1d3"))
	for x in range(180, 2300, 220):
		draw_line(Vector2(x,110), Vector2(x,1690), Color(0.72,0.67,0.59,0.22), 2.0)
	for y in range(190, 1690, 220):
		draw_line(Vector2(80,y), Vector2(2320,y), Color(0.72,0.67,0.59,0.22), 2.0)
