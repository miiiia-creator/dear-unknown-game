class_name WorldMapView
extends Control
## The world as a grid of dots — the same visual language as the puzzles.
## Pins sit on true equirectangular coordinates, so the data in cities.json is
## just longitude/latitude run through one formula.

signal city_picked(city_id: String)

## 48 x 24 dot map, one cell per 7.5 degrees.
const LAND := [
	"................................................",
	".................####...........................",
	"......###############.........#################.",
	"...#################...#########################",
	"...#############......##########################",
	"....############......##########################",
	"......##########......#########################.",
	".......########.......########################..",
	"..........#####.......######################....",
	"...........###.......###########.####..#####....",
	"............##.......###########..##....####....",
	"...............###....#########........#######..",
	"..............######...########.........#######.",
	"..............######...#######...........#####..",
	"..............######...#######.........#######..",
	"...............#####....######........########..",
	"...............####......####..........#######..",
	"...............###......................#####.##",
	"................##............................##",
	"................#...............................",
	"................................................",
	"................................................",
	"................................................",
	"................................................",
]

## Where a label may sit relative to its pin, best first: above, below, then
## out to either side, then the diagonals. Values are multiples of the pin
## radius for the gap, and the text is centred on the resulting anchor.
##
## This replaced a hand-written table of per-city offsets. That table only
## covered the five destinations that existed when it was written, and London,
## Paris and Rome were already colliding; at twenty-five it would be a
## full-time job. Placement is worked out at draw time now, so a destination
## added later needs no entry anywhere.
const LABEL_SLOTS := [
	Vector2(0.0, -1.9),
	Vector2(0.0, 2.9),
	Vector2(1.0, 0.35),
	Vector2(-1.0, 0.35),
	Vector2(1.0, -1.5),
	Vector2(-1.0, -1.5),
	Vector2(1.0, 2.4),
	Vector2(-1.0, 2.4),
]

var _hover := ""
var _cells: Array = []      ## [Rect2, city_id] hit targets, rebuilt on draw
var _map_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _map_area() -> Rect2:
	var cell := floorf(minf(size.x / 48.0, size.y / 24.0))
	cell = maxf(cell, 2.0)
	var box := Vector2(48, 24) * cell
	return Rect2(((size - box) * 0.5).floor(), box)


func _draw() -> void:
	_map_rect = _map_area()
	var cell := _map_rect.size.x / 48.0
	var dot := maxf(1.0, floorf(cell * 0.62))
	var inset := (cell - dot) * 0.5

	var land := Pal.c("line_strong")
	land.a = 0.45
	for r in LAND.size():
		var row: String = LAND[r]
		for c in row.length():
			if row[c] != "#":
				continue
			draw_rect(Rect2(_map_rect.position + Vector2(c, r) * cell + Vector2(inset, inset),
					Vector2(dot, dot)), land)

	_draw_route()
	_draw_pins(cell)


## Dashed line joining the destinations already stamped, in travel order.
func _draw_route() -> void:
	var points: Array = []
	for city in GameData.cities:
		if GameData.is_city_complete(city["id"]):
			points.append(_point_for(city))
	if points.size() < 2:
		return
	var col := Pal.c("accent")
	col.a = 0.5
	for i in points.size() - 1:
		_dashed(points[i], points[i + 1], col)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var travelled := 0.0
	while travelled < length:
		var seg := minf(6.0, length - travelled)
		draw_line(a + dir * travelled, a + dir * (travelled + seg), col, 1.5, true)
		travelled += 11.0


func _point_for(city: Dictionary) -> Vector2:
	var m: Array = city["map"]
	return _map_rect.position + Vector2(float(m[0]) * _map_rect.size.x,
			float(m[1]) * _map_rect.size.y)


