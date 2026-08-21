extends AppScreen
## One season's cards, shown full bleed.
##
## The postcard is the thing this whole game is for, so it gets the screen
## rather than a panel in the middle of one. Everything else — which card,
## turning it over, sending it — sits underneath as small controls, and the card
## takes every pixel that is left.
##
## The card from M is first in the same row as the destinations: it is the
## season's opening card, not a special case. Every season starts with one.

const OPENING := "opening"

const RISE := 0.55          ## seconds for a card to arrive
const FLIP := 0.34          ## seconds for half a turn

var _season_id := ""
var _selected := OPENING
var _has_opening := true
var _card: PostcardView
var _opening: OpeningCardView
var _flip_button: Button
var _stage: Control
var _empty: Label
var _busy := false


func build() -> void:
	# A card names its own season. Asking for one without saying which season it
	# belongs to used to land on whatever season was current and then quietly
	# fall back to that season's first card.
	var season := GameData.season(str(args.get("season", "")))
	if season.is_empty() and args.has("card") and str(args["card"]) != OPENING:
		season = GameData.season_of(str(args["card"]))
	if season.is_empty():
		season = GameData.current_season()
	_season_id = str(season.get("id", ""))
	var city_ids: Array = season.get("cities", [])
	var earned := _earned_in(city_ids)

	# Only the first season has an opening card, so for every season after it
	# the row starts at the first destination.
	_has_opening = not GameData.opening_of(_season_id).is_empty()
	_selected = args.get("card", OPENING if _has_opening else "")
	if _selected == OPENING and not _has_opening:
		_selected = ""
	if _selected != OPENING and not _selected in earned:
		_selected = OPENING if _has_opening else (earned[0] if not earned.is_empty() else "")

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	root.offset_left = gutter
	root.offset_right = -gutter
	root.offset_top = 10
	root.offset_bottom = -gutter
	add_child(root)

	root.add_child(_caption(earned.size(), city_ids.size()))
	var seasons := _season_switcher()
	if seasons != null:
		root.add_child(seasons)

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

	_opening = OpeningCardView.new()
	_opening.season_id = _season_id if _has_opening else str(GameData.seasons[0].get("id", ""))
	_opening.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opening.dots = 1.0
	_opening.note = 1.0
	_opening.face = "back"
	_stage.add_child(_opening)

	_card = PostcardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_card)

	_empty = UI.paragraph(
			tr("Complete every puzzle in a destination to earn its postcard."),
			UI.BODY, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER)
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.anchor_left = 0.2
	_empty.anchor_right = 0.8
	_empty.anchor_top = 0.45
	_empty.anchor_bottom = 0.55
	_empty.offset_left = 0
	_empty.offset_right = 0
	_stage.add_child(_empty)

	_show_face()

	root.add_child(UI.spacer(12))
	root.add_child(_controls(city_ids, earned))
	_play_entry.call_deferred()



## Once there is more than one season, the earlier ones still have to be
## reachable — a postcard you were sent is not something the game should take
## back when the next chapter starts.
func _season_switcher() -> Control:
	if GameData.seasons.size() < 2:
		return null
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in GameData.seasons:
		var id := str(entry.get("id", ""))
		var b := UI.quiet_button(GameData.text(entry.get("title", "")), UI.SMALL)
		if id == _season_id:
			b.add_theme_color_override("font_color", Pal.c("ink"))
		else:
			b.pressed.connect(func(): go("postcards", {"season": id}))
		row.add_child(b)
	return row


func _caption(have: int, total: int) -> Control:
	var row := UI.hbox(10)
	row.add_child(UI.label_small(GameData.season_label(_season_id), "accent"))
	row.add_child(UI.grow())
	row.add_child(UI.label_small("%d / %d" % [have, total], "ink_faint"))
	return row


func _earned_in(city_ids: Array) -> Array:
	var out: Array = []
	for id in city_ids:
		if SaveGame.has_postcard(str(id)):
			out.append(str(id))
	return out


func _controls(city_ids: Array, earned: Array) -> Control:
	var col := UI.vbox(10)

	var buttons: Array[Control] = []
	if _has_opening:
		var first := UI.button(tr("The First One"), _selected == OPENING)
		first.pressed.connect(func(): _select(OPENING))
		buttons.append(first)
	for id in city_ids:
		var city_id := str(id)
		var have := city_id in earned
		var b := UI.button(GameData.text(GameData.city(city_id).get("name", "?")),
				_selected == city_id)
		b.disabled = not have
		if have:
			b.pressed.connect(func(): _select(city_id))
		buttons.append(b)
	col.add_child(UI.chip_rows(buttons,
			buttons.size() if not is_narrow() else maxi(2, int(column_width() / 116.0))))

	var actions := UI.hbox(8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	# "Turn over" says an action; it does not say that there is a letter waiting
	# on the other side, which is the only reason to press it.
	_flip_button = UI.button(tr("Read the letter"))
	_flip_button.pressed.connect(_do_flip)
	if _selected != "":
		actions.add_child(_flip_button)
	if _selected != OPENING and _selected != "":
		var send := UI.button(tr("Send to a friend"), true)
		var id := _selected
		send.pressed.connect(func(): go("share", {"city": id}))
		actions.add_child(send)
	col.add_child(actions)
	return col



func _show_face() -> void:
	var opening := _selected == OPENING and _has_opening
	_opening.visible = opening
	# Nothing to show is a real state — a season whose cards are all still to be
	# earned. Drawing an empty postcard for it looked like a bug.
	_card.visible = not opening and _selected != ""
	if _card.visible:
		_card.setup(_selected, "", "", "")
	if _empty != null:
		_empty.visible = not opening and _selected == ""


## Cards arrive rather than appear: a short rise and settle, which is most of
## why the moment reads as receiving something rather than opening a menu.
func _play_entry() -> void:
	_stage.pivot_offset = _stage.size * 0.5
	var rest := _stage.position.y
	_stage.modulate.a = 0.0
	_stage.scale = Vector2(0.965, 0.965)
	_stage.position.y = rest + 14.0
	var tw := create_tween()
	tw.tween_property(_stage, "modulate:a", 1.0, RISE * 0.7)
	tw.parallel().tween_property(_stage, "scale", Vector2.ONE, RISE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_stage, "position:y", rest, RISE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Swapping cards keeps the arrival: the old one fades, the new one rises.
func _select(card_id: String) -> void:
	if _busy or card_id == _selected:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_stage, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): go("postcards", {"card": card_id}))


## A flat card turning: squash to nothing on X, swap the face, open out again.
func _do_flip() -> void:
	if _busy:
		return
	_busy = true
	# At the start of the turn, not at the halfway swap: paper makes its noise
	# while it is moving, and the swap is the one instant the card is invisible.
	Sfx.play("flip")
	_stage.pivot_offset = _stage.size * 0.5
	var tw := create_tween()
	tw.tween_property(_stage, "scale:x", 0.0, FLIP).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_swap_face)
	tw.tween_property(_stage, "scale:x", 1.0, FLIP).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _busy = false)


func _swap_face() -> void:
	if _selected == OPENING:
		_opening.face = "front" if _opening.face == "back" else "back"
		_flip_button.text = tr("Read the note") if _opening.face == "front" \
				else tr("See the front")
	else:
		_card.flip()
		_flip_button.text = tr("Read the note") if _card.face == "front" \
				else tr("See the picture")
