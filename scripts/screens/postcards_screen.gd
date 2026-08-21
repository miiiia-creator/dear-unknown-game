extends AppScreen
## Everything M has sent, laid out by the day it was posted.
##
## There used to be a row of buttons for the destinations and another for the
## seasons. Five seasons of five would have made twenty-seven buttons, and no
## amount of wrapping fixes that — the postcards are a pile, not a menu. So the
## pile is what this is: one card at a time, filling the screen, with a
## timeline underneath you can drag.
##
## The timeline runs on postmarks rather than on the order the cards arrived,
## which is the point of it. Season Two was written in the middle of Season
## One, so a card earned late lands between two you have had for hours.
##
## Turning a card over is a state that persists as you move along the line: on
## the written side, dragging to the next card shows its writing too. That is
## the difference between a gallery and something you can read straight
## through.

const OPENING := "opening"

var _cards: Array = []          ## [{"id", "label"}] in postmark order
var _index := 0
var _face := "front"

var _stage: Control
var _card: PostcardView
var _opening: OpeningCardView
var _line: PostcardTimeline
var _busy := false


func build() -> void:
	_collect()
	_index = clampi(int(args.get("at", _index_of(str(args.get("card", ""))))),
			0, maxi(0, _cards.size() - 1))
	_face = str(args.get("face", "front"))

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.04, 0.045, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	root.offset_left = gutter
	root.offset_right = -gutter
	root.offset_top = 8
	root.offset_bottom = -gutter
	add_child(root)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_stage)

	_opening = OpeningCardView.new()
	_opening.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opening.dots = 1.0
	_opening.note = 1.0
	_stage.add_child(_opening)

	_card = PostcardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_card)

	root.add_child(UI.spacer(8))

	_line = PostcardTimeline.new()
	_line.custom_minimum_size = Vector2(0, 54)
	_line.entries = _cards
	_line.index = _index
	_line.picked.connect(_move_to)
	root.add_child(_line)

	if _cards.is_empty():
		_stage.add_child(UI.paragraph(
				tr("Complete every puzzle in a destination to earn its postcard."),
				UI.BODY, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
		return

	_show()


## Earned cards in postmark order. The season's opening card has no postmark
## and no destination, so it sits at the head of the line where it belongs.
func _collect() -> void:
	_cards.clear()
	for season in GameData.seasons:
		var sid := str(season.get("id", ""))
		if not GameData.opening_of(sid).is_empty():
			_cards.append({"id": OPENING, "season": sid, "label": "", "at": ""})
	var earned: Array = []
	for city in GameData.cities:
		var id: String = city["id"]
		if not SaveGame.has_postcard(id):
			continue
		earned.append({"id": id, "label": _month_of(str(city.get("sent", ""))),
				"at": str(city.get("sent", ""))})
	earned.sort_custom(func(a, b): return _stamp(a["at"]) < _stamp(b["at"]))
	_cards.append_array(earned)


## "08 APR 2019" as a sortable number, and as the short label on the line.
func _stamp(sent: String) -> int:
	var parts := sent.split(" ")
	if parts.size() < 3:
		return 0
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
			"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var m := MONTHS.find(String(parts[1]).to_upper())
	return int(parts[2]) * 10000 + (m + 1) * 100 + int(parts[0])


func _month_of(sent: String) -> String:
	var parts := sent.split(" ")
	return "%s %s" % [parts[1], parts[2]] if parts.size() >= 3 else ""


func _index_of(card_id: String) -> int:
	for i in _cards.size():
		if str(_cards[i]["id"]) == card_id:
			return i
	return 0


func _show() -> void:
	var here: Dictionary = _cards[_index]
	var opening := str(here["id"]) == OPENING
	_opening.visible = opening
	_card.visible = not opening
	if opening:
		_opening.season_id = str(here.get("season", ""))
		_opening.face = "back" if _face == "back" else "front"
	else:
		_card.setup(str(here["id"]))
		_card.face = _face


## The card takes the tap, and turning it over is what a tap does.
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _cards.is_empty():
		_flip()
		accept_event()


func _flip() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("flip")
	_stage.pivot_offset = _stage.size * 0.5
	var tw := create_tween()
	tw.tween_property(_stage, "scale:x", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_face = "back" if _face == "front" else "front"
		args["face"] = _face
		_show())
	tw.tween_property(_stage, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _busy = false)


## Moving along the line keeps the face you were reading. Someone working
## through the letters should not have to turn every card over again.
##
## This used to swap the screen for a fresh one at the new index, which threw
## away the timeline mid-gesture — the line could not be pulled, because the
## thing being pulled was destroyed the moment it crossed a card. The card is
## changed in place instead, and where you are is written back into `args` so
## that a rebuild under the player — a resize, a change of mood, a change of
## language — still comes back to the card being read.
func _move_to(next: int) -> void:
	if next == _index or next >= _cards.size():
		return
	_index = next
	_show()
	args["at"] = _index
	args["face"] = _face
