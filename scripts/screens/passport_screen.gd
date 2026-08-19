extends AppScreen
## Stamps earned, plus the achievement list that Steam will mirror.


func build() -> void:
	var stamped := GameData.completed_city_count()
	var body := scaffold("Passport",
			"%d of %d destinations" % [stamped, GameData.cities.size()])

	var grid := GridContainer.new()
	grid.columns = columns_for(190, 3)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)

	for city in GameData.cities:
		grid.add_child(_page(city))

	body.add_child(UI.spacer(14))
	body.add_child(UI.hrule())
	body.add_child(UI.label("Achievements", UI.H3, "ink"))
	body.add_child(UI.paragraph(
			"Mirrors the Steam achievement list; unlocked locally for now.",
			UI.SMALL, "ink_faint"))

	for id in SaveGame.ACHIEVEMENTS:
		var info: Dictionary = SaveGame.ACHIEVEMENTS[id]
		var earned := SaveGame.has_achievement(id)
		var row := UI.hbox(10)
		row.add_child(UI.label("🏆" if earned else "○", UI.BODY,
				"gold" if earned else "ink_faint"))
		row.add_child(UI.label(info["title"], UI.BODY, "ink" if earned else "ink_faint"))
		row.add_child(UI.paragraph(info["desc"], UI.SMALL, "ink_soft" if earned else "ink_faint"))
		row.add_child(UI.grow())
		body.add_child(row)


func _page(city: Dictionary) -> Control:
	var id: String = city["id"]
	var complete := GameData.is_city_complete(id)
	var unlocked := GameData.is_city_unlocked(id)

	var panel := UI.panel(12, not complete)
	panel.custom_minimum_size = Vector2(0, 160 if is_narrow() else 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := UI.vbox(4)
	panel.add_child(v)

	var head := UI.hbox(8)
	head.add_child(UI.label(city["flag"], UI.BODY, "ink"))
	head.add_child(UI.label(city["name"], UI.BODY,
			"ink" if unlocked else "ink_faint"))
	head.add_child(UI.grow())
	v.add_child(head)

	var slot := Control.new()
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, 140)
	v.add_child(slot)

	if complete:
		var stamp := StampView.new()
		stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
		# A little variation so the page looks hand-stamped.
		stamp.setup(id, -0.18 + 0.09 * float(int(city["order"]) % 3))
		slot.add_child(stamp)
	else:
		var progress := GameData.city_progress(id)
		var note := UI.label(
				"%d / %d" % [progress.x, progress.y] if unlocked else "🔒",
				UI.H3, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER)
		note.set_anchors_preset(Control.PRESET_CENTER)
		note.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(note)

	return panel