func _draw_pins(cell: float) -> void:
	_cells.clear()
	var font: Font = Pal.ui_font
	var radius := maxf(5.0, cell * 0.55)

	for city in GameData.cities:
		var id: String = city["id"]
		var p := _point_for(city)
		var unlocked := GameData.is_city_unlocked(id)
		var complete := GameData.is_city_complete(id)
		var hovered := _hover == id

		var col := Pal.c("ink_faint")
		if complete:
			col = Pal.c("accent")
		elif unlocked:
			col = Pal.c("good")

		if hovered:
			var halo := col
			halo.a = 0.22
			draw_circle(p, radius * 2.2, halo)

		if complete:
			draw_circle(p, radius, col)
			draw_arc(p, radius * 1.7, 0, TAU, 32, col, 1.5, true)
		elif unlocked:
			draw_circle(p, radius * 0.9, Pal.c("bg"))
			draw_arc(p, radius * 0.9, 0, TAU, 32, col, 2.0, true)
			draw_circle(p, radius * 0.35, col)
		else:
			draw_arc(p, radius * 0.8, 0, TAU, 32, col, 1.5, true)

		_cells.append([Rect2(p - Vector2(radius, radius) * 2.2,
				Vector2(radius, radius) * 4.4), id])

	_draw_labels(radius)


## Labels are placed after every pin is drawn, so a label can be tested against
## all of them rather than only the ones that happened to come first.
##
## Destinations you have reached are placed before ones you have not: when a
## corner of the map is too crowded for everything to fit, the names worth
## reading are the ones that win the room.
func _draw_labels(radius: float) -> void:
	var font: Font = Pal.ui_font
	var fsize := 13
	var taken: Array[Rect2] = []

	var ordered: Array = []
	for city in GameData.cities:
		var id: String = city["id"]
		var rank := 2
		if GameData.is_city_complete(id):
			rank = 0
		elif GameData.is_city_unlocked(id):
			rank = 1
		ordered.append([rank, city])
	ordered.sort_custom(func(a, b): return a[0] < b[0])

	# Pins themselves are obstacles: a name printed across a dot is worse than
	# a name printed slightly further out.
	var pins: Array[Rect2] = []
	for city in GameData.cities:
		var q := _point_for(city)
		pins.append(Rect2(q - Vector2(radius, radius), Vector2(radius, radius) * 2.0))

	for entry in ordered:
		var city: Dictionary = entry[1]
		var id: String = city["id"]
		var p := _point_for(city)
		var label: String = GameData.text(city["name"])
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x

		var best := Rect2()
		var found := false
		for slot in LABEL_SLOTS:
			var anchor := p + Vector2(
					(slot as Vector2).x * (radius + tw * 0.5 + 3.0),
					(slot as Vector2).y * radius)
			var box := Rect2(Vector2(anchor.x - tw * 0.5, anchor.y - fsize * 0.85),
					Vector2(tw, fsize * 1.05))
			if not _map_rect.encloses(box):
				continue
			if _clashes(box, taken) or _clashes(box, pins):
				continue
			best = box
			found = true
			break

		# Every slot is spoken for. Print it above anyway rather than dropping a
		# destination off the map, and let it be the one that reads as crowded.
		if not found:
			var anchor := p + Vector2(0.0, LABEL_SLOTS[0].y * radius)
			best = Rect2(Vector2(anchor.x - tw * 0.5, anchor.y - fsize * 0.85),
					Vector2(tw, fsize * 1.05))

		taken.append(best)
		var unlocked := GameData.is_city_unlocked(id)
		var text_col := Pal.c("ink") if (unlocked or _hover == id) else Pal.c("ink_faint")
		draw_string(font, Vector2(best.position.x, best.position.y + fsize * 0.85),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_col)


func _clashes(box: Rect2, against: Array[Rect2]) -> bool:
	var padded := box.grow(2.0)
	for other in against:
		if padded.intersects(other):
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := ""
		for entry in _cells:
			if (entry[0] as Rect2).has_point(event.position):
				found = entry[1]
				break
		if found != _hover:
			_hover = found
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for entry in _cells:
				if (entry[0] as Rect2).has_point(mb.position):
					city_picked.emit(entry[1])
					accept_event()
					return
