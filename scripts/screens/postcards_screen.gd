extends AppScreen
## Earned postcards, front and back, plus the ones already sent.

var _selected: String = ""
var _card: PostcardView
var _flip_button: Button


func build() -> void:
	var earned: Array = SaveGame.data["postcards"]
	var body := scaffold("Postcards",
			"%d of %d collected" % [earned.size(), GameData.cities.size()])

	if earned.is_empty():
		body.add_child(UI.paragraph(
				"Complete every puzzle in a destination to earn its postcard.",
				UI.BODY, "ink_soft"))
		return

	_selected = args.get("city", earned[-1])
	if not _selected in earned:
		_selected = earned[-1]

	var picker := UI.hbox(8)
	for city_id in earned:
		var city := GameData.city(city_id)
		var b := UI.button("%s  %s" % [city["flag"], city["name"]], city_id == _selected)
		var id: String = city_id
		b.pressed.connect(func(): _select(id))
		picker.add_child(b)
	body.add_child(picker)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 340)
	body.add_child(stage)

	_card = PostcardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.setup(_selected, "", "", "")
	stage.add_child(_card)

	var actions := UI.hbox(10)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER

	_flip_button = UI.button("↻  Turn over")
	_flip_button.pressed.connect(_flip)
	actions.add_child(_flip_button)

	var send := UI.button("📮  Send to a friend", true)
	send.pressed.connect(func(): go("share", {"city": _selected}))
	actions.add_child(send)
	body.add_child(actions)

	var sent: Array = SaveGame.sent_postcards()
	if not sent.is_empty():
		body.add_child(UI.spacer(10))
		body.add_child(UI.hrule())
		body.add_child(UI.label("Sent", UI.H3, "ink"))
		for entry in sent:
			var city := GameData.city(entry["city"])
			var row := UI.hbox(10)
			row.add_child(UI.label("%s  %s" % [city.get("flag", ""),
					city.get("name", "?")], UI.BODY, "ink"))
			row.add_child(UI.label("to %s" % entry.get("to", "a friend"),
					UI.SMALL, "ink_soft"))
			row.add_child(UI.grow())
			var copy := UI.quiet_button("copy link", UI.SMALL)
			var code: String = entry["code"]
			copy.pressed.connect(func():
				DisplayServer.clipboard_set(ShareCode.url_for(code))
				app.toast("Link copied"))
			row.add_child(copy)
			body.add_child(row)


func _select(city_id: String) -> void:
	go("postcards", {"city": city_id})


func _flip() -> void:
	_card.flip()
	_flip_button.text = "↻  Turn back" if _card.face == "back" else "↻  Turn over"
