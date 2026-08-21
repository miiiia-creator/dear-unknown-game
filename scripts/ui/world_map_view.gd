class_name WorldMapView
extends Control
## The world as a grid of dots — the same visual language as the puzzles.
## Pins sit on true equirectangular coordinates, so the data in cities.json is
## just longitude/latitude run through one formula.
##
## No names on it. Every pin used to carry its destination beside it, placed by
## a solver that tried eight slots and gave up gracefully — and in Europe half a
## dozen of them still printed over each other, which is what a map of ten
## places in a band of sixty degrees is always going to do. The list directly
## underneath names all of them, in order, with room. The map's job is where,
## not what.

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

## The destination being travelled to. The map and the list are one screen now,
## so the map is not a separate index of the same places — it is where the one
## you are on happens to be. Everything else steps back.
var focus_id := ""

var _hover := ""
var _cells: Array = []      ## [Rect2, city_id] hit targets, rebuilt on draw
var _map_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func focus(city_id: String) -> void:
	if city_id == focus_id:
		return
	focus_id = city_id
	queue_redraw()


## How much of its colour a pin keeps. Nothing is hidden — a dimmed pin is
## still a place you have been — but only one of them is the subject.
func _weight(city_id: String) -> float:
	if focus_id == "" or city_id == focus_id:
		return 1.0
	return 0.34


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

	_draw_pins(cell)


## The dashed line between stamped destinations is gone. It joined them in the
## order they were played, which quietly claimed that was the order the cards
## were sent — and the postmarks say otherwise, or will once the dates are
## settled. A map that asserts something the letters have not decided is worse
## than a map with nothing drawn on it.
func _point_for(city: Dictionary) -> Vector2:
	var m: Array = city["map"]
	return _map_rect.position + Vector2(float(m[0]) * _map_rect.size.x,
			float(m[1]) * _map_rect.size.y)


func _draw_pins(cell: float) -> void:
	_cells.clear()
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
		col.a *= _weight(id)

		if id == focus_id:
			var ring := Pal.c("accent")
			ring.a = 0.16
			draw_circle(p, radius * 2.6, ring)
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
