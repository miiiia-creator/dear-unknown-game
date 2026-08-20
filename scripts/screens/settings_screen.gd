extends AppScreen


func build() -> void:
	var body := scaffold(tr("Settings"))

	body.add_child(_row("Language",
			"Interface and letters. The Chinese letters are written rather than "
			+ "translated, so they are not line-for-line the same.",
			_locale_toggle()))

	body.add_child(_row("Mood",
			"Paper for daytime, Evening for a lamp-lit desk.",
			_mood_toggle()))

	body.add_child(_row("Sound",
			"Pencil on the grid and paper on the cards. Kept quiet on purpose.",
			_bool_toggle("sound")))

	body.add_child(_row("Music",
			"One piece, looping. It is not in the download — it arrives on its "
			+ "own once the game is open, so it never makes you wait.",
			_music_toggle()))

	body.add_child(_row("Cross off finished lines",
			"When a row or column matches its numbers, strike the numbers out. "
			+ "It marks what the line says on its own — the line can still be in "
			+ "the wrong place. Turn off for a stricter puzzle.",
			_bool_toggle("mark_done")))

	body.add_child(_row("Crosshair guides",
			"Highlight the row and column under the cursor.",
			_bool_toggle("cross_hair")))

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

	body.add_child(UI.spacer(10))
	body.add_child(UI.hrule())
	body.add_child(UI.paragraph(tr("Not in the prototype yet: music, daily "
			+ "puzzle, Steam integration."), UI.SMALL, "ink_faint"))


func _row(title: String, help: String, control: Control) -> Control:
	var panel := UI.panel(12)
	var h := UI.hbox(16)
	panel.add_child(h)

	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(tr(title), UI.BODY, "ink"))
	text.add_child(UI.paragraph(tr(help), UI.SMALL, "ink_soft"))
	h.add_child(text)
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
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("Reset progress")
	dialog.dialog_text = "This erases every discovery, postcard and stamp. " \
			+ "It cannot be undone."
	dialog.ok_button_text = tr("Erase everything")
	add_child(dialog)
	dialog.confirmed.connect(func():
		SaveGame.reset_everything()
		app.toast(tr("Progress reset"))
		go("prologue"))
	dialog.popup_centered(Vector2i(460, 160))
