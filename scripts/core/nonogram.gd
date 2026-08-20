class_name Nonogram
extends RefCounted
## Pure puzzle logic: grid state, clue generation, undo, hints, completion.
## No nodes, no drawing — so it can be unit-tested and reused by the solver.
##
## Cells carry a colour rather than a boolean. A black-and-white puzzle is the
## one-colour case of the same model, which is why nothing here has a branch
## for it: `#` in the art means "colour 1", and a grid whose palette has one
## entry behaves exactly as it always did.
##
## The rule that makes colour puzzles their own thing: two runs of the SAME
## colour need a gap between them, two runs of DIFFERENT colours may touch. The
## solver in tools/build_content.py enforces the same rule, and that is where a
## grid earns its guarantee of a single solution.

## Cell values. Colours are 1..palette.size(); MARKED is negative so it can
## never be mistaken for one.
const EMPTY := 0
const FILLED := 1        ## colour one — what a single-colour puzzle fills with
const MARKED := -1

## Characters the art uses. `#` is sugar for colour one.
const INK := "#"
const BLANK := "."

var width: int = 0
var height: int = 0
var colours: int = 1           ## how many inks this grid uses
var solution: Array = []       ## Array[Array[int]] — 0 empty, 1..n colour
var state: Array = []          ## Array[Array[int]] — same, plus MARKED
var row_clues: Array = []      ## Array[Array[Vector2i]] — (length, colour)
var col_clues: Array = []
var hints_used: int = 0
var moves: int = 0

var _undo_stack: Array = []


func _init(art: Array) -> void:
	height = art.size()
	width = String(art[0]).length()
	for r in height:
		var line: String = art[r]
		var sol_row: Array = []
		var state_row: Array = []
		for col in width:
			var value := value_of(line[col])
			colours = maxi(colours, value)
			sol_row.append(value)
			state_row.append(EMPTY)
		solution.append(sol_row)
		state.append(state_row)

	for r in height:
		row_clues.append(clues_of(solution[r]))
	for col in width:
		var strip: Array = []
		for r in height:
			strip.append(solution[r][col])
		col_clues.append(clues_of(strip))


## One art character to one cell value.
static func value_of(ch: String) -> int:
	if ch == INK:
		return FILLED
	if ch >= "1" and ch <= "9":
		return int(ch)
	return EMPTY


## Runs of a line as (length, colour). Touching runs of different colours are
## separate entries with no gap between them, which is exactly what the player
## has to work out. An empty line reads as one zero so the board can show "0".
static func clues_of(line: Array) -> Array:
	var out: Array = []
	var run := 0
	var colour := EMPTY
	for v in line:
		if v == colour and v != EMPTY:
			run += 1
			continue
		if run > 0:
			out.append(Vector2i(run, colour))
		colour = v
		run = 1 if v != EMPTY else 0
	if run > 0:
		out.append(Vector2i(run, colour))
	if out.is_empty():
		out.append(Vector2i(0, EMPTY))
	return out


func in_bounds(r: int, col: int) -> bool:
	return r >= 0 and r < height and col >= 0 and col < width


func get_cell(r: int, col: int) -> int:
	return state[r][col]


# -- editing ---------------------------------------------------------------

## A stroke groups every cell touched by one click-drag so undo feels natural.
func begin_stroke() -> void:
	_undo_stack.append([])
	if _undo_stack.size() > 200:
		_undo_stack.pop_front()


func set_cell(r: int, col: int, value: int) -> bool:
	if not in_bounds(r, col):
		return false
	var old: int = state[r][col]
	if old == value:
		return false
	if _undo_stack.is_empty():
		begin_stroke()
	_undo_stack[-1].append([r, col, old])
	state[r][col] = value
	moves += 1
	return true


func end_stroke() -> void:
	if not _undo_stack.is_empty() and _undo_stack[-1].is_empty():
		_undo_stack.pop_back()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var stroke: Array = _undo_stack.pop_back()
	for i in range(stroke.size() - 1, -1, -1):
		var e: Array = stroke[i]
		state[e[0]][e[1]] = e[2]
	return true


