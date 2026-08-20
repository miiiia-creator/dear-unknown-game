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
var _busy := false


func build() -> void:
	var season := GameData.season(str(args.get("season", "")))
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
	col.add_child(_picker_rows(buttons))

	var actions := UI.hbox(8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_flip_button = UI.button(tr("Turn over"))
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



## A season plus its opening card is six buttons, and six do not fit across a
## phone. They used to sit in one row regardless — and because a container is
## never smaller than its contents, that row's width became the width of
## everything above it, which is what pushed the card itself off the screen.
## Wrapping is the fix and it is also the better answer: a row you have to
## scroll hides destinations, and this screen is the one place the season is
## laid out whole.
func _picker_rows(buttons: Array[Control]) -> Control:
	var per_row := buttons.size()
	if is_narrow():
		per_row = maxi(2, int(column_width() / 116.0))

	var rows := UI.vbox(6)
	var row: HBoxContainer = null
	for i in buttons.size():
		if row == null or row.get_child_count() >= per_row:
			row = UI.hbox(6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			rows.add_child(row)
		row.add_child(buttons[i])
	return rows


func _show_face() -> void:
	var opening := _selected == OPENING and _has_opening
	_opening.visible = opening
	_card.visible = not opening
	if not opening:
		_card.setup(_selected, "", "", "")


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
