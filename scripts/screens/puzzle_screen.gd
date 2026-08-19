extends AppScreen
## The core loop: solve the grid, then the picture resolves into a discovery.

var puzzle_data: Dictionary
var city: Dictionary
var board: BoardView
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
	board.crosshair = bool(SaveGame.setting("cross_hair", true))
	board.mark_done = bool(SaveGame.setting("mark_done", true))
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

	var back_btn := UI.quiet_button("←  %s" % city["name"], UI.SMALL)
	back_btn.pressed.connect(func(): go("city", {"city": city["id"]}))
	bar.add_child(back_btn)

	var solved := SaveGame.is_solved(puzzle_data["id"])
	var title: String = puzzle_data["name"] if solved else "Puzzle %d" % (int(puzzle_data["index"]) + 1)
	bar.add_child(UI.label(title, UI.H3, "ink"))
	bar.add_child(UI.label("·  %d × %d" % [puzzle_data["art"].size(),
			String(puzzle_data["art"][0]).length()], UI.SMALL, "ink_faint"))

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
	_fill_button = UI.button("■  Fill", true)
	_fill_button.pressed.connect(func(): _set_tool(BoardView.Tool.FILL))
	_mark_button = UI.button("✕  Mark", false)
	_mark_button.pressed.connect(func(): _set_tool(BoardView.Tool.MARK))
	for b in [_fill_button, _mark_button]:
		b.custom_minimum_size = Vector2(0 if narrow else 112, 46 if narrow else 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
		tools.add_child(b)

	var actions := UI.hbox(8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_undo_button = UI.button("↶  Undo")
	_undo_button.pressed.connect(_undo)
	var reset := UI.button("↺  Reset")
	reset.pressed.connect(_reset)
	var hint := UI.button("💡  Hint")
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
		one.add_child(UI.label("right-click also marks ✕", UI.SMALL, "ink_faint"))
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


func _set_tool(which: int) -> void:
	board.tool = which
	var filling := which == BoardView.Tool.FILL
	UI.restyle_button(_fill_button, filling)
	UI.restyle_button(_mark_button, not filling)


func _undo() -> void:
	if nono.undo():
		board.queue_redraw()
		_refresh_buttons()


func _reset() -> void:
	nono.reset()
	board.queue_redraw()
	_refresh_buttons()


func _hint() -> void:
	var c := nono.take_hint()
	if c.x < 0:
		return
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
	if nono.hints_used == 0 and puzzle_data["art"].size() >= 15:
		SaveGame.unlock("unaided")
	SaveGame.check_achievements()

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

	var card := UI.panel(18)
	card.custom_minimum_size = Vector2(460, 0)
	centre.add_child(card)

	var v := UI.vbox(6)
	card.add_child(v)

	v.add_child(UI.label("📸  DISCOVERED", UI.SMALL, "accent",
			HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(6))

	var art := PixelArtView.new()
	art.custom_minimum_size = Vector2(0, 220)
	art.setup(puzzle_data["art"], Pal.c("cell"))
	art.appear = 0.0
	v.add_child(art)
	v.add_child(UI.spacer(8))

	v.add_child(UI.label("%s  %s" % [puzzle_data["emoji"], puzzle_data["name"]],
			UI.H2, "ink", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("%s · %s, %s" % [puzzle_data["category"], city["name"],
			city["country"]], UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
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
	v.add_child(UI.label("%s  %d of %d in %s" % [city["flag"], progress.x,
			progress.y, city["name"]], UI.SMALL, "ink_soft",
			HORIZONTAL_ALIGNMENT_CENTER))
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
		return "%s COMPLETE  →" % String(city["name"]).to_upper()
	return "Next puzzle  →"


func _continue() -> void:
	if GameData.is_city_complete(city["id"]):
		replace("city_complete", {"city": city["id"]})
		return
	var next_puzzle := GameData.next_puzzle_for(city["id"])
	if next_puzzle.is_empty():
		replace("city", {"city": city["id"]})
	else:
		replace("puzzle", {"puzzle": next_puzzle["id"]})
