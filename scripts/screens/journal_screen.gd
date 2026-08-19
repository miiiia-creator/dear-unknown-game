extends AppScreen
## Everything discovered so far, grouped by destination.


func build() -> void:
	var body := scaffold("Travel Journal",
			"%d of %d discoveries" % [GameData.discovered_count(),
			GameData.total_puzzle_count()])

	var any := false
	for city in GameData.cities:
		var progress := GameData.city_progress(city["id"])
		if progress.x == 0 and not GameData.is_city_unlocked(city["id"]):
			continue
		any = true
		body.add_child(_city_section(city, progress))

	if not any:
		body.add_child(UI.paragraph("Nothing yet. Solve a puzzle to start the journal.",
				UI.BODY, "ink_soft"))


func _city_section(city: Dictionary, progress: Vector2i) -> Control:
	var section := UI.vbox(8)

	var head := UI.hbox(10)
	head.add_child(UI.label("%s  %s" % [city["flag"], city["name"]], UI.H3, "ink"))
	head.add_child(UI.label("%d / %d" % [progress.x, progress.y], UI.SMALL, "ink_soft"))
	head.add_child(UI.grow())
	section.add_child(head)

	var grid := GridContainer.new()
	grid.columns = columns_for(140)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	section.add_child(grid)

	var accent: Color = GameData.city_palette(city["id"])[1]
	for p in city["puzzles"]:
		grid.add_child(_entry(p, city, accent))

	section.add_child(UI.spacer(10))
	return section


func _entry(p: Dictionary, city: Dictionary, accent: Color) -> Control:
	var solved := SaveGame.is_solved(p["id"])

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 108 if is_narrow() else 130)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not solved

	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.c("panel") if solved else Pal.c("panel_alt")
	sb.border_color = Pal.c("line")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	for s in ["normal", "disabled"]:
		card.add_theme_stylebox_override(s, sb)
	var hov := sb.duplicate()
	hov.border_color = Pal.c("accent")
	card.add_theme_stylebox_override("hover", hov)
	card.add_theme_stylebox_override("pressed", hov)

	var v := UI.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var art := PixelArtView.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.setup(p["art"], Pal.c("cell") if solved else accent, not solved)
	v.add_child(art)
	v.add_child(UI.label(p["name"] if solved else "— — —", UI.SMALL,
			"ink" if solved else "ink_faint", HORIZONTAL_ALIGNMENT_CENTER))

	if solved:
		card.pressed.connect(func(): _show_detail(p, city))
	return card


func _show_detail(p: Dictionary, city: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var scrim := Button.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.focus_mode = Control.FOCUS_NONE
	var flat := StyleBoxFlat.new()
	flat.bg_color = Pal.c("bg")
	flat.bg_color.a = 0.9
	for s in ["normal", "hover", "pressed"]:
		scrim.add_theme_stylebox_override(s, flat)
	scrim.pressed.connect(overlay.queue_free)
	overlay.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	var card := UI.panel(16)
	card.custom_minimum_size = Vector2(420, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(card)

	var v := UI.vbox(6)
	card.add_child(v)

	var art := PixelArtView.new()
	art.custom_minimum_size = Vector2(0, 200)
	art.setup(p["art"], Pal.c("cell"))
	v.add_child(art)
	v.add_child(UI.spacer(6))
	v.add_child(UI.label("%s  %s" % [p["emoji"], p["name"]], UI.H2, "ink",
			HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("%s · %s, %s" % [p["category"], city["name"], city["country"]],
			UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))

	var rec := SaveGame.solve_record(p["id"])
	if rec.has("time"):
		var t := int(rec["time"])
		v.add_child(UI.spacer(6))
		v.add_child(UI.label("solved in %d:%02d" % [t / 60, t % 60], UI.SMALL,
				"ink_faint", HORIZONTAL_ALIGNMENT_CENTER))

	v.add_child(UI.spacer(8))
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var replay := UI.button("Play again")
	var pid: String = p["id"]
	replay.pressed.connect(func(): go("puzzle", {"puzzle": pid}))
	row.add_child(replay)
	var close := UI.button("Close", true)
	close.pressed.connect(overlay.queue_free)
	row.add_child(close)
	v.add_child(row)
