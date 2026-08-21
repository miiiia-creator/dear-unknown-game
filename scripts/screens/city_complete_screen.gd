extends AppScreen
## The payoff screen: postcard, passport stamp, next destination unlocked.

## Postcard picture proportion. The artwork brief asks for 3:2 full-bleed, so
## nothing has to be cropped to fit.
const PICTURE_ASPECT := 1.5

var city_id: String
var _title_plate: Control
var _stage: Control
var _front: Control
var _back: PostcardView
var _turn: Button
var _busy := false


func build() -> void:
	city_id = args.get("city", "")
	var city := GameData.city(city_id)
	if city.is_empty():
		go("menu")
		return

	SaveGame.grant_city_rewards(city_id)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := UI.vbox(8)
	column.custom_minimum_size = Vector2(minf(620.0, column_width()), 0)
	centre.add_child(column)

	var progress := GameData.city_progress(city_id)
	# Nothing above the card. It is a postcard arriving, and a heading that
	# announces the achievement and counts the puzzles turns it into a results
	# screen — the card says everything worth saying by being there.
	var card_w := minf(620.0, column_width())
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stage)

	var card := _framed_scene(stage, card_w)
	_stage = stage

	# The letter is what finishing a destination is for, and until now there was
	# no way to reach it from this screen at all — the card showed its picture
	# and the only buttons led somewhere else. A player could finish a city and
	# never learn that anything was written on the back.
	_back = PostcardView.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.face = "back"
	_back.visible = false
	stage.add_child(_back)
	_back.setup(city_id)

	column.add_child(UI.spacer(10))

	_turn = UI.quiet_button(tr("Read the letter"), UI.SMALL)
	_turn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_turn.pressed.connect(_flip)
	column.add_child(_turn)

	column.add_child(UI.spacer(8))

	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER

	var share := UI.button(tr("Send to a friend"), true)
	share.pressed.connect(func(): go("share", {"city": city_id}))
	buttons.add_child(share)

	var next_id := GameData.next_city_id(city_id)
	var onward: Button
	if next_id != "":
		var next_city := GameData.city(next_id)
		onward = UI.button(tr("Continue to %s") % GameData.text(next_city["name"]))
		# Into the next city's card, not its journal: the card is how a city
		# opens now, and the letter on it is the reason to go.
		onward.pressed.connect(func(): go("card", {"city": next_id}))
	else:
		onward = UI.button(tr("Back to the map"))
		onward.pressed.connect(func(): go("map"))
	buttons.add_child(onward)
	column.add_child(buttons)

	if next_id != "":
		column.add_child(UI.spacer(6))
		column.add_child(UI.label(tr("%s unlocked") % GameData.text(GameData.city(next_id)["name"]),
				UI.SMALL, "accent", HORIZONTAL_ALIGNMENT_CENTER))

	_animate(card)


## The picture fills the card and the destination name sits over its lower
## band, the way a printed travel postcard sets its type. The artwork brief
## therefore asks for a calm lower third with nothing important in it.
func _framed_scene(stage: Control, card_w: float) -> PostcardScene:
	var city := GameData.city(city_id)
	var palette := GameData.city_palette(city_id)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = palette[0]
	sb.border_color = palette[2].lerp(palette[0], 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", sb)
	stage.add_child(frame)

	_front = frame

	var scene := PostcardScene.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(scene)
	# In the tree first: setup starts video playback and measures the artwork,
	# neither of which works on a node that is not yet parented.
	scene.setup(city_id)

	# Shape the card to the art so a painted postcard's own printed edge is not
	# cropped off; procedural skies keep the 3:2 default.
	# Fit the card to the screen, not just to its own width: a tall drawing at
	# full width ran off the bottom of the window.
	var aspect: float = scene.art_aspect() if scene.has_art else PICTURE_ASPECT
	var room := get_viewport_rect().size.y * 0.72
	var w := card_w
	if w / aspect > room:
		w = room * aspect
	stage.custom_minimum_size = Vector2(w, w / aspect)

	var plate := Control.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(plate)

	# `w`, not `card_w`: the card is fitted to the screen's height as well as its
	# width, and sizing the name off the width that was asked for rather than
	# the one that was used put it below the bottom edge of the card.
	var card_h := w / aspect

	# Type colour follows the painting, not the palette: a dark canvas needs
	# light lettering and vice versa, and the artwork is the only thing that
	# knows which it is.
	var dark_art := scene.has_art and scene.caption_luma < 0.45
	# The same rules the card itself uses, so the name does not change size or
	# colour depending on which screen you are looking at it from. Sized off the
	# card's short side: taken from the height, a tall card set the name wider
	# than the card and it read as knocked off centre.
	var short_side := minf(w, card_h)
	var type_col := Color(0.97, 0.97, 0.96) if dark_art else Color(0.10, 0.10, 0.10)
	var halo := Color(0, 0, 0, 0.45) if dark_art else Color(1, 1, 1, 0.45)

	var title := UI.label(String(GameData.text(city["name"])).to_upper(),
			int(short_side * 0.135), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", type_col)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", halo)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = card_h - short_side * 0.34
	title.offset_bottom = card_h - short_side * 0.16
	plate.add_child(title)

	var sub := UI.label(String(GameData.text(city["country"])).to_upper(),
			int(short_side * 0.052), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", type_col)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = card_h - short_side * 0.15
	sub.offset_bottom = card_h - short_side * 0.02
	plate.add_child(sub)

	_title_plate = plate
	return scene


func _animate(card: PostcardScene) -> void:
	_title_plate.modulate.a = 0.0

	var tw := card.play(self)
	tw.parallel().tween_property(_title_plate, "modulate:a", 1.0, 0.6).set_delay(1.4)
	tw.tween_interval(0.2)
	# The one loud sound in the game, and it lands here rather than on the
	# postcard's arrival: the card fades in over a second and a half, which is
	# nothing to hit, while the stamp is an impact with an exact moment.
	# No toast to go with it: the card, the title plate and the stamp sound all
	# already say the city is finished, and a notification sliding in over the
	# moment made it feel like an app reporting an achievement.
	tw.tween_callback(func(): Sfx.play("stamp"))
	# It waits to be turned. Turning itself took the moment away from whoever
	# was looking at the picture.


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_flip()
		accept_event()


## A flat card turning: squash to nothing on X, swap the face, open out again.
## The same movement the postcards gallery uses, so the two read as one object.
func _flip() -> void:
	if _busy or _back == null:
		return
	_busy = true
	var showing_back := _back.visible
	_stage.pivot_offset = _stage.size * 0.5
	Sfx.play("flip")
	var tw := create_tween()
	tw.tween_property(_stage, "scale:x", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_back.visible = not showing_back
		_front.visible = showing_back
		_title_plate.visible = showing_back
		_turn.text = tr("See the picture") if not showing_back else tr("Read the letter"))
	tw.tween_property(_stage, "scale:x", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _busy = false)
