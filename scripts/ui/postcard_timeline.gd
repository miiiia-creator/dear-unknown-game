class_name PostcardTimeline
extends Control
## The cards you have been sent, laid out by the day they were posted.
##
## Not by the order they arrived. Season Two was written in the middle of
## Season One, so a card earned late can land between two you have had for
## hours — and that is the whole point of showing this at all. Only earned
## cards appear: an empty slot would say "something belongs here, before one
## you already have", which gives the discrepancy away before it can be found.
##
## The card being read is always the one under the mark in the middle. You pull
## the line left and right beneath it, it carries on a little when you let go,
## and it always comes to rest on a card rather than between two. The dots used
## to be the tap targets: four pixels wide, eleven of them across a phone, which
## is less a control than a dare. They are a scale now, not a menu.

signal picked(index: int)

## How far a pointer travels before it counts as a drag rather than a tap.
const DRAG_THRESHOLD := 6.0

## Wide enough that one card is a deliberate push rather than a twitch.
const SLOT_MIN := 68.0

## Fling decay, and the speed under which the line counts as stopped. Both in
## slots per second.
const FRICTION := 7.0
const STOPPED := 0.25
const MAX_FLING := 14.0

## How hard the line is pulled onto the nearest card once it has stopped.
const SNAP := 14.0

var entries: Array = []      ## [{"id", "label", "at"}] already in order
var index := 0               ## the card in the middle, updated as you drag

var _scroll := 0.0           ## where the middle of the line has got to, in slots
var _spoken := -1            ## the last index handed to `picked`
var _pointer_down := false
var _dragging := false
var _travelled := 0.0
var _last_x := 0.0
var _velocity := 0.0
var _aim := -1               ## a tapped card to glide to, or -1 for the nearest


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_scroll = float(index)
	_spoken = index
	set_process(true)


func _last() -> float:
	return maxf(0.0, float(entries.size() - 1))


func _slot_width() -> float:
	return maxf(SLOT_MIN, size.x / maxf(3.0, float(entries.size())))


func _x_of(i: int) -> float:
	return size.x * 0.5 + (float(i) - _scroll) * _slot_width()


func _focus() -> int:
	return clampi(roundi(_scroll), 0, maxi(0, entries.size() - 1))


# -- motion ----------------------------------------------------------------

func _process(delta: float) -> void:
	if entries.is_empty() or _dragging:
		return
	if absf(_velocity) > STOPPED:
		_glide(delta)
	else:
		_settle(delta)


## Carry on after the finger lifts, and let friction take it.
func _glide(delta: float) -> void:
	var was := _scroll
	_scroll = clampf(_scroll + _velocity * delta, 0.0, _last())
	if is_equal_approx(_scroll, was):
		_velocity = 0.0     # ran into an end
		return
	_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta)
	_mark()


## The line comes to rest on a card, never between two.
func _settle(delta: float) -> void:
	_velocity = 0.0
	var target := float(_aim) if _aim >= 0 else float(_focus())
	if is_equal_approx(_scroll, target):
		_aim = -1
		_announce()
		return
	_scroll = lerpf(_scroll, target, clampf(SNAP * delta, 0.0, 1.0))
	if absf(_scroll - target) < 0.002:
		_scroll = target
	_mark()


## Which card the mark is over. The tick is the detent you can feel on a dial:
## the line is continuous, the cards are not.
func _mark() -> void:
	var f := _focus()
	if f != index:
		index = f
		Sfx.play("nav")
	queue_redraw()


## The card behind the line is only swapped once the line has stopped: setting
## one up loads a painting and starts its film, which is not something to do
## five times on the way past.
func _announce() -> void:
	if index == _spoken:
		return
	_spoken = index
	picked.emit(index)


# -- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if entries.is_empty():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_pointer_down = true
			_dragging = false
			_travelled = 0.0
			_velocity = 0.0
			_aim = -1
			_last_x = event.position.x
		elif _pointer_down:
			_pointer_down = false
			if not _dragging:
				_aim = _nearest(event.position.x)
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _pointer_down:
			return
		var dx: float = event.position.x - _last_x
		_last_x = event.position.x
		_travelled += absf(dx)
		if _travelled < DRAG_THRESHOLD:
			return
		_dragging = true
		# Pulling the line right moves it towards the cards you already passed.
		var slots := -dx / _slot_width()
		_scroll = clampf(_scroll + slots, 0.0, _last())
		_velocity = clampf(slots / maxf(get_process_delta_time(), 0.0001),
				-MAX_FLING, MAX_FLING)
		_mark()
		accept_event()


func _nearest(x: float) -> int:
	var best := index
	var closest := 1e9
	for i in entries.size():
		var d: float = absf(_x_of(i) - x)
		if d < closest:
			closest = d
			best = i
	return best


# -- drawing ---------------------------------------------------------------

func _draw() -> void:
	if entries.is_empty():
		return
	var mid := size.y * 0.52
	var centre := size.x * 0.5
	var rule := Pal.c("line_strong")
	rule.a = 0.5
	draw_line(Vector2(0, mid), Vector2(size.x, mid), rule, 1.0, true)

	var accent: Color = Pal.c("accent")
	# The reading position is a fixed mark; the postmarks run under it. Which
	# card you are on is where the line has got to, not which dot you hit.
	draw_arc(Vector2(centre, mid), 9.0, 0, TAU, 28, accent, 1.0, true)

	var font: Font = Pal.ui_font
	var fsize := 10
	var taken: Array[Rect2] = []
	# Nearest the mark first, so the date under it always wins the room and the
	# ones crowding it go without.
	for i in _by_nearest():
		var x := _x_of(i)
		if x < -40.0 or x > size.x + 40.0:
			continue
		var here := i == index
		# Out at the edges a card is context, not something to read.
		var fade := clampf(1.0 - absf(x - centre) / maxf(centre, 1.0) * 0.7, 0.25, 1.0)

		var col: Color = accent if here else Pal.c("ink_faint")
		if not here:
			col.a *= fade
		draw_circle(Vector2(x, mid), 4.0 if here else 2.5, col)

		var label := str(entries[i].get("label", ""))
		if label == "":
			continue
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var box := Rect2(Vector2(x - w * 0.5, mid + 11.0), Vector2(w, float(fsize) * 1.2))
		if _clashes(box, taken):
			continue
		taken.append(box)
		var text_col: Color = Pal.c("ink_soft") if here else Pal.c("ink_faint")
		if not here:
			text_col.a *= fade
		draw_string(font, Vector2(box.position.x, mid + 20.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_col)

	# Nothing else on screen says this line can be pulled, and a control whose
	# only affordance is that you happened to try it is not a control.
	if _scroll > 0.02:
		_chevron(10.0, mid, -1.0)
	if _scroll < _last() - 0.02:
		_chevron(size.x - 10.0, mid, 1.0)


func _chevron(x: float, y: float, dir: float) -> void:
	var col := Pal.c("ink_faint")
	col.a *= 0.7
	draw_polyline(PackedVector2Array([Vector2(x - 3.0 * dir, y - 4.0),
			Vector2(x + 1.0 * dir, y), Vector2(x - 3.0 * dir, y + 4.0)]),
			col, 1.0, true)


func _by_nearest() -> Array[int]:
	var order: Array[int] = []
	for i in entries.size():
		order.append(i)
	var centre := size.x * 0.5
	order.sort_custom(func(a, b): return absf(_x_of(a) - centre) < absf(_x_of(b) - centre))
	return order


func _clashes(box: Rect2, against: Array[Rect2]) -> bool:
	var padded := box.grow(4.0)
	for other in against:
		if padded.intersects(other):
			return true
	return false
