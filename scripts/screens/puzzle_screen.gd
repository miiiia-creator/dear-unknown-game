extends AppScreen
## The core loop: solve the grid, then the picture resolves into a discovery.

var puzzle_data: Dictionary
var city: Dictionary
var board: BoardView
var _ink_buttons: Array[Button] = []
var nono: Nonogram

var _elapsed := 0.0
var _running := true
var _timer_label: Label
var _fill_button: Button
var _mark_button: Button
var _undo_button: Button
var _overlay: Control
var _dirty := false
var _save_countdown := 0.0


func build() -> void:
	puzzle_data = GameData.puzzle(args.get("puzzle", ""))
	if puzzle_data.is_empty():
		go("menu")
		return
	city = GameData.city(puzzle_data["city_id"])
	nono = Nonogram.new(puzzle_data["art"])

	# Pick up a board left half-finished in an earlier session.
	var saved := SaveGame.load_progress(puzzle_data["id"])
	if not saved.is_empty() and nono.apply_flat(str(saved.get("grid", ""))):
		_elapsed = float(saved.get("time", 0.0))
		nono.hints_used = int(saved.get("hints", 0))

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28
	root.offset_right = -28
	root.offset_top = 20
	root.offset_bottom = -20
	add_child(root)

	root.add_child(_top_bar())
	root.add_child(UI.spacer(6))
	root.add_child(UI.hrule())

	board = BoardView.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.crosshair = true
	board.mark_done = bool(SaveGame.setting("mark_done", true))
	# The grid's own inks. Empty for every black-and-white puzzle, which is
	# every puzzle until Season Two.
	var palette: Array = []
	for hex in puzzle_data.get("palette", []):
		palette.append(Color(str(hex)))
	board.puzzle_palette = palette
	board.setup(nono)
	board.changed.connect(_on_changed)
	board.solved.connect(_on_solved)
	root.add_child(board)

	root.add_child(UI.hrule())
	root.add_child(UI.spacer(8))
	root.add_child(_tool_bar())
	_refresh_buttons()


func parent_args() -> Dictionary:
	return {"city": city.get("id", "")}


func _top_bar() -> Control:
	var bar := UI.hbox(14)

	# Back to the card, which is where this grid was picked — and where solving
	# it lights the next point. `back()` rather than a route of its own, so the
	# link and the escape key cannot drift apart again.
	var back_btn := UI.quiet_button("%s" % GameData.text(city["name"]), UI.SMALL)
	back_btn.pressed.connect(back)
	bar.add_child(back_btn)

	var solved := SaveGame.is_solved(puzzle_data["id"])
	var title: String = GameData.text(puzzle_data["name"]) if solved else "Puzzle %d" % (int(puzzle_data["index"]) + 1)
	bar.add_child(UI.label(title, UI.H3, "ink"))
	# Width first, matching the journal tiles and how a grid size is said aloud.
	bar.add_child(UI.label(tr("·  %d × %d") % [String(puzzle_data["art"][0]).length(),
			puzzle_data["art"].size()], UI.SMALL, "ink_faint"))

	bar.add_child(UI.grow())
	_timer_label = UI.label("0:00", UI.BODY, "ink_soft")
	bar.add_child(_timer_label)
	return bar


