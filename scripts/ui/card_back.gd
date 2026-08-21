class_name CardBack
extends Control
## The blank back of a city's card, which fills in as the city is solved.
##
## Each grid the city contains has a place on the back. Solved, its picture is
## printed there; next in line, a point of light sits where the picture will
## go; after that, nothing — an empty card gives away nothing about how much is
## still to come, which is the right amount to know.

signal slot_picked(puzzle_id: String)

## A press that landed on the dark around the card rather than on the card. The
## screen holds the card up out of the page, so the page around it is the way
## to put it down again.
signal dismissed

const RATIO := 1.5

var city_id: String = ""

## The card is whatever shape the city's picture is. Both faces have to read it
## from the same place, or turning the card changes its size in your hand.
var _aspect := 1.0 / RATIO

var _slots: Array = []          ## [Rect2, puzzle_id, solved]
var _pulse := 0.0
var _arrived := 0.0


func _ready() -> void:
	_measure()
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	set_process(true)


func _measure() -> void:
	for ext in [".png", ".jpg", ".jpeg", ".webp"]:
		var path: String = "res://assets/postcards/" + city_id + str(ext)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex != null and tex.get_height() > 0:
			_aspect = float(tex.get_width()) / float(tex.get_height())
			return


func play_arrival() -> void:
	_arrived = 0.0


func _process(delta: float) -> void:
	_pulse += delta
	if _arrived < 1.0:
		_arrived = minf(1.0, _arrived + delta * 1.6)
	queue_redraw()


## Upright the card stands tall, matching the front.
func _card_rect() -> Rect2:
	var ratio := _aspect
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

	# One scale for every discovery on the card, and the positions worked out
	# rather than measured by hand.
	#
	# They used to come from a per-city `composition` table giving each piece a
	# width as a fraction of the card. That made Tokyo's five-by-five pond cells
	# ten times the area of the ten-by-ten gate's beside it — a slab of black
	# next to a smudge — and it only covered the five destinations that existed
	# when it was written, so the other six stacked every piece in the middle of
	# the card on top of itself.
	#
	# A card is a sheet with the things you found pinned to it, so they are all
	# pinned at the same size: one cell measurement shared by every grid, which
	# makes a ten-by-ten twice the picture a five-by-five is, because it is.
	_slots.clear()
	var gap := 1.6                     # in cells, between one piece and the next
	var span := 0.0
	var tallest := 1.0
	for p in puzzles:
		span += float(String(p["art"][0]).length())
		tallest = maxf(tallest, float(p["art"].size()))
	span += gap * float(maxi(0, puzzles.size() - 1))

	var cell := minf(card.size.x * 0.78 / span, card.size.y * 0.40 / tallest)
	cell = maxf(1.0, floorf(cell))
	var x := card.position.x + (card.size.x - span * cell) * 0.5
	# The row sits below the middle, where a hand would lay things out, and each
	# piece stands on a line of its own so the card is not a shelf.
	var baseline := card.position.y + card.size.y * 0.62

	for i in puzzles.size():
		var p: Dictionary = puzzles[i]
		var rows := float(p["art"].size())
		var cols := float(String(p["art"][0]).length())
		var w := cols * cell
		var h := rows * cell
		var lift := card.size.y * (0.05 if i % 2 == 1 else 0.0)
		var rect := Rect2(x, baseline - h - lift, w, h)
		x += w + gap * cell
		var solved: bool = SaveGame.is_solved(p["id"])
		_slots.append([rect, p["id"], solved])

		if solved:
			_draw_art(p["art"], rect, deep, p.get("palette", []))
		elif _is_next(puzzles, i):
			_draw_light(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.14,
					palette[1])


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


## A discovery as it sits on the card.
##
## It used to be one flat colour with no gaps, which on a sheet of pale paper is
## a lump of black — and on a grid that was solved in four inks it threw all
## four away. A discovery is a grid of marks, not a silhouette: the cells keep
## the hairline between them that the board draws, and they keep the colours
## they were solved in. What lands on the card is the picture you made.
func _draw_art(art: Array, rect: Rect2, col: Color, inks: Array = []) -> void:
	var rows := art.size()
	var cols := String(art[0]).length()
	var cell := floorf(minf(rect.size.x / float(cols), rect.size.y / float(rows)))
	if cell < 1.0:
		return
	# Air between the marks, but never so much that a small piece falls apart:
	# below three points a cell the gap is not drawn at all.
	var gap := 1.0 if cell >= 3.0 else 0.0
	var origin := rect.position + (rect.size - Vector2(cols, rows) * cell) * 0.5
	for r in rows:
		var line: String = art[r]
		for c in cols:
			var ch: String = line[c]
			if ch == ".":
				continue
			var ink := col
			if not inks.is_empty():
				var which := 0 if ch == "#" else int(ch) - 1
				if which >= 0 and which < inks.size():
					ink = Color(inks[which])
			ink.a = _arrived
			draw_rect(Rect2(origin + Vector2(c, r) * cell,
					Vector2(cell - gap, cell - gap)), ink)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var pos: Vector2 = event.position

	# The waiting light first, and with room around it: it is a small mark on a
	# large card, and it is the thing the screen is asking you to press.
	for entry in _slots:
		var rect: Rect2 = entry[0]
		if not entry[2] and rect.grow(rect.size.x * 0.4).has_point(pos):
			slot_picked.emit(entry[1])
			accept_event()
			return

	# Then the pictures already recovered. A finished grid was a picture and
	# nothing else, so a solved destination was a card you could only look at —
	# there was no way back into a puzzle once it had been done. They open the
	# grid they came from, where Reset is waiting for anyone who wants to solve
	# it again. No extra room around these: they sit where the composition puts
	# them, which is sometimes close together.
	for entry in _slots:
		if entry[2] and (entry[0] as Rect2).has_point(pos):
			slot_picked.emit(entry[1])
			accept_event()
			return

	if not _card_rect().has_point(pos):
		dismissed.emit()
		accept_event()
