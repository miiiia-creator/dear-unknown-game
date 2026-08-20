class_name PinMark
extends Control
## The map's three pin states — stamped, open, locked — at list size, so a row
## in the destination list reads as the same thing as a dot on the map.

var state := "locked"


func setup(new_state: String) -> void:
	state = new_state
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20, 20)
	resized.connect(queue_redraw)


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.20
	match state:
		"stamped":
			var col := Pal.c("accent")
			draw_circle(centre, radius, col)
			draw_arc(centre, radius * 1.9, 0, TAU, 24, col, 1.0, true)
		"open":
			var col := Pal.c("good")
			draw_arc(centre, radius * 1.2, 0, TAU, 24, col, 1.6, true)
			draw_circle(centre, radius * 0.45, col)
		_:
			draw_arc(centre, radius * 1.1, 0, TAU, 24, Pal.c("ink_faint"), 1.0, true)
