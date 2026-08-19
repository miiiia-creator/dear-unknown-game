class_name Nonogram
extends RefCounted
## Pure puzzle logic: grid state, clue generation, undo, hints, completion.
## No nodes, no drawing — so it can be unit-tested and reused by the solver.

enum { EMPTY, FILLED, MARKED }

var width: int = 0
var height: int = 0
var solution: Array = []      ## Array[Array[int]] — 1 filled, 0 blank
var state: Array = []          ## Array[Array[int]] — EMPTY / FILLED / MARKED
var row_clues: Array = []      ## Array[Array[int]]
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
			sol_row.append(1 if line[col] == "#" else 0)
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


## Run-lengths of a 0/1 line. An empty line reads as [0] so the UI can show "0".
static func clues_of(line: Array) -> Array:
	var out: Array = []
	var run := 0
	for v in line:
		if v == 1:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	if out.is_empty():
		out.append(0)
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


## Restore a board from SaveGame's flat digit string. Ignores anything whose
## length no longer matches the puzzle, so edited art cannot load a stale grid.
func apply_flat(flat: String) -> bool:
	if flat.length() != width * height:
		return false
	for r in height:
		for col in width:
			var digit := flat[r * width + col]
			state[r][col] = int(digit) if digit in ["0", "1", "2"] else EMPTY
	_undo_stack.clear()
	return true


func to_flat() -> String:
	var out := ""
	for r in height:
		for col in width:
			out += str(state[r][col])
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
			var want: int = FILLED if solution[r][col] == 1 else MARKED
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

	begin_stroke()
	set_cell(best.y, best.x, FILLED if solution[best.y][best.x] == 1 else MARKED)
	end_stroke()
	hints_used += 1
	return best


func is_complete() -> bool:
	for r in height:
		for col in width:
			var filled: bool = state[r][col] == FILLED
			if filled != (solution[r][col] == 1):
				return false
	return true


func filled_count() -> int:
	var n := 0
	for r in height:
		for col in width:
			if state[r][col] == FILLED:
				n += 1
	return n


func total_filled() -> int:
	var n := 0
	for r in height:
		for col in width:
			n += solution[r][col]
	return n


## True when a line's filled runs exactly match its clues.
##
## This is a *local* check: the line satisfies its own numbers. It can still sit
## in the wrong place relative to the columns, which is why crossing off a
## satisfied line is a hint and not a guarantee — the same convention every
## paper nonogram uses.
func row_satisfied(r: int) -> bool:
	var line: Array = []
	for col in width:
		line.append(1 if state[r][col] == FILLED else 0)
	return clues_of(line) == row_clues[r]


func col_satisfied(col: int) -> bool:
	var line: Array = []
	for r in height:
		line.append(1 if state[r][col] == FILLED else 0)
	return clues_of(line) == col_clues[col]


## Every cell that contradicts the solution — used only by the "check" nudge.
func mistakes() -> Array:
	var out: Array = []
	for r in height:
		for col in width:
			if state[r][col] == FILLED and solution[r][col] == 0:
				out.append(Vector2i(col, r))
	return out
