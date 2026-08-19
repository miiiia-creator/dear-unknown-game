extends AppScreen


func build() -> void:
	var body := scaffold("Settings")

	body.add_child(_row("Mood",
			"Paper for daytime, Evening for a lamp-lit desk.",
			_mood_toggle()))

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
	stats.add_child(UI.label("Progress", UI.H3, "ink"))
	stats.add_child(UI.label("%d of %d discoveries · %d of %d destinations" % [
			GameData.discovered_count(), GameData.total_puzzle_count(),
			GameData.completed_city_count(), GameData.cities.size()],
			UI.BODY, "ink_soft"))
	stats.add_child(UI.paragraph("Saved to " + SaveGame.save_path(), UI.SMALL, "ink_faint"))
	body.add_child(stats)

	var danger := UI.hbox(10)
	var reset := UI.button("Reset all progress")
	reset.pressed.connect(_confirm_reset)
	danger.add_child(reset)
	danger.add_child(UI.grow())
	body.add_child(danger)

	body.add_child(UI.spacer(10))
	body.add_child(UI.hrule())
	body.add_child(UI.paragraph("Not in the prototype yet: sound, music, "
			+ "daily puzzle, Steam integration.", UI.SMALL, "ink_faint"))


func _row(title: String, help: String, control: Control) -> Control:
	var panel := UI.panel(12)
	var h := UI.hbox(16)
	panel.add_child(h)

	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, UI.BODY, "ink"))
	text.add_child(UI.paragraph(help, UI.SMALL, "ink_soft"))
	h.add_child(text)
	h.add_child(control)
	return panel


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


func _bool_toggle(key: String) -> Control:
	var on := bool(SaveGame.setting(key, true))
	var b := UI.button("On" if on else "Off", on)
	b.custom_minimum_size = Vector2(90, 0)
	b.pressed.connect(func():
		SaveGame.set_setting(key, not on)
		go("settings"))
	return b


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset progress"
	dialog.dialog_text = "This erases every discovery, postcard and stamp. " \
			+ "It cannot be undone."
	dialog.ok_button_text = "Erase everything"
	add_child(dialog)
	dialog.confirmed.connect(func():
		SaveGame.reset_everything()
		app.toast("Progress reset")
		go("menu"))
	dialog.popup_centered(Vector2i(460, 160))
