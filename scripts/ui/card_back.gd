class_name CardBack
extends Control
## The blank back of a city's card, which fills in as the city is solved.
##
## Each grid the city contains has a place on the back. Solved, its picture is
## printed there; next in line, a point of light sits where the picture will
## go; after that, nothing — an empty card gives away nothing about how much is
## still to come, which is the right amount to know.

signal slot_picked(puzzle_id: String)

const RATIO := 1.5

var city_id: String = ""

var _slots: Array = []          ## [Rect2, puzzle_id, solved]
var _pulse := 0.0
var _arrived := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	set_process(true)


func play_arrival() -> void:
	_arrived = 0.0


func _process(delta: float) -> void:
	_pulse += delta
	if _arrived < 1.0:
		_arrived = minf(1.0, _arrived + delta * 1.6)
	queue_redraw()


## Upright the card stands tall, matching the front.
func _card_rect() -> Rect2:
	var ratio := RATIO if size.x > size.y else 1.0 / RATIO
	var w := size.x
	var h := w / ratio
	if h > size.y:
		h = size.y
		w = h * ratio
	return Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())


func _draw() -> void:
	if city_id == "":
		return
	var palette: Array = GameData.city_palette(city_id)
	var paper: Color = palette[0]
	var deep: Color = palette[2]
	var card := _card_rect()

	draw_rect(card.grow(2.0), Color(0, 0, 0, 0.10))
	draw_rect(card, paper)
	var edge := deep.lerp(paper, 0.7)
	draw_rect(card, edge, false, maxf(1.0, card.size.y * 0.004))

	var puzzles: Array = GameData.puzzles_of(city_id)
	if puzzles.is_empty():
		return

	# Down the card in a column, generously spaced: the back is mostly paper,
	# and the pictures are what has been recovered from it so far.
	_slots.clear()
	var box := card.grow(-card.size.x * 0.16)
	var step := box.size.y / float(puzzles.size())
	var side := minf(box.size.x, step * 0.66)

	for i in puzzles.size():
		var p: Dictionary = puzzles[i]
		var centre := Vector2(card.get_center().x,
				box.position.y + step * (float(i) + 0.5))
		var rect := Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side))
		var solved: bool = SaveGame.is_solved(p["id"])
		_slots.append([rect, p["id"], solved])

		if solved:
			_draw_art(p["art"], rect, deep)
		elif _is_next(puzzles, i):
			_draw_light(centre, side * 0.16, palette[1])


func _is_next(puzzles: Array, index: int) -> bool:
	for i in puzzles.size():
		if not SaveGame.is_solved(puzzles[i]["id"]):
			return i == index
	return false


## The point of light. It breathes rather than blinks — a blinking dot is a
## notification, and this is meant to look like something waiting.
func _draw_light(centre: Vector2, radius: float, col: Color) -> void:
	var breath := 0.5 + 0.5 * sin(_pulse * 2.0)
	var halo := col
	halo.a = 0.10 + 0.16 * breath
	draw_circle(centre, radius * (2.6 + breath * 0.7), halo)
	halo.a = 0.22 + 0.20 * breath
	draw_circle(centre, radius * 1.7, halo)
	draw_circle(centre, radius * (0.85 + breath * 0.2), col)


func _draw_art(art: Array, rect: Rect2, col: Color) -> void:
	var rows := art.size()
	var cols := String(art[0]).length()
	var cell := floorf(minf(rect.size.x / float(cols), rect.size.y / float(rows)))
	if cell < 1.0:
		return
	var origin := rect.position + (rect.size - Vector2(cols, rows) * cell) * 0.5
	var ink := col
	ink.a = _arrived
	for r in rows:
		var line: String = art[r]
		for c in cols:
			if line[c] == ".":
				continue
			draw_rect(Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)), ink)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var pos: Vector2 = event.position
	for entry in _slots:
		var rect: Rect2 = entry[0]
		if not entry[2] and rect.grow(rect.size.x * 0.4).has_point(pos):
			slot_picked.emit(entry[1])
			accept_event()
			return
