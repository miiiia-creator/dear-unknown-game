extends AppScreen
## Compose a postcard for a friend.
##
## The friend gets a link. Opening it shows a locked postcard and the nonogram
## that unlocks it — solve the puzzle, read the note. Everything travels inside
## the URL fragment, so there is nothing to host but one static HTML file.

var city_id: String
var puzzle_id: String

var _card: PostcardView
var _from: LineEdit
var _to: LineEdit
var _message: TextEdit
var _link_label: Label


func build() -> void:
	var earned: Array = SaveGame.data["postcards"]
	var body := scaffold(tr("Send a Postcard"),
			"Your friend solves the puzzle to open it. No app needed.")

	if earned.is_empty():
		body.add_child(UI.paragraph(
				"Complete a destination first — you need a postcard to send.",
				UI.BODY, "ink_soft"))
		return

	city_id = args.get("city", earned[-1])
	if not city_id in earned:
		city_id = earned[-1]
	var puzzles := GameData.puzzles_of(city_id)
	puzzle_id = args.get("puzzle", puzzles[-1]["id"])

	# Side by side on a desktop, stacked on a phone.
	var narrow := column_width() < 700.0
	var columns: BoxContainer = UI.vbox(16) if narrow else UI.hbox(24)
	body.add_child(columns)

	# ---- left: the form
	var form := UI.vbox(10)
	form.custom_minimum_size = Vector2(0 if narrow else 360, 0)
	columns.add_child(form)

	form.add_child(UI.label(tr("Postcard"), UI.SMALL, "ink_soft"))
	var picker := UI.hbox(6)
	for id in earned:
		var city := GameData.city(id)
		var b := UI.button(str(GameData.text(city["name"])), id == city_id)
		b.tooltip_text = GameData.text(city["name"])
		var target: String = id
		b.pressed.connect(func(): go("share", {"city": target}))
		picker.add_child(b)
	form.add_child(picker)

	form.add_child(UI.label(tr("Locked behind"), UI.SMALL, "ink_soft"))
	var chooser := UI.dropdown()
	for i in puzzles.size():
		var p: Dictionary = puzzles[i]
		chooser.add_item("%s  (%d×%d)" % [GameData.text(p["name"]),
				p["art"].size(), String(p["art"][0]).length()], i)
		if p["id"] == puzzle_id:
			chooser.select(i)
	chooser.item_selected.connect(func(i: int):
		puzzle_id = puzzles[i]["id"]
		_refresh_link())
	form.add_child(chooser)

	form.add_child(UI.label(tr("To"), UI.SMALL, "ink_soft"))
	_to = UI.line_edit("your friend's name", 24)
	_to.text_changed.connect(func(_t): _refresh_card())
	form.add_child(_to)

	var msg_head := UI.hbox(8)
	msg_head.add_child(UI.label(tr("Message"), UI.SMALL, "ink_soft"))
	msg_head.add_child(UI.grow())
	var suggest := UI.quiet_button(tr("Suggest one"), UI.SMALL)
	suggest.pressed.connect(_suggest_message)
	msg_head.add_child(suggest)
	form.add_child(msg_head)

	_message = TextEdit.new()
	_message.placeholder_text = "Wish you were here…"
	_message.custom_minimum_size = Vector2(0, 92)
	_message.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_message.add_theme_font_override("font", Pal.ui_font)
	_message.add_theme_font_size_override("font_size", UI.BODY)
	_message.add_theme_color_override("font_color", Pal.c("ink"))
	_message.add_theme_color_override("font_placeholder_color", Pal.c("ink_faint"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.c("bg")
	sb.border_color = Pal.c("line_strong")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_message.add_theme_stylebox_override("normal", sb)
	_message.add_theme_stylebox_override("focus", sb)
	_message.text_changed.connect(_refresh_card)
	form.add_child(_message)

	form.add_child(UI.label(tr("From"), UI.SMALL, "ink_soft"))
	_from = UI.line_edit("your name", 24)
	_from.text_changed.connect(func(_t): _refresh_card())
	form.add_child(_from)

	# ---- right: live preview
	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 280)
	right.add_child(stage)

	_card = PostcardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.face = "back"
	_card.setup(city_id, "", "", "")
	stage.add_child(_card)

	var flip := UI.quiet_button(tr("See the front"), UI.SMALL)
	flip.pressed.connect(func():
		_card.flip()
		flip.text = "See the back" if _card.face == "front" else "See the front")
	right.add_child(flip)

	right.add_child(UI.hrule())
	_link_label = UI.paragraph("", UI.SMALL, "ink_soft")
	_link_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	right.add_child(_link_label)

	var actions := UI.hbox(8)
	var copy_link := UI.button(tr("Copy link"), true)
	copy_link.pressed.connect(_copy_link)
	actions.add_child(copy_link)

	var copy_code := UI.button(tr("Copy code only"))
	copy_code.pressed.connect(func():
		DisplayServer.clipboard_set(_code())
		app.toast(tr("Code copied"), tr("Paste it into the postcard page.")))
	actions.add_child(copy_code)
	right.add_child(actions)

	_refresh_card()


## Drop a starter line into the box. Always picks something different from
## what is already there, so pressing it again actually shuffles.
func _suggest_message() -> void:
	var notes: Array = GameData.city(city_id).get("notes", [])
	if notes.is_empty():
		return
	var current := _message.text.strip_edges()
	var options: Array = []
	for n in notes:
		if str(n) != current:
			options.append(n)
	if options.is_empty():
		options = notes
	_message.text = str(options[randi() % options.size()])
	_message.set_caret_column(_message.text.length())
	_refresh_card()


func _code() -> String:
	return ShareCode.build(city_id, puzzle_id, _message.text, _from.text, _to.text)


func _refresh_card() -> void:
	_card.setup(city_id, _message.text, _from.text, _to.text)
	_refresh_link()


func _refresh_link() -> void:
	var url := ShareCode.url_for(_code())
	_link_label.text = url


func _copy_link() -> void:
	var url := ShareCode.url_for(_code())
	DisplayServer.clipboard_set(url)
	SaveGame.record_sent(city_id, _to.text.strip_edges(), _code())
	var who := _to.text.strip_edges()
	app.toast(tr("Link copied"),
			tr("to %s") % who if who != "" else tr("Paste it into the postcard page."))
