class_name BoardView
extends Control
## The puzzle grid. Everything is drawn in `_draw` rather than built from child
## nodes — one control means crisp square cells at any window size and no
## layout churn on a 15x15 board.

signal changed
signal solved

const CLUE_SCALE := 0.66     ## clue column width as a fraction of a cell
const PAD := 10.0

enum Tool { FILL, MARK }

var puzzle: Nonogram
var tool: int = Tool.FILL
var crosshair := true
## Cross off a row or column once its filled runs match its numbers.
var mark_done := true
## 0 = normal play, 1 = fully revealed picture (grid furniture faded out).
var reveal := 0.0:
	set(value):
		reveal = value
		queue_redraw()

var _cell := 24.0
var _origin := Vector2.ZERO       ## top-left of the cell area
## Colours for this grid, set by the puzzle screen. Empty means one ink.
var puzzle_palette: Array = []

var _gutter := Vector2.ZERO       ## left / top clue gutter sizes
var _hover := Vector2i(-1, -1)
var _painting := false
var _paint_value := 0
var _last_painted := Vector2i(-1, -1)


func setup(p: Nonogram) -> void:
	puzzle = p
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


# -- geometry --------------------------------------------------------------

func _measure() -> void:
	var max_row_clues := 1
	for c in puzzle.row_clues:
		max_row_clues = maxi(max_row_clues, c.size())
	var max_col_clues := 1
	for c in puzzle.col_clues:
		max_col_clues = maxi(max_col_clues, c.size())

	var cols_total: float = puzzle.width + max_row_clues * CLUE_SCALE
	var rows_total: float = puzzle.height + max_col_clues * CLUE_SCALE
	_cell = floorf(minf((size.x - PAD * 2) / cols_total, (size.y - PAD * 2) / rows_total))
	_cell = maxf(_cell, 8.0)

	_gutter = Vector2(max_row_clues * CLUE_SCALE * _cell, max_col_clues * CLUE_SCALE * _cell)
	var board := Vector2(puzzle.width * _cell, puzzle.height * _cell) + _gutter
	_origin = ((size - board) * 0.5).floor() + _gutter


func cell_at(pos: Vector2) -> Vector2i:
	var local := pos - _origin
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c := Vector2i(int(local.x / _cell), int(local.y / _cell))
	if c.x >= puzzle.width or c.y >= puzzle.height:
		return Vector2i(-1, -1)
	return c


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c.x, c.y) * _cell, Vector2(_cell, _cell))


# -- drawing ---------------------------------------------------------------

func _draw() -> void:
	if puzzle == null:
		return
	_measure()

	var furniture := 1.0 - reveal
	var grid_area := Rect2(_origin, Vector2(puzzle.width, puzzle.height) * _cell)

	# Board backdrop.
	draw_rect(grid_area.grow(4.0), Pal.c("panel"))

	if crosshair and furniture > 0.0 and _hover.x >= 0:
		var tint := Pal.c("accent")
		tint.a = 0.07 * furniture
		draw_rect(Rect2(_origin.x - _gutter.x, _origin.y + _hover.y * _cell,
				_gutter.x + puzzle.width * _cell, _cell), tint)
		draw_rect(Rect2(_origin.x + _hover.x * _cell, _origin.y - _gutter.y,
				_cell, _gutter.y + puzzle.height * _cell), tint)

	_draw_cells(furniture)
	if furniture > 0.0:
		_draw_grid(furniture)
		_draw_clues(furniture)


func _draw_cells(furniture: float) -> void:
	var fill_color := Pal.c("cell")
	var mark_color := Pal.c("ink_faint")
	mark_color.a = furniture
	var inset := 1.0 if reveal < 0.5 else 0.0

	for r in puzzle.height:
		for c in puzzle.width:
			var st: int = puzzle.state[r][c]
			var rect := cell_rect(Vector2i(c, r))
			if st == Nonogram.FILLED:
				draw_rect(rect.grow(-inset), fill_color)
			elif st == Nonogram.MARKED and furniture > 0.0:
				var m := rect.grow(-_cell * 0.32)
				var wdt := maxf(1.5, _cell * 0.08)
				draw_line(m.position, m.position + m.size, mark_color, wdt, true)
				draw_line(Vector2(m.position.x + m.size.x, m.position.y),
						Vector2(m.position.x, m.position.y + m.size.y), mark_color, wdt, true)


func _draw_grid(furniture: float) -> void:
	var thin := Pal.c("line")
	var thick := Pal.c("line_strong")
	thin.a = furniture
	thick.a = furniture

	for c in range(puzzle.width + 1):
		var x := _origin.x + c * _cell
		var major := c % 5 == 0 or c == puzzle.width
		draw_line(Vector2(x, _origin.y - (_gutter.y if major else 0.0)),
				Vector2(x, _origin.y + puzzle.height * _cell),
				thick if major else thin, 2.0 if major else 1.0)
	for r in range(puzzle.height + 1):
		var y := _origin.y + r * _cell
		var major := r % 5 == 0 or r == puzzle.height
		draw_line(Vector2(_origin.x - (_gutter.x if major else 0.0), y),
				Vector2(_origin.x + puzzle.width * _cell, y),
				thick if major else thin, 2.0 if major else 1.0)


