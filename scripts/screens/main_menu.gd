extends AppScreen
## Title screen. Deliberately quiet: a destination, one big button, a short
## list of collections.


func build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := UI.vbox(0)
	column.custom_minimum_size = Vector2(minf(420.0, column_width()), 0)
	centre.add_child(column)

	column.add_child(UI.label("✈", 34, "accent", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(4))
	var t := UI.label("Dear, Unknown", 34, "ink", HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(t)
	column.add_child(UI.spacer(4))
	# The name is the series; the season is what this set of postcards is about.
	column.add_child(UI.label("SEASON ONE   ·   THE LAST ONES",
			UI.SMALL, "accent", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(26))

	var city_id := GameData.current_city_id()
	var city := GameData.city(city_id)
	var progress := GameData.city_progress(city_id)

	column.add_child(UI.label("%s  %s" % [city.get("flag", ""), city.get("name", "")],
			UI.H3, "ink", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(6))

	var bar_row := UI.hbox(0)
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ratio := float(progress.x) / maxf(1.0, float(progress.y))
	bar_row.add_child(UI.progress_bar(ratio, minf(220.0, column_width() * 0.6), 5))
	column.add_child(bar_row)
	column.add_child(UI.spacer(6))
	column.add_child(UI.label("%d of %d discovered" % [progress.x, progress.y],
			UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(22))

	var next_puzzle := GameData.next_puzzle_for(city_id)
	var cont := UI.button("CONTINUE" if GameData.discovered_count() > 0 else "START",
			true)
	cont.custom_minimum_size = Vector2(0, 52)
	if next_puzzle.is_empty():
		cont.text = "VIEW %s" % String(city.get("name", "")).to_upper()
		cont.pressed.connect(func(): go("city", {"city": city_id}))
	else:
		cont.pressed.connect(func():
			go("puzzle", {"puzzle": next_puzzle["id"]}))
	column.add_child(cont)
	column.add_child(UI.spacer(22))

	var links := [
		["🗺   World Map", "map", {}],
		["📖   Travel Journal", "journal", {}],
		["📮   Postcards", "postcards", {}],
		["🛂   Passport", "passport", {}],
		["⚙   Settings", "settings", {}],
	]
	for entry in links:
		var b := UI.quiet_button(entry[0], UI.BODY)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var screen: String = entry[1]
		var a: Dictionary = entry[2]
		b.pressed.connect(func(): go(screen, a))
		column.add_child(b)

	column.add_child(UI.spacer(20))
	var soon := UI.label("Daily Puzzle — coming soon", UI.SMALL, "ink_faint",
			HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(soon)
