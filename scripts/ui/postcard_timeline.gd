class_name PostcardTimeline
extends Control
## The cards you have been sent, laid out by the day they were posted.
##
## Not by the order they arrived. Season Two was written in the middle of
## Season One, so a card earned late can land between two you have had for
## hours — and that is the whole point of showing this at all. Only earned
## cards appear: an empty slot would say "something belongs here, before one
## you already have", which gives the discrepancy away before it can be found.

signal picked(index: int)

const DRAG_THRESHOLD := 6.0

var entries: Array = []      ## [{"id", "label", "at"}] already in order
var index := 0

var _pointer_down := false
var _dragging := false
var _travelled := 0.0
var _last_x := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _slot_width() -> float:
	return maxf(48.0, size.x / maxf(3.0, float(entries.size())))


func _x_of(i: int) -> float:
	# The current card sits in the middle and the line slides under it, so the
	# thing you are looking at never moves.
	return size.x * 0.5 + (float(i) - float(index)) * _slot_width()


func _draw() -> void:
	if entries.is_empty():
		return
	var mid := size.y * 0.52
	var line := Pal.c("line_strong")
	line.a = 0.5
	draw_line(Vector2(0, mid), Vector2(size.x, mid), line, 1.0, true)

	var font: Font = Pal.ui_font
	for i in entries.size():
		var x := _x_of(i)
		if x < -60.0 or x > size.x + 60.0:
			continue
		var here := i == index
		var col: Color = Pal.c("accent") if here else Pal.c("ink_faint")
		if here:
			draw_circle(Vector2(x, mid), 4.5, col)
			draw_arc(Vector2(x, mid), 9.0, 0, TAU, 24, col, 1.0, true)
		else:
			draw_circle(Vector2(x, mid), 2.5, col)

		var label: String = str(entries[i].get("label", ""))
		if label == "":
			continue
		var fsize := 10
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var text_col: Color = Pal.c("ink_soft") if here else Pal.c("ink_faint")
		if not here:
			text_col.a = 0.6
		draw_string(font, Vector2(x - w * 0.5, mid + 20.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_col)


func _gui_input(event: InputEvent) -> void:
	if entries.is_empty():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var pressed: bool = event.pressed
		if pressed:
			_pointer_down = true
			_dragging = false
			_travelled = 0.0
			_last_x = event.position.x
		elif _pointer_down:
			_pointer_down = false
			if not _dragging:
				_tap(event.position.x)
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _pointer_down:
			return
		var dx: float = event.position.x - _last_x
		_travelled += absf(dx)
		if _travelled > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_scrub(dx)
			_last_x = event.position.x
		accept_event()


## Dragging moves the line under the card; each slot crossed is a card.
func _scrub(dx: float) -> void:
	var step := _slot_width()
	if absf(dx) < step * 0.5:
		return
	var want: int = index - signi(int(dx))
	_go(want)
	_last_x += dx


func _tap(x: float) -> void:
	var best := index
	var closest := 1e9
	for i in entries.size():
		var d: float = absf(_x_of(i) - x)
		if d < closest:
			closest = d
			best = i
	_go(best)


func _go(want: int) -> void:
	var next: int = clampi(want, 0, entries.size() - 1)
	if next == index:
		return
	index = next
	queue_redraw()
	picked.emit(index)
