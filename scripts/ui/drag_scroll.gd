class_name DragScroll
extends ScrollContainer
## A ScrollContainer you can drag.
##
## Godot's ScrollContainer answers the wheel and pan gestures but has no
## drag-to-scroll of its own, so on a touch screen a long page simply does not
## move. Handing the canvas its touch events back (the `touch-action: none` in
## the web shell) is necessary but not sufficient — something still has to turn
## a drag into scrolling, and that is this.
##
## Input is taken in `_input` rather than `_gui_input` because the pages are
## full of buttons, and a drag that starts on a tile would otherwise be eaten by
## the tile before the container ever sees it.

## How far a pointer travels before it counts as a drag rather than a tap. Below
## this a button still gets its press; above it the button is suppressed, so a
## scroll never fires the thing you dragged across.
const DRAG_THRESHOLD := 8.0

const FRICTION := 6.0
const MIN_FLING := 12.0

var _pointer_down := false
var _dragging := false
var _last_y := 0.0
var _travelled := 0.0
var _velocity := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_process(true)


func _process(delta: float) -> void:
	# Carry on a little after the finger lifts, then settle.
	if _dragging or absf(_velocity) < MIN_FLING:
		_velocity = 0.0
		return
	scroll_vertical -= int(_velocity * delta)
	_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var at: Vector2 = event.position
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if pressed:
			if not get_global_rect().has_point(at):
				return
			_pointer_down = true
			_dragging = false
			_travelled = 0.0
			_velocity = 0.0
			_last_y = at.y
		else:
			# Swallow the release that ends a drag, or the control underneath
			# fires as though it had been tapped.
			if _dragging:
				get_viewport().set_input_as_handled()
			_pointer_down = false
			_dragging = false
		return

	if not _pointer_down:
		return
	if not (event is InputEventScreenDrag or event is InputEventMouseMotion):
		return

	var y: float = event.position.y
	var dy := y - _last_y
	_last_y = y
	_travelled += absf(dy)
	if _travelled < DRAG_THRESHOLD:
		return

	_dragging = true
	scroll_vertical -= int(dy)
	# Pixels per second, for the fling that follows.
	_velocity = dy / maxf(get_process_delta_time(), 0.0001)
	get_viewport().set_input_as_handled()
