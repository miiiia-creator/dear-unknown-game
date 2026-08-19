extends AppScreen
## Destination picker: the dot map up top, a row of city cards underneath.


func build() -> void:
	var body := scaffold("World Map",
			"%d of %d destinations stamped" % [GameData.completed_city_count(),
			GameData.cities.size()])

	var map_panel := UI.panel(16)
	map_panel.custom_minimum_size = Vector2(0, 220 if is_narrow() else 380)
	var map := WorldMapView.new()
	map.city_picked.connect(_open_city)
	map_panel.add_child(map)
	body.add_child(map_panel)

	var grid := GridContainer.new()
	grid.columns = columns_for(240, 3)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)

	for city in GameData.cities:
		grid.add_child(_city_card(city))


func _city_card(city: Dictionary) -> Control:
	var id: String = city["id"]
	var unlocked := GameData.is_city_unlocked(id)
	var complete := GameData.is_city_complete(id)
	var progress := GameData.city_progress(id)

	var card := UI.panel(12, not unlocked)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := UI.vbox(6)
	card.add_child(v)

	var head := UI.hbox(8)
	head.add_child(UI.label(city["flag"], UI.H3, "ink"))
	var name_label := UI.label(city["name"], UI.H3, "ink" if unlocked else "ink_faint")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if complete:
		head.add_child(UI.label("✓", UI.BODY, "accent"))
	elif not unlocked:
		head.add_child(UI.label("🔒", UI.BODY, "ink_faint"))
	v.add_child(head)

	v.add_child(UI.paragraph(city["tagline"], UI.SMALL,
			"ink_soft" if unlocked else "ink_faint"))
	v.add_child(UI.spacer(2))

	if unlocked:
		v.add_child(UI.progress_bar(float(progress.x) / maxf(1.0, progress.y),
				minf(200.0, column_width() * 0.5), 5))
		v.add_child(UI.label("%d / %d discoveries" % [progress.x, progress.y],
				UI.SMALL, "ink_soft"))
		var open := UI.button("Open" if not complete else "Revisit")
		open.pressed.connect(func(): _open_city(id))
		v.add_child(open)
	else:
		var prev: Dictionary = GameData.cities[int(city["order"]) - 1]
		v.add_child(UI.label("Finish %s to unlock" % prev["name"], UI.SMALL, "ink_faint"))

	return card


func _open_city(city_id: String) -> void:
	if not GameData.is_city_unlocked(city_id):
		app.toast("Locked", "Complete the previous destination first.")
		return
	go("city", {"city": city_id})
