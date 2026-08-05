@tool
class_name MuseumArtwork
extends Node2D

@export var artwork_name := "Artwork":
	set(value): artwork_name = value; queue_redraw()
@export var room_name := "Room":
	set(value): room_name = value; queue_redraw()
@export var artwork_texture: Texture2D:
	set(value): artwork_texture = value; queue_redraw()
@export var visit_radius := 55.0
var visited := false

func _ready() -> void:
	add_to_group("museum_artworks")
	queue_redraw()

func set_visited(value: bool) -> void:
	visited = value
	queue_redraw()

func _draw() -> void:
	var frame := Rect2(-42, -55, 84, 110)
	var image_rect := Rect2(-35, -48, 70, 96)
	draw_rect(frame, Color("#5b4636"), true)
	if artwork_texture:
		draw_texture_rect(artwork_texture, image_rect, false)
	draw_string(ThemeDB.fallback_font, Vector2(-65, -67), "%s • %s" % [room_name, artwork_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#222536"))
	if visited:
		draw_circle(Vector2.ZERO, 65.0, Color(0.25, 0.85, 0.5, 0.24))
		draw_string(ThemeDB.fallback_font, Vector2(-9, 8), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#174b32"))

