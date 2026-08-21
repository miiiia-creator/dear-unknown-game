class_name SolidView
extends Control
## The block, drawn as cubes and answering a thumb.
##
## Isometric rather than the oblique projection the relief spike used: an
## oblique block only ever shows you one face, and the whole point here is that
## a cube is constrained from three directions at once. You should be able to
## see three of them without turning anything.
##
## Turning is in quarters. A free orbit reads better in a trailer and is worse
## to play with one hand — you end up nudging it back to square before every
## tap. Four steps around, and a tilt to get underneath, reaches all six faces.

signal cube_picked(cell: Vector3i)
signal cube_marked(cell: Vector3i)

## Half-width and half-height of a cube's top face. 2:1 is the flatter,
## friendlier isometric; true 30° is prettier and gives smaller tap targets.
const HALF := Vector2(0.5, 0.25)

var puzzle: Solid
var turn := 0                     ## quarter turns about the upright axis
var tilt := 1                     ## 1 looking down, -1 looking up

var _scale := 26.0
var _origin := Vector2.ZERO
var _faces: Array = []            ## [PackedVector2Array, Vector3i] front-last
var _hover := Vector3i(-1, -1, -1)
## The shape as the camera has it, so a clue along "the way I am looking" does
## not have to work out which world axis that is this quarter turn.
var _seen: Array = []
## And what is still standing there, which is what a clue has to sit on.
var _here: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func rotate_by(quarters: int) -> void:
	turn = posmod(turn + quarters, 4)
	queue_redraw()


func flip() -> void:
	tilt = -tilt
	queue_redraw()


## World cell to the space the camera sees, so that turning the block is a
## relabelling rather than a second set of drawing code.
func _viewed(c: Vector3i) -> Vector3:
	var n := puzzle.size
	var x := float(c.x)
	var z := float(c.z)
	match turn:
		1: 
			var t := x
			x = z
			z = float(n.x - 1) - t
		2:
			x = float(n.x - 1) - x
			z = float(n.z - 1) - z
		3:
			var t2 := x
			x = float(n.z - 1) - z
			z = t2
	var y := float(c.y)
	if tilt < 0:
		y = float(n.y - 1) - y
	return Vector3(x, y, z)


func _project(v: Vector3) -> Vector2:
	return _origin + Vector2(
			(v.x - v.z) * HALF.x * _scale,
			(v.x + v.z) * HALF.y * _scale - v.y * _scale * 0.62)


func _measure() -> void:
	var n := puzzle.size
	var span_x := float(n.x + n.z) * HALF.x
	var span_y := float(n.x + n.z) * HALF.y + float(n.y) * 0.62
	_scale = minf(size.x * 0.96 / maxf(span_x, 0.001),
			size.y * 0.96 / maxf(span_y, 0.001))
	_origin = Vector2.ZERO
	# Centre on the block's own extent rather than on the origin cube.
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for corner in [Vector3(0, 0, 0), Vector3(n.x, 0, 0), Vector3(0, 0, n.z),
			Vector3(n.x, 0, n.z), Vector3(0, n.y, 0), Vector3(n.x, n.y, 0),
			Vector3(0, n.y, n.z), Vector3(n.x, n.y, n.z)]:
		var p := _project(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	_origin = (size - (hi - lo)) * 0.5 - lo


## Rebuild the view-space copy of the shape. 125 cells; cheaper than carrying an
## inverse of the rotation around and much harder to get subtly wrong.
func _look() -> void:
	var n := puzzle.size
	_seen = []
	_here = []
	for grid in [_seen, _here]:
		for y in n.y:
			var plane: Array = []
			for z in n.z:
				var row: Array = []
				row.resize(n.x)
				row.fill(false)
				plane.append(row)
			grid.append(plane)
	for y in n.y:
		for z in n.z:
			for x in n.x:
				var c := Vector3i(x, y, z)
				var v := _viewed(c)
				if puzzle.solid_at(c):
					_seen[int(v.y)][int(v.z)][int(v.x)] = true
				if puzzle.present(c):
					_here[int(v.y)][int(v.z)][int(v.x)] = true


## Count and pieces along one line of the view-space shape.
func _seen_clue(axis: int, a: int, b: int) -> Vector2i:
	var n := puzzle.size
	var length: int = [n.x, n.y, n.z][axis]
	var count := 0
	var runs := 0
	var was := false
	for i in length:
		var here: bool
		match axis:
			0: here = _seen[a][b][i]
			1: here = _seen[i][b][a]
			_: here = _seen[a][i][b]
		if here:
			count += 1
			if not was:
				runs += 1
		was = here
	return Vector2i(count, runs)


func _draw() -> void:
	if puzzle == null:
		return
	_measure()
	_look()
	_faces.clear()

	# Back to front, so a cube in front is drawn over the one behind it and the
	# last thing written into any pixel is the thing you can actually touch.
	var order: Array = []
	for y in puzzle.size.y:
		for z in puzzle.size.z:
			for x in puzzle.size.x:
				var c := Vector3i(x, y, z)
				if not puzzle.present(c):
					continue
				var v := _viewed(c)
				order.append([v.x + v.z + v.y * 0.5, c, v])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for entry in order:
		_draw_cube(entry[1], entry[2])
	_draw_clues()


## A clue rides on the outermost cube of its line that is still standing, so it
## moves inward as the block is opened up. Written on the bounding box instead,
## the numbers went on hanging in the air over cubes that were no longer there —
## and a clue you cannot point at is a clue about nothing.
func _draw_clues() -> void:
	var n := puzzle.size
	var font: Font = Pal.mono_font
	# Sized to the short way across a projected face, which on an isometric top
	# is a quarter of the long way — the number has to fit the smaller one.
	var fsize := int(clampf(_scale * HALF.y * 1.5, 8.0, 22.0))
	for a in n.x:
		for b in n.z:
			var d := _outermost(1, a, b)
			if d >= 0:
				_clue_at(font, fsize, _seen_clue(1, a, b),
						Vector3(float(a) + 0.5, float(d) + 1.0, float(b) + 0.5))
	for a in n.x:
		for b in n.y:
			var d := _outermost(2, a, b)
			if d >= 0:
				_clue_at(font, fsize, _seen_clue(2, a, b),
						Vector3(float(a) + 0.5, float(b) + 0.5, float(d) + 1.0))
	for a in n.y:
		for b in n.z:
			var d := _outermost(0, a, b)
			if d >= 0:
				_clue_at(font, fsize, _seen_clue(0, a, b),
						Vector3(float(d) + 1.0, float(a) + 0.5, float(b) + 0.5))


## How far in the first standing cube of a line is, counted from the face the
## camera is on. -1 when the line has been emptied.
func _outermost(axis: int, a: int, b: int) -> int:
	var n := puzzle.size
	var length: int = [n.x, n.y, n.z][axis]
	for step in length:
		var i := length - 1 - step
		var here: bool
		match axis:
			0: here = _here[a][b][i]
			1: here = _here[i][b][a]
			_: here = _here[a][i][b]
		if here:
			return i
	return -1


## A plain number is one run, a ring is two, a box is three or more. Nothing at
## all means the line is empty, which is a clue in itself and the loudest one.
func _clue_at(font: Font, fsize: int, clue: Vector2i, at: Vector3) -> void:
	if clue.x <= 0:
		return
	var p := _project(at)
	var text := str(clue.x)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var ink: Color = Pal.c("ink")
	if clue.y >= 2:
		var mark: Color = Pal.c("accent")
		# Inside the cell it belongs to, not spilling into the two beside it.
		var r := float(fsize) * 0.62
		if clue.y == 2:
			draw_arc(p, r, 0, TAU, 18, mark, 1.0, true)
		else:
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0),
					mark, false, 1.0)
	draw_string(font, p + Vector2(-w.x * 0.5, w.y * 0.32), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, ink)


