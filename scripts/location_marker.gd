@tool
class_name MuseumLocationMarker
extends Node2D

const ENTRANCE_COLOR := Color("#2f80ed")
const EXIT_COLOR := Color("#27ae60")
const STAIRS_COLOR := Color("#9b51e0")

@export_enum("Entrance", "Exit", "Stairs") var marker_type := "Stairs":
	set(value): marker_type = value; queue_redraw()

func marker_color() -> Color:
	match marker_type:
		"Entrance": return ENTRANCE_COLOR
		"Exit": return EXIT_COLOR
		_: return STAIRS_COLOR

func _draw() -> void:
	match marker_type:
		"Entrance":
			draw_rect(Rect2(-42, -65, 84, 130), marker_color(), true)
			draw_string(ThemeDB.fallback_font, Vector2(-60,-80), "PYRAMID ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#222536"))
		"Exit":
			draw_rect(Rect2(-45,-65,90,130), marker_color(), true)
			draw_string(ThemeDB.fallback_font, Vector2(-20,6), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		"Stairs":
			draw_circle(Vector2.ZERO, 48.0, marker_color())
			draw_string(ThemeDB.fallback_font, Vector2(-26,6), "STAIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