## Restore a board from SaveGame's flat string. Anything whose length no longer
## matches the puzzle is ignored, so edited art cannot load a stale grid.
##
## Saves written before colour existed used 0/1/2 per cell. They are still read:
## a board someone left half-finished should not be thrown away by a change to
## the file format.
func apply_flat(flat: String) -> bool:
	if flat.length() != width * height:
		return false
	var legacy := true
	for i in flat.length():
		if not flat[i] in ["0", "1", "2"]:
			legacy = false
			break
	for r in height:
		for col in width:
			var ch := flat[r * width + col]
			if legacy:
				state[r][col] = [EMPTY, FILLED, MARKED][int(ch)]
			elif ch == "x":
				state[r][col] = MARKED
			elif ch >= "1" and ch <= "9":
				state[r][col] = int(ch)
			else:
				state[r][col] = EMPTY
	_undo_stack.clear()
	return true


func to_flat() -> String:
	var out := ""
	for r in height:
		for col in width:
			var v: int = state[r][col]
			if v == MARKED:
				out += "x"
			elif v > 0:
				out += str(v)
			else:
				out += BLANK
	return out


func reset() -> void:
	for r in height:
		for col in width:
			state[r][col] = EMPTY
	_undo_stack.clear()
	moves = 0


# -- hints and completion --------------------------------------------------

## Reveal one true cell the player has not got right yet. Prefers cells in the
## most-constrained (fewest remaining unknowns) line so the hint opens up work.
func take_hint() -> Vector2i:
	var candidates: Array = []
	for r in height:
		for col in width:
			var want: int = solution[r][col] if solution[r][col] != EMPTY else MARKED
			if state[r][col] != want:
				candidates.append(Vector2i(col, r))
	if candidates.is_empty():
		return Vector2i(-1, -1)

	var best: Vector2i = candidates[0]
	var best_score := 999
	for p in candidates:
		var unknown := 0
		for col in width:
			if state[p.y][col] == EMPTY:
				unknown += 1
		for r in height:
			if state[r][p.x] == EMPTY:
				unknown += 1
		if unknown < best_score:
			best_score = unknown
			best = p

	var truth: int = solution[best.y][best.x]
	begin_stroke()
	set_cell(best.y, best.x, truth if truth != EMPTY else MARKED)
	end_stroke()
	hints_used += 1
	return best


## Marking a cell is a note to yourself, so it counts as leaving it empty.
func is_complete() -> bool:
	for r in height:
		for col in width:
			var placed: int = state[r][col]
			if placed == MARKED:
				placed = EMPTY
			if placed != solution[r][col]:
				return false
	return true


func filled_count() -> int:
	var n := 0
	for r in height:
		for col in width:
			if state[r][col] > 0:
				n += 1
	return n


## The number of cells the finished picture fills, whatever colour they are.
func total_filled() -> int:
	var n := 0
	for r in height:
		for col in width:
			if solution[r][col] != EMPTY:
				n += 1
	return n


## True when a line's runs exactly match its clues, colours included.
##
## This is a *local* check: the line satisfies its own numbers. It can still sit
## in the wrong place relative to the columns, which is why crossing off a
## satisfied line is a hint and not a guarantee — the same convention every
## paper nonogram uses.
func row_satisfied(r: int) -> bool:
	var line: Array = []
	for col in width:
		line.append(_placed(r, col))
	return clues_of(line) == row_clues[r]


func col_satisfied(col: int) -> bool:
	var line: Array = []
	for r in height:
		line.append(_placed(r, col))
	return clues_of(line) == col_clues[col]


## Every cell that contradicts the solution — used only by the "check" nudge.
## A cell of the wrong colour is as much a mistake as a cell that should be
## blank, which is new: black and white only ever had the one way to be wrong.
func mistakes() -> Array:
	var out: Array = []
	for r in height:
		for col in width:
			var placed := _placed(r, col)
			if placed != EMPTY and placed != solution[r][col]:
				out.append(Vector2i(col, r))
	return out


## What the player has actually put in a cell, with a mark counting as nothing.
func _placed(r: int, col: int) -> int:
	var v: int = state[r][col]
	return EMPTY if v == MARKED else v