func _draw_cube(c: Vector3i, v: Vector3) -> void:
	var kept := puzzle.state_at(c) == Solid.KEPT
	var base: Color = Pal.c("accent") if kept else Pal.c("panel_alt")
	if _hover == c:
		base = base.lerp(Pal.c("good"), 0.35)
	var top := _face(v, "top")
	var left := _face(v, "left")
	var right := _face(v, "right")
	# One light, from over the left shoulder, which is what tells a stack of
	# squares that it is a stack of cubes.
	draw_colored_polygon(top, base.lerp(Color.WHITE, 0.22))
	draw_colored_polygon(left, base.lerp(Color.BLACK, 0.10))
	draw_colored_polygon(right, base.lerp(Color.BLACK, 0.28))
	var seam := Pal.c("line_strong")
	seam.a = 0.5
	for poly in [top, left, right]:
		draw_polyline(poly + PackedVector2Array([poly[0]]), seam, 1.0, true)
	# The hexagon is the union of the three faces, and hit testing it is the
	# same question as "which cube did the thumb land on".
	_faces.append([_face(v, "hex"), c])


func _face(v: Vector3, which: String) -> PackedVector2Array:
	var p := func(dx: float, dy: float, dz: float) -> Vector2:
		return _project(v + Vector3(dx, dy, dz))
	match which:
		"top":
			return PackedVector2Array([p.call(0, 1, 0), p.call(1, 1, 0),
					p.call(1, 1, 1), p.call(0, 1, 1)])
		"left":
			return PackedVector2Array([p.call(0, 1, 1), p.call(1, 1, 1),
					p.call(1, 0, 1), p.call(0, 0, 1)])
		"right":
			return PackedVector2Array([p.call(1, 1, 1), p.call(1, 1, 0),
					p.call(1, 0, 0), p.call(1, 0, 1)])
		_:
			return PackedVector2Array([p.call(0, 1, 0), p.call(1, 1, 0),
					p.call(1, 1, 1), p.call(1, 0, 1), p.call(1, 0, 0),
					p.call(0, 0, 1)])


## Front-most first, which is the reverse of the order they were drawn in.
func _at(pos: Vector2) -> Vector3i:
	for i in range(_faces.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(pos, _faces[i][0]):
			return _faces[i][1]
	return Vector3i(-1, -1, -1)


func _gui_input(event: InputEvent) -> void:
	if puzzle == null:
		return
	if event is InputEventMouseMotion:
		var found := _at(event.position)
		if found != _hover:
			_hover = found
			queue_redraw()
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var cell := _at(event.position)
	if cell.x < 0:
		return
	accept_event()
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		cube_marked.emit(cell)
	else:
		cube_picked.emit(cell)
	queue_redraw()
