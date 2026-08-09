@tool
class_name MuseumArtwork
extends Node2D

const ART_FRAME := Rect2(-42, -55, 84, 110)
const ART_IMAGE := Rect2(-35, -48, 70, 96)
const ART_FRAME_BOTTOM_Y := 55.0

@export var artwork_name := "Artwork":
	set(value): artwork_name = value; queue_redraw()
@export var room_name := "Room":
	set(value): room_name = value; queue_redraw()
@export var artwork_texture: Texture2D:
	set(value): artwork_texture = value; queue_redraw()
var visited := false
var view_progress := 0.0
var seconds_remaining := 0.0

func _ready() -> void:
	z_as_relative = false
	_update_static_z_index()
	add_to_group("museum_artworks")
	queue_redraw()

func _update_static_z_index() -> void:
	z_index = int(round(global_position.y + ART_FRAME_BOTTOM_Y * absf(global_scale.y)))

func set_visited(value: bool) -> void:
	visited = value
	queue_redraw()

func contains_world_point(point: Vector2) -> bool:
	var carpet := get_node_or_null("Carpet") as Polygon2D
	return carpet != null and Geometry2D.is_point_in_polygon(carpet.to_local(point), carpet.polygon)

func viewing_position() -> Vector2:
	var carpet := get_node_or_null("Carpet") as Polygon2D
	if carpet == null or carpet.polygon.is_empty():
		return global_position
	var center := Vector2.ZERO
	for point in carpet.polygon:
		center += point
	return carpet.to_global(center / carpet.polygon.size())

func set_view_progress(progress: float, remaining: float) -> void:
	view_progress = clampf(progress, 0.0, 1.0)
	seconds_remaining = remaining
	queue_redraw()

func _draw() -> void:
	draw_rect(ART_FRAME, Color("#5b4636"), true)
	if artwork_texture:
		draw_texture_rect(artwork_texture, ART_IMAGE, false)
	draw_string(ThemeDB.fallback_font, Vector2(-65, -67), "%s • %s" % [room_name, artwork_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#222536"))
	if visited:
		draw_circle(Vector2.ZERO, 65.0, Color(0.25, 0.85, 0.5, 0.24))
		draw_string(ThemeDB.fallback_font, Vector2(-9, 8), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#174b32"))
	elif view_progress > 0.0:
		draw_rect(Rect2(-50, 64, 100, 10), Color("#252936"), true)
		draw_rect(Rect2(-48, 66, 96 * view_progress, 6), Color("#f4d35e"), true)
		draw_string(ThemeDB.fallback_font, Vector2(-18, 92), "%.1fs" % seconds_remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#222536"))
