extends AppScreen
## Everything global: where you have been and what is stamped.
##
## The passport used to be its own page. A stamp means "I was here", which is
## what a map is already saying, so the stamp belongs on the map rather than one
## tap away from it.
##
## The destinations below the map used to be big cards, each carrying a drawn
## passport stamp and its own button — five of those already filled a screen,
## and a second season would have doubled it. They are one line each now,
## grouped under the season they belong to, using the same three pin states the
## map draws above. The stamp itself moved to the destination's own page, where
## there is room for it to be legible.


func build() -> void:
	var body := scaffold(tr("World Map"),
			tr("%d of %d destinations stamped") % [GameData.completed_city_count(),
			GameData.cities.size()])

	var map_panel := UI.panel(16)
	map_panel.custom_minimum_size = Vector2(0, 200 if is_narrow() else 340)
	var map := WorldMapView.new()
	map.city_picked.connect(_open_city)
	map_panel.add_child(map)
	body.add_child(map_panel)

	for season in GameData.seasons:
		body.add_child(_season_block(season))


## One season: a quiet heading, then its destinations as lines.
func _season_block(season: Dictionary) -> Control:
	var city_ids: Array = season.get("cities", [])
	var stamped := 0
	for id in city_ids:
		if GameData.is_city_complete(str(id)):
			stamped += 1

	var block := UI.vbox(4)

	var head := UI.hbox(10)
	head.add_child(UI.label_small(GameData.season_label(str(season.get("id", ""))), "accent"))
	head.add_child(UI.grow())
	head.add_child(UI.label_small("%d / %d" % [stamped, city_ids.size()], "ink_faint"))
	block.add_child(head)
	block.add_child(UI.hrule())

	var list := UI.vbox(0)
	block.add_child(list)
	for id in city_ids:
		list.add_child(_destination_row(GameData.city(str(id))))
	return block


func _destination_row(city: Dictionary) -> Control:
	var id: String = city["id"]
	var unlocked := GameData.is_city_unlocked(id)
	var complete := GameData.is_city_complete(id)

	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 46 if is_narrow() else 52)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.tooltip_text = GameData.text(city["name"])

	# Flat, with a hairline underneath: a list of lines, not a stack of cards.
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Pal.c("line")
	flat.border_width_bottom = 1
	row.add_theme_stylebox_override("normal", flat)
	row.add_theme_stylebox_override("disabled", flat)
	var lit := flat.duplicate() as StyleBoxFlat
	lit.bg_color = Pal.c("panel")
	row.add_theme_stylebox_override("hover", lit)
	row.add_theme_stylebox_override("pressed", lit)

	var line := UI.hbox(12)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 2
	# The scroll bar floats over the right edge; keep the status clear of it.
	line.offset_right = -14
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(line)

	var mark := PinMark.new()
	mark.setup("stamped" if complete else ("open" if unlocked else "locked"))
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(mark)

	line.add_child(UI.label(GameData.text(city["name"]), UI.H3,
			"ink" if unlocked else "ink_faint"))
	line.add_child(UI.grow())
	line.add_child(_status(city, unlocked, complete))

	if unlocked and GameData.is_city_written(id):
		row.pressed.connect(func(): _open_city(id))
	else:
		row.disabled = true
	return row


## The right-hand end of a row: a date once stamped, a count while playing, and
## the name of what stands in the way while locked.
func _status(city: Dictionary, unlocked: bool, complete: bool) -> Control:
	var id: String = city["id"]
	if not GameData.is_city_written(id):
		return UI.label_small(tr("Still being written"), "ink_faint")
	if complete:
		var date := SaveGame.stamp_date(id)
		return UI.label_small(date if date != "" else tr("Stamped"), "accent")
	if unlocked:
		var progress := GameData.city_progress(id)
		var wrap := UI.hbox(8)
		wrap.alignment = BoxContainer.ALIGNMENT_END
		if not is_narrow():
			var bar := UI.progress_bar(float(progress.x) / maxf(1.0, progress.y), 90.0, 4)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			wrap.add_child(bar)
		wrap.add_child(UI.label_small("%d / %d" % [progress.x, progress.y], "ink_soft"))
		return wrap
	var prev: Dictionary = GameData.cities[int(city["order"]) - 1]
	# Across a season boundary, naming the previous city is confusing — it
	# belongs to a chapter this row is not part of. Name the chapter instead.
	if str(prev.get("season", "")) != str(city.get("season", "")):
		var earlier := GameData.season(str(prev.get("season", "")))
		return UI.label_small(
				tr("Finish %s to unlock") % GameData.text(earlier.get("title", "")),
				"ink_faint")
	return UI.label_small(tr("Finish %s to unlock") % GameData.text(prev["name"]),
			"ink_faint")


func _open_city(city_id: String) -> void:
	if not GameData.is_city_unlocked(city_id):
		# The row for this destination is on the same screen and already says
		# what it is waiting for, so the sound alone is the whole answer. A
		# notification here was repeating the page back at the player.
		Sfx.play("locked")
		return
	go("journal", {"city": city_id})
