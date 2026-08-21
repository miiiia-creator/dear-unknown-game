extends AppScreen
## Settings.
##
## Every row used to carry a paragraph explaining itself. Six of them made a
## page of prose with some controls buried in it, and none of the explanations
## said anything the label and the switch did not — "Sound: On" does not need
## to be told that the sounds are pencil on paper and kept quiet on purpose.
## A setting is a name and a state.


func build() -> void:
	var body := scaffold("")

	body.add_child(_row("Language", _locale_toggle()))
	body.add_child(_row("Mood", _mood_toggle()))
	body.add_child(_row("Sound", _bool_toggle("sound")))
	body.add_child(_row("Music", _music_toggle()))
	body.add_child(_row("Cross off finished lines", _bool_toggle("mark_done")))

	body.add_child(UI.spacer(10))
	body.add_child(UI.hrule())

	var stats := UI.vbox(4)
	stats.add_child(UI.label(tr("Progress"), UI.H3, "ink"))
	stats.add_child(UI.label(tr("%d of %d discoveries · %d of %d destinations") % [
			GameData.discovered_count(), GameData.total_puzzle_count(),
			GameData.completed_city_count(), GameData.cities.size()],
			UI.BODY, "ink_soft"))
	stats.add_child(UI.paragraph(tr("Saved to ") + SaveGame.save_path(), UI.SMALL, "ink_faint"))
	body.add_child(stats)

	var danger := UI.hbox(10)
	var reset := UI.button(tr("Reset all progress"))
	reset.pressed.connect(_confirm_reset)
	danger.add_child(reset)
	danger.add_child(UI.grow())
	body.add_child(danger)


func _row(title: String, control: Control) -> Control:
	var panel := UI.panel(12)
	# A panel's padding was sized around two lines of prose. With the prose gone
	# it left each switch floating in a band of empty paper.
	var pad: StyleBoxFlat = panel.get_theme_stylebox("panel")
	pad.content_margin_top = 12
	pad.content_margin_bottom = 12
	var h := UI.hbox(16)
	panel.add_child(h)

	var name := UI.label(tr(title), UI.BODY, "ink")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name)
	h.add_child(control)
	return panel


func _locale_toggle() -> Control:
	var row := UI.hbox(6)
	var current := TranslationServer.get_locale()
	for entry in Pal.LOCALES:
		var code: String = entry["code"]
		var b := UI.button(str(entry["label"]), current.begins_with(code.split("_")[0]))
		b.pressed.connect(func():
			SaveGame.set_setting("locale", code)
			Pal.set_locale(code))
		row.add_child(b)
	return row


func _mood_toggle() -> Control:
	var row := UI.hbox(6)
	for option in [["Paper", "paper"], ["Evening", "evening"]]:
		var value: String = option[1]
		var b := UI.button(option[0], Pal.mood == value)
		b.pressed.connect(func():
			SaveGame.set_setting("mood", value)
			Pal.set_mood(value))
		row.add_child(b)
	return row


## Music needs its own toggle rather than _bool_toggle: turning it off has to
## stop the player, not merely be remembered for next time.
func _music_toggle() -> Control:
	var on := Music.enabled()
	var b := UI.button(tr("On") if on else tr("Off"), on)
	b.custom_minimum_size = Vector2(90, 0)
	b.pressed.connect(func():
		Music.set_enabled(not on)
		go("settings"))
	return b


func _bool_toggle(key: String) -> Control:
	var on := bool(SaveGame.setting(key, true))
	var b := UI.button(tr("On") if on else "Off", on)
	b.custom_minimum_size = Vector2(90, 0)
	b.pressed.connect(func():
		SaveGame.set_setting(key, not on)
		go("settings"))
	return b


func _confirm_reset() -> void:
	var ask := Ask.open(self, tr("Reset progress"),
			tr("This erases every discovery, postcard and stamp. "
			+ "It cannot be undone."),
			tr("Erase everything"))
	ask.confirmed.connect(func():
		SaveGame.reset_everything()
		app.toast(tr("Progress reset"))
		go("prologue"))
