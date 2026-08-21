class_name Solid
extends RefCounted
## A block of cubes with something inside it, and the clues that say what.
##
## Season Three's question was whether depth can change the *reasoning* rather
## than just the picture. Reading a colour grid as a relief does not: the board,
## the clues and the deductions are identical to Season Two's, and only the
## reward moves. Reasoning becomes three-dimensional when the clues do — when a
## line you are looking along is constrained from two other directions as well.
##
## The notation is Picross 3D's, and the reason to borrow it is that it is the
## only one that fits on a phone. A run-sequence clue on three faces would be
## three times the numbers a 15x20 grid already struggles to show. Here a line
## carries **one** number — how many cubes of it survive — plus a mark when
## those cubes are not all in one piece:
##
##   plain   one run          ###..   or   ..###
##   ring    two runs         ##.#.
##   square  three or more    #.#.#
##
## That is the whole language, and it is enough: a five-long line holding three
## cubes in two pieces has only three arrangements, and the other two axes are
## saying the same kind of thing about every cube in it.

## What the player has decided about a cube.
enum { UNKNOWN, KEPT, GONE }

const N := 5

var size := Vector3i(N, N, N)
## Both are [y][z][x] — a stack of layers, each a grid of rows, which is how
## the source literal reads and so the one order worth having.
var solution: Array = []
var state: Array = []
var mistakes := 0


func _init(layers: Array = []) -> void:
	if layers.is_empty():
		return
	size = Vector3i(String(layers[0][0]).length(), layers.size(), layers[0].size())
	solution = []
	state = []
	for y in size.y:
		var plane: Array = []
		var blank: Array = []
		for z in size.z:
			var row: Array = []
			var unknown: Array = []
			var line: String = layers[y][z]
			for x in size.x:
				row.append(line[x] != ".")
				unknown.append(UNKNOWN)
			plane.append(row)
			blank.append(unknown)
		solution.append(plane)
		state.append(blank)


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < size.x and c.y >= 0 and c.y < size.y \
			and c.z >= 0 and c.z < size.z


## `y` is up, `z` runs back into the picture, `x` across it.
func solid_at(c: Vector3i) -> bool:
	return inside(c) and solution[c.y][c.z][c.x]


func state_at(c: Vector3i) -> int:
	return state[c.y][c.z][c.x] if inside(c) else GONE


func set_state(c: Vector3i, value: int) -> void:
	if inside(c):
		state[c.y][c.z][c.x] = value


## Still in the block: not yet chiselled away.
func present(c: Vector3i) -> bool:
	return inside(c) and state_at(c) != GONE


## Chisel. Taking away a cube that belongs to the shape is the one way to be
## wrong, and being wrong keeps the cube — the shape cannot be damaged, only
## the record of how cleanly it was found.
func chisel(c: Vector3i) -> bool:
	if not present(c) or state_at(c) == KEPT:
		return false
	if solid_at(c):
		mistakes += 1
		set_state(c, KEPT)
		return false
	set_state(c, GONE)
	return true


## Mark a cube as one to keep. Wrong here costs nothing but the mark: it is a
## note to yourself, and the shape is not touched either way.
func mark(c: Vector3i) -> bool:
	if not present(c):
		return false
	set_state(c, UNKNOWN if state_at(c) == KEPT else KEPT)
	return true


func solved() -> bool:
	for y in size.y:
		for z in size.z:
			for x in size.x:
				var c := Vector3i(x, y, z)
				if solid_at(c) != present(c):
					return false
	return true


# -- clues -----------------------------------------------------------------

## The cells of one line, from a face inwards. `axis` 0 runs along x, 1 along y,
## 2 along z; `a` and `b` index the other two.
func line(axis: int, a: int, b: int) -> Array:
	var cells: Array = []
	var length: int = [size.x, size.y, size.z][axis]
	for i in length:
		match axis:
			0: cells.append(Vector3i(i, a, b))
			1: cells.append(Vector3i(a, i, b))
			_: cells.append(Vector3i(a, b, i))
	return cells


## How many cubes of a line survive, and in how many pieces.
func clue(axis: int, a: int, b: int) -> Vector2i:
	var count := 0
	var runs := 0
	var was := false
	for c in line(axis, a, b):
		var here := solid_at(c)
		if here:
			count += 1
			if not was:
				runs += 1
		was = here
	return Vector2i(count, runs)
