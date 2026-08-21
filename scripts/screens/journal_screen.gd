extends AppScreen
## One destination, everything about it: what you have found there, what is left
## to solve, and the letter that arrived with its postcard.
##
## This used to be two screens — a city page you played from and a journal you
## read from — showing the same eight tiles with the same pictures and names.
## Two near-identical pages make a player wonder which one they are on.

var city_id: String


func build() -> void:
	city_id = args.get("city", GameData.current_city_id())
	var city := GameData.city(city_id)
	var progress := GameData.city_progress(city_id)
	var complete := GameData.is_city_complete(city_id)

	var body := scaffold(str(GameData.text(city["name"])))
	body.add_child(_city_switcher())

	# A fixed-width progress bar plus buttons in one row has a minimum width that
	# a phone cannot honour, and a container that cannot shrink simply overflows
	# — which is what was clipping every tile on the right. Stack it instead.
	var narrow := is_narrow()
	var head: BoxContainer = UI.vbox(10) if narrow else UI.hbox(16)

	var stat := UI.hbox(12)
	stat.add_child(UI.label(tr("%d / %d discoveries") % [progress.x, progress.y],
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
		var next_id := GameData.next_city_id(city_id)
		if next_id != "":
			var onward := UI.button(tr("Travel to %s") % GameData.text(GameData.city(next_id)["name"]), true)
			onward.pressed.connect(func(): go("journal", {"city": next_id}))
			actions.add_child(onward)
	elif GameData.is_city_written(city_id):
		var next_puzzle := GameData.next_puzzle_for(city_id)
		var play := UI.button(tr("Puzzle %d") % (int(next_puzzle["index"]) + 1), true)
		play.pressed.connect(func(): go("puzzle", {"puzzle": next_puzzle["id"]}))
		actions.add_child(play)
	else:
		actions.add_child(UI.label(tr("Still being written"), UI.BODY, "ink_faint"))
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

	var letter := _letter_panel(city)
	if letter != null:
		body.add_child(UI.spacer(6))
		body.add_child(letter)


## Jump between destinations without going back out to the map.
func _city_switcher() -> Control:
	# Only this city's season. Ten destinations in one row is wider than a
	# phone, and a container is never narrower than its contents — the row
	# would quietly stretch the whole page past the edge of the screen.
	var season := GameData.season_of(city_id)
	var ids: Array = season.get("cities", GameData.city_ids())
	var here := str(season.get("id", ""))

	# Scoping the row to one season stopped it overflowing a phone, and left no
	# way out of the season you were in. The way out is a season above it.
	var stack := UI.vbox(8)
	if GameData.seasons.size() > 1:
		var chips: Array = []
		for entry in GameData.seasons:
			var sid := str(entry.get("id", ""))
			var b := UI.button(GameData.text(entry.get("title", "")), sid == here)
			if sid != here:
				var first := str((entry.get("cities", []) as Array)[0])
				b.pressed.connect(func(): go("journal", {"city": first}))
			chips.append(b)
		stack.add_child(UI.chip_rows(chips,
				chips.size() if not is_narrow() else 2))

	var row := UI.hbox(6)
	for cid in ids:
		var c := GameData.city(str(cid))
		if c.is_empty():
			continue
		var id: String = c["id"]
		var unlocked := GameData.is_city_unlocked(id)
		var b := UI.button(GameData.text(c["name"]), id == city_id)
		b.disabled = not unlocked
		b.tooltip_text = GameData.text(c["name"])
		if unlocked:
			b.pressed.connect(func(): go("journal", {"city": id}))
		row.add_child(b)
	stack.add_child(row)
	return stack


## The letter that came with this city's postcard, once it has been earned.
func _letter_panel(city: Dictionary) -> Control:
	# The letter arrives with the postcard, so it stays sealed until the city is
	# finished — otherwise the ending is sitting on the page from the first move.
	if not SaveGame.has_postcard(city_id):
		return null
	var letter: Dictionary = city.get("letter", {})
	if GameData.text(letter.get("body", "")) == "":
		return null
	var panel := UI.panel(12)
	var v := UI.vbox(8)
	# The drawn stamp used to sit on a card on the map, five at a time, mostly
	# as texture. One city has room for it to be read, and next to the letter it
	# is doing what a stamp does: saying where the thing came from.
	var narrow := is_narrow()
	var stamp := StampView.new()
	stamp.setup(city_id, -0.14 + 0.08 * float(int(city["order"]) % 3))
	stamp.custom_minimum_size = Vector2(150, 96) if not narrow else Vector2(140, 88)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if narrow:
		stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(stamp)
		panel.add_child(v)
	else:
		var spread := UI.hbox(16)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spread.add_child(v)
		spread.add_child(stamp)
		panel.add_child(spread)
	v.add_child(UI.label_small(GameData.text(letter.get("title", "")), "accent"))
	v.add_child(UI.paragraph(GameData.text(letter["body"]), UI.BODY, "ink"))
	var row := UI.hbox(8)
	var open := UI.button(tr("Postcard"))
	open.pressed.connect(func(): go("postcards", {"card": city_id}))
	row.add_child(open)
	var send := UI.button(tr("Send to a friend"), true)
	send.pressed.connect(func(): go("share", {"city": city_id}))
	row.add_child(send)
	v.add_child(row)
	return panel


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
	# No outline: the fill and the space around it separate one tile from the
	# next. An outline on every tile turned the page into a spreadsheet.
	sb.border_color = Pal.c("accent")
	sb.set_border_width_all(1 if (unlocked and not solved) else 0)
	sb.set_corner_radius_all(3)
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

	var caption: String = GameData.text(p["name"]) if solved else ("Puzzle %d" % (int(p["index"]) + 1))
	v.add_child(UI.label(caption, UI.SMALL, "ink" if solved else "ink_soft",
			HORIZONTAL_ALIGNMENT_CENTER))

	# Width first, the way everyone says a grid size out loud.
	var sub := "%d × %d" % [String(p["art"][0]).length(), p["art"].size()]
	if not unlocked and not solved:
		sub = "locked"
	v.add_child(UI.label(sub, UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER))

	var pid: String = p["id"]
	card.pressed.connect(func(): go("puzzle", {"puzzle": pid}))
	return card
