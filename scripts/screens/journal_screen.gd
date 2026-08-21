extends AppScreen
## Where you have been, all of it, on one screen.
##
## This was two destinations. The map showed ten pins and a list of ten
## one-line rows; the journal showed one of those cities at a time with the
## same name, the same progress and the same tiles. Two pages built out of the
## same ten facts is a page and its own table of contents, and nobody needed
## to be able to go from one to the other.
##
## So: the map is pinned at the top, the list under it is the destinations, and
## a destination goes straight to its card — the letter, the turn, the points
## of light. The rows briefly expanded into a strip of grid thumbnails instead;
## that put a picture of the puzzle one tap from the card that already has one,
## and made the list something to operate rather than something to read. The
## card is the way in. There is no second way in.
##
## The map lights whichever destination you are currently travelling to and
## steps the rest back, so it says where you are rather than restating the list.

var _map: WorldMapView


func build() -> void:
	var here := str(args.get("city", GameData.current_city_id()))

	var frame := UI.panel(6)
	frame.custom_minimum_size = Vector2(0, 190 if is_narrow() else 250)
	_map = WorldMapView.new()
	_map.focus_id = here
	_map.city_picked.connect(_open)
	frame.add_child(_map)

	var body := scaffold(tr("Journal"),
			tr("%d of %d destinations stamped") % [GameData.completed_city_count(),
			GameData.cities.size()], frame)

	for season in GameData.seasons:
		body.add_child(_season_block(season))


## One season: a quiet heading, then its destinations.
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
	# The scroll bar floats over the right edge, the same way it does over the
	# rows below — without this the season's count is printed underneath it.
	var clear := Control.new()
	clear.custom_minimum_size = Vector2(14, 0)
	head.add_child(clear)
	block.add_child(head)
	block.add_child(UI.hrule())

	var list := UI.vbox(0)
	block.add_child(list)
	for id in city_ids:
		list.add_child(_row(GameData.city(str(id))))
	return block


func _row(city: Dictionary) -> Control:
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

	# The chapter's own name, once the destination is stamped. It takes the
	# place the date used to hold: the date said when *you* got here, which is a
	# save file's fact rather than the story's, and every finished row carried
	# the same one. The title is what the chapter turned out to be about, and
	# like the letter it comes with, it is not there until it is earned.
	if complete:
		var chapter := GameData.text(city.get("letter", {}).get("title", ""))
		if chapter != "":
			line.add_child(UI.label_small(chapter, "ink_soft"))

	line.add_child(UI.grow())
	var tail := _status(city, unlocked, complete)
	if tail != null:
		line.add_child(tail)

	if unlocked and GameData.is_city_written(id):
		row.pressed.connect(func(): _open(id))
	else:
		row.disabled = true
	return row


## The right-hand end of a row: a count while playing, and the name of what
## stands in the way while locked. A finished destination has nothing there —
## the pin says it is stamped and the chapter title says what it was.
func _status(city: Dictionary, unlocked: bool, complete: bool) -> Control:
	var id: String = city["id"]
	if not GameData.is_city_written(id):
		return UI.label_small(tr("Still being written"), "ink_faint")
	if complete:
		return null
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


## A destination, from the list or from its pin — the map is a second way to
## say the same thing, not a second place to go. A city that has not been
## written has no card to open, which the map used to do anyway.
func _open(city_id: String) -> void:
	if not GameData.is_city_unlocked(city_id) or not GameData.is_city_written(city_id):
		# The row for this destination is on the same screen and already says
		# what it is waiting for, so the sound alone is the whole answer.
		Sfx.play("locked")
		return
	go("card", {"city": city_id})