func _tool_bar() -> Control:
	var narrow := column_width() < 620.0
	var root := UI.vbox(8)

	# Both tools stay on screen with the active one lit, so there is never a
	# question about which mode you are in. On a phone they get a row of their
	# own and grow to thumb size.
	var tools := UI.hbox(8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	if board.puzzle_palette.size() > 1:
		# With more than one ink, "Fill" is no longer a single thing: the row
		# becomes the palette itself, and Mark keeps its place at the end so the
		# gesture a player already knows does not move.
		for i in board.puzzle_palette.size():
			var swatch := _ink_button(i, narrow)
			_ink_buttons.append(swatch)
			tools.add_child(swatch)
		_mark_button = UI.button(tr("Mark"), false)
		_mark_button.pressed.connect(func(): _set_tool(BoardView.Tool.MARK))
		_mark_button.custom_minimum_size = Vector2(0 if narrow else 96, 46 if narrow else 0)
		tools.add_child(_mark_button)
	else:
		_fill_button = UI.button(tr("Fill"), true)
		_fill_button.pressed.connect(func(): _set_tool(BoardView.Tool.FILL))
		_mark_button = UI.button(tr("Mark"), false)
		_mark_button.pressed.connect(func(): _set_tool(BoardView.Tool.MARK))
		for b in [_fill_button, _mark_button]:
			b.custom_minimum_size = Vector2(0 if narrow else 112, 46 if narrow else 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
			tools.add_child(b)

	if not _ink_buttons.is_empty():
		_set_ink.call_deferred(1)

	var actions := UI.hbox(8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_undo_button = UI.button(tr("Undo"))
	_undo_button.pressed.connect(_undo)
	var reset := UI.button(tr("Reset"))
	reset.pressed.connect(_reset)
	var hint := UI.button(tr("Hint"))
	hint.pressed.connect(_hint)
	for b in [_undo_button, reset, hint]:
		if narrow:
			b.custom_minimum_size = Vector2(0, 42)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)

	if narrow:
		root.add_child(tools)
		root.add_child(actions)
	else:
		var one := UI.hbox(10)
		one.alignment = BoxContainer.ALIGNMENT_CENTER
		one.add_child(tools)
		one.add_child(UI.spacer(0))
		one.add_child(actions)
		one.add_child(UI.spacer(0))
		one.add_child(UI.label(tr("right-click also marks"), UI.SMALL, "ink_faint"))
		root.add_child(one)
	return root


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _timer_label:
		_timer_label.text = "%d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]

	# Debounced autosave, so a hard quit mid-puzzle costs at most a couple of
	# seconds rather than the whole board.
	if _dirty:
		_save_countdown -= delta
		if _save_countdown <= 0.0:
			_flush_progress()


func _flush_progress() -> void:
	_dirty = false
	if nono.is_complete():
		return
	SaveGame.save_progress(puzzle_data["id"], nono.state, _elapsed, nono.hints_used)


func _exit_tree() -> void:
	if _dirty:
		_flush_progress()


# -- actions ---------------------------------------------------------------

func _toggle_tool() -> void:
	_set_tool(BoardView.Tool.MARK if board.tool == BoardView.Tool.FILL
			else BoardView.Tool.FILL)


## One ink in the palette row: a square of the colour itself, because a word
## cannot say which colour it means and the swatch always can.
func _ink_button(index: int, narrow: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(46 if narrow else 52, 46 if narrow else 40)
	var colour: Color = board.puzzle_palette[index]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colour
		sb.set_corner_radius_all(3)
		sb.border_color = Pal.c("ink")
		sb.set_border_width_all(0)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func(): _set_ink(index + 1))
	return b


## Which ink paints, and the border that says so. A ring around the chosen
## swatch rather than a change of fill: the fill is the information.
func _set_ink(value: int) -> void:
	board.ink = value
	board.tool = BoardView.Tool.FILL
	for i in _ink_buttons.size():
		var sb: StyleBoxFlat = _ink_buttons[i].get_theme_stylebox("normal")
		sb.set_border_width_all(3 if i == value - 1 else 0)
	if _mark_button != null:
		UI.restyle_button(_mark_button, false)


func _set_tool(which: int) -> void:
	board.tool = which
	var filling := which == BoardView.Tool.FILL
	if _fill_button != null:
		UI.restyle_button(_fill_button, filling)
	if _mark_button != null:
		UI.restyle_button(_mark_button, not filling)
	if which == BoardView.Tool.MARK:
		for b in _ink_buttons:
			(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(0)


func _undo() -> void:
	if nono.undo():
		Sfx.play("undo")
		board.queue_redraw()
		_refresh_buttons()


func _reset() -> void:
	nono.reset()
	Sfx.play("reset")
	board.queue_redraw()
	_refresh_buttons()


func _hint() -> void:
	var c := nono.take_hint()
	if c.x < 0:
		return
	# A hint writes a cell the same way a click does, so it makes the same noise
	# the player would have made writing it themselves.
	Sfx.play("fill" if nono.get_cell(c.y, c.x) == Nonogram.FILLED else "mark")
	board.flash(c)
	_refresh_buttons()


func _on_changed() -> void:
	_dirty = true
	_save_countdown = 2.0
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _undo_button:
		_undo_button.disabled = not nono.can_undo()


func _input(event: InputEvent) -> void:
	if not _running or _overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_Z:
				_undo()
			KEY_R:
				_reset()
			KEY_H:
				_hint()
			KEY_SPACE, KEY_TAB:
				_toggle_tool()
			_:
				return
		get_viewport().set_input_as_handled()


# -- the reveal ------------------------------------------------------------

func _on_solved() -> void:
	if not _running:
		return
	_running = false

	var first_time := not SaveGame.is_solved(puzzle_data["id"])
	SaveGame.mark_solved(puzzle_data["id"], _elapsed, nono.hints_used)

	# On the last cell rather than on the overlay a second later: the sound
	# belongs to the grid furniture fading out, which is the moment the picture
	# actually arrives.
	Sfx.play("solved")
	var tw := create_tween()
	tw.tween_property(board, "reveal", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.25)
	tw.tween_callback(func(): _show_reveal(first_time))


func _show_reveal(_first_time: bool) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Pal.c("bg")
	scrim.color.a = 0.92
	_overlay.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centre)

	var card := UI.panel(6)
	# A fixed 460 is wider than a phone, and a CenterContainer will not shrink
	# its child — it just lets it hang over the right edge and get clipped.
	card.custom_minimum_size = Vector2(minf(460.0, column_width()), 0)
	centre.add_child(card)

	var v := UI.vbox(6)
	card.add_child(v)

	v.add_child(UI.label(tr("DISCOVERED"), UI.SMALL, "accent",
			HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(6))

	var art := PixelArtView.new()
	art.custom_minimum_size = Vector2(0, 220)
	art.setup(puzzle_data["art"], Pal.c("cell"))
	art.appear = 0.0
	v.add_child(art)
	v.add_child(UI.spacer(8))

	v.add_child(UI.label(str(GameData.text(puzzle_data["name"])), UI.H2, "ink",
			HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(tr("%s · %s, %s") % [GameData.text(puzzle_data["category"]), GameData.text(city["name"]),
			GameData.text(city["country"])], UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(4))
	v.add_child(UI.spacer(6))

	var stat := "%d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]
	if nono.hints_used > 0:
		stat += "  ·  %d hint%s" % [nono.hints_used, "" if nono.hints_used == 1 else "s"]
	else:
		stat += "  ·  no hints"
	v.add_child(UI.label(stat, UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(8))

	var progress := GameData.city_progress(city["id"])
	v.add_child(UI.label(tr("%d of %d in %s") % [progress.x, progress.y,
			GameData.text(city["name"])], UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(10))

	var cont := UI.button(_continue_label(), true)
	cont.custom_minimum_size = Vector2(0, 48)
	cont.pressed.connect(_continue)
	v.add_child(cont)

	_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(art, "appear", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _continue_label() -> String:
	if GameData.is_city_complete(city["id"]):
		return "%s complete" % String(GameData.text(city["name"])).to_upper()
	return "Next puzzle"


func _continue() -> void:
	if GameData.is_city_complete(city["id"]):
		replace("city_complete", {"city": city["id"]})
		return
	# Back to the card rather than straight into the next grid. The picture
	# that was just solved belongs on the card, and watching it land there is
	# the reward for the one before it — going directly to another empty grid
	# skips the only moment that says anything happened.
	replace("card", {"city": city["id"]})
