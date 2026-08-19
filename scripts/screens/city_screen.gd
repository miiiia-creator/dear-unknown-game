extends AppScreen
## One destination: its discoveries as a grid of tiles, plus the next puzzle.

var city_id: String


func build() -> void:
	city_id = args.get("city", GameData.first_city_id())
	var city := GameData.city(city_id)
	var progress := GameData.city_progress(city_id)
	var complete := GameData.is_city_complete(city_id)

	var body := scaffold("%s  %s" % [city["flag"], city["name"]], city["tagline"])

	# A fixed-width progress bar plus buttons in one row has a minimum width that
	# a phone cannot honour, and a container that cannot shrink simply overflows
	# — which is what was clipping every tile on the right. Stack it instead.
	var narrow := is_narrow()
	var head: BoxContainer = UI.vbox(10) if narrow else UI.hbox(16)

	var stat := UI.hbox(12)
	stat.add_child(UI.label("%d / %d discoveries" % [progress.x, progress.y],
			UI.BODY, "ink_soft"))
	stat.add_child(UI.progress_bar(float(progress.x) / maxf(1.0, progress.y),
			column_width() * (0.42 if narrow else 0.26), 6))
	head.add_child(stat)
	if not narrow:
		head.add_child(UI.grow())

	var actions: BoxContainer = UI.hbox(8)
	if narrow:
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(actions)

	if complete:
		var view_card := UI.button("📮  View Postcard", true)
		view_card.pressed.connect(func(): go("postcards", {"city": city_id}))
		actions.add_child(view_card)
		var next_id := GameData.next_city_id(city_id)
		if next_id != "":
			var onward := UI.button("Travel to %s  →" % GameData.city(next_id)["name"])
			onward.pressed.connect(func(): go("city", {"city": next_id}))
			actions.add_child(onward)
	else:
		var next_puzzle := GameData.next_puzzle_for(city_id)
		var play := UI.button("▶  Puzzle %d" % (int(next_puzzle["index"]) + 1), true)
		play.pressed.connect(func(): go("puzzle", {"puzzle": next_puzzle["id"]}))
		actions.add_child(play)
	if narrow:
		for b in actions.get_children():
			(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(head)
	body.add_child(UI.spacer(2))

	var grid := GridContainer.new()
	grid.columns = columns_for(170)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)

	var accent: Color = GameData.city_palette(city_id)[1]
	for p in GameData.puzzles_of(city_id):
		grid.add_child(_tile(p, accent))


func _tile(p: Dictionary, accent: Color) -> Control:
	var solved := SaveGame.is_solved(p["id"])
	var unlocked := GameData.is_puzzle_unlocked(p["id"])

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 132 if is_narrow() else 168)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not unlocked and not solved

	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.c("panel") if (solved or unlocked) else Pal.c("panel_alt")
	sb.border_color = Pal.c("accent") if (unlocked and not solved) else Pal.c("line")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	for s in ["normal", "disabled"]:
		card.add_theme_stylebox_override(s, sb)
	var hover := sb.duplicate()
	hover.border_color = Pal.c("accent")
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)

	var v := UI.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var art := PixelArtView.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.setup(p["art"], Pal.c("cell") if solved else accent, not solved)
	v.add_child(art)

	var caption: String = p["name"] if solved else ("Puzzle %d" % (int(p["index"]) + 1))
	v.add_child(UI.label(caption, UI.SMALL, "ink" if solved else "ink_soft",
			HORIZONTAL_ALIGNMENT_CENTER))

	var sub := "%d × %d" % [p["art"].size(), String(p["art"][0]).length()]
	if not unlocked and not solved:
		sub = "🔒 locked"
	v.add_child(UI.label(sub, UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER))

	var pid: String = p["id"]
	card.pressed.connect(func(): go("puzzle", {"puzzle": pid}))
	return card