## A clue is a run length and the colour of that run. Until the palettes exist
## every run is colour one and the numbers are drawn in ink, exactly as before;
## the colour is read here so that the day a grid has two, nothing else has to
## change.
func _clue_colour(entry: Vector2i, base: Color) -> Color:
	if puzzle.colours <= 1 or entry.y <= 0:
		return base
	var palette: Array = puzzle_palette
	if entry.y - 1 < palette.size():
		var c: Color = palette[entry.y - 1]
		c.a = base.a
		return c
	return base


func _draw_clues(furniture: float) -> void:
	var font: Font = Pal.mono_font
	var fsize := int(maxf(9.0, _cell * 0.46))
	var slot := _cell * CLUE_SCALE

	for r in puzzle.height:
		var list: Array = puzzle.row_clues[r]
		var done := mark_done and puzzle.row_satisfied(r)
		var left := _origin.x - list.size() * slot
		var baseline := _origin.y + r * _cell + _cell * 0.72
		for i in list.size():
			var col := Pal.c("ink_faint") if done else Pal.c("ink_soft")
			if _hover.y == r and not done:
				col = Pal.c("ink")
			col.a = furniture
			var entry: Vector2i = list[i]
			col = _clue_colour(entry, col)
			var text := str(entry.x)
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			var slot_right := _origin.x - (list.size() - 1 - i) * slot - slot * 0.25
			draw_string(font, Vector2(slot_right - tw, baseline),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		if done:
			var strike := Pal.c("ink_faint")
			strike.a = 0.75 * furniture
			var y := baseline - fsize * 0.32
			draw_line(Vector2(left + slot * 0.1, y), Vector2(_origin.x - slot * 0.15, y),
					strike, maxf(1.0, _cell * 0.045), true)

	for c in puzzle.width:
		var list: Array = puzzle.col_clues[c]
		var done := mark_done and puzzle.col_satisfied(c)
		var top := _origin.y - list.size() * slot
		var centre_x := _origin.x + c * _cell + _cell * 0.5
		for i in list.size():
			var col := Pal.c("ink_faint") if done else Pal.c("ink_soft")
			if _hover.x == c and not done:
				col = Pal.c("ink")
			col.a = furniture
			var entry: Vector2i = list[i]
			col = _clue_colour(entry, col)
			var text := str(entry.x)
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			var y := _origin.y - (list.size() - 1 - i) * slot - slot * 0.25
			draw_string(font, Vector2(centre_x - tw * 0.5, y),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		if done:
			var strike := Pal.c("ink_faint")
			strike.a = 0.75 * furniture
			draw_line(Vector2(centre_x, top + slot * 0.15),
					Vector2(centre_x, _origin.y - slot * 0.1),
					strike, maxf(1.0, _cell * 0.045), true)


# -- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if puzzle == null or reveal > 0.0:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mb.pressed:
			var c := cell_at(mb.position)
			if c.x < 0:
				return
			var want := _target_state(mb.button_index == MOUSE_BUTTON_RIGHT)
			_paint_value = Nonogram.EMPTY if puzzle.state[c.y][c.x] == want else want
			_painting = true
			_last_painted = Vector2i(-1, -1)
			puzzle.begin_stroke()
			_apply(c)
			accept_event()
		else:
			if _painting:
				_painting = false
				puzzle.end_stroke()
				_check_solved()
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var c := cell_at(mm.position)
		if c != _hover:
			_hover = c
			queue_redraw()
		if _painting and c.x >= 0:
			_apply(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover.x >= 0:
		_hover = Vector2i(-1, -1)
		queue_redraw()


func _target_state(secondary: bool) -> int:
	var use_mark := (tool == Tool.MARK) != secondary
	return Nonogram.MARKED if use_mark else Nonogram.FILLED


func _apply(c: Vector2i) -> void:
	if c == _last_painted:
		return
	_last_painted = c
	var row_was := puzzle.row_satisfied(c.y)
	var col_was := puzzle.col_satisfied(c.x)
	if not puzzle.set_cell(c.y, c.x, _paint_value):
		return
	Sfx.play("fill" if _paint_value == Nonogram.FILLED else "mark")
	# The line confirmation is the audible half of the cross-off, and it says
	# exactly what the strike through the numbers says. So it follows the same
	# setting: a player who turned the cross-off off for a stricter puzzle has
	# not agreed to be told the same thing through the speakers. Suppressed on
	# the final cell too, where the solve sound is a moment away.
	if mark_done and not puzzle.is_complete() \
			and ((not row_was and puzzle.row_satisfied(c.y))
			or (not col_was and puzzle.col_satisfied(c.x))):
		Sfx.play("line")
	changed.emit()
	queue_redraw()


func _check_solved() -> void:
	if puzzle.is_complete():
		solved.emit()


## Used by the hint button so the revealed cell gets a moment of attention.
func flash(c: Vector2i) -> void:
	queue_redraw()
	var glow := ColorRect.new()
	glow.color = Pal.c("accent")
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_measure()
	var rect := cell_rect(c)
	glow.position = rect.position
	glow.size = rect.size
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, 0.7).from(0.8)
	tw.tween_callback(glow.queue_free)
	_check_solved()
