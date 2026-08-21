extends AppScreen
## A city's card, and the way into its puzzles.
##
## The card arrives with the letter face up. Touch it and it turns over to a
## blank back with one point of light on it; touch that and the first grid
## opens. Solving a grid leaves its picture on the back and lights the next
## point, so the card develops as the city is worked through — the postcard is
## the level select, and filling it in is the progress bar.

const SLOT_RISE := 0.5

var city_id: String
var _stage: Control
var _letter: PostcardView
var _back: Control
var _busy := false
var _showing_back := false


func build() -> void:
	city_id = args.get("city", GameData.current_city_id())

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	root.offset_left = gutter
	root.offset_right = -gutter
	root.offset_top = 8
	root.offset_bottom = -gutter
	add_child(root)

	# Everything but the card goes dark, so looking at one feels like holding it
	# up rather than reading a page that happens to have a card on it.
	var _backdrop := ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.04, 0.045, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, 0)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_stage)

	_letter = PostcardView.new()
	_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_letter.face = "back"
	_stage.add_child(_letter)
	_letter.setup(city_id)

	_back = CardBack.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.city_id = city_id
	_back.visible = false
	_back.slot_picked.connect(_open)
	_stage.add_child(_back)

	# Coming back from a solved grid, the card is already turned over — the
	# letter has been read and showing it again would be starting over.
	if args.get("face", "") == "back" or _solved_count() > 0:
		_showing_back = true
		_letter.visible = false
		_back.visible = true
		_back.play_arrival()

	root.add_child(UI.spacer(10))
	root.add_child(_hint())


func _hint() -> Control:
	var text := tr("Tap the card") if not _showing_back else tr("Tap the light")
	if _showing_back and _next_puzzle() == "":
		text = ""
	var label := UI.label(text, UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _solved_count() -> int:
	var n := 0
	for p in GameData.puzzles_of(city_id):
		if SaveGame.is_solved(p["id"]):
			n += 1
	return n


func _next_puzzle() -> String:
	for p in GameData.puzzles_of(city_id):
		if not SaveGame.is_solved(p["id"]):
			return p["id"]
	return ""


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _showing_back:
		_turn()
		accept_event()


func _turn() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("flip")
	_stage.pivot_offset = _stage.size * 0.5
	var tw := create_tween()
	tw.tween_property(_stage, "scale:x", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_showing_back = true
		_letter.visible = false
		_back.visible = true
		_back.play_arrival())
	tw.tween_property(_stage, "scale:x", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_busy = false
		replace("card", {"city": city_id, "face": "back"}))


func _open(puzzle_id: String) -> void:
	go("puzzle", {"puzzle": puzzle_id})
