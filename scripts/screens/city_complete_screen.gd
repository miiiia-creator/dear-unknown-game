extends AppScreen
## The payoff screen: postcard, passport stamp, next destination unlocked.

## Postcard picture proportion. The artwork brief asks for 3:2 full-bleed, so
## nothing has to be cropped to fit.
const PICTURE_ASPECT := 1.5

var city_id: String
var _title_plate: Control


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
	column.add_child(UI.label(tr("%s COMPLETE") % String(GameData.text(city["name"])).to_upper(),
			UI.H2, "ink", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.label(tr("%d / %d discoveries") % [progress.x, progress.y],
			UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(14))

	var card_w := minf(620.0, column_width())
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stage)

	var card := _framed_scene(stage, card_w)

	column.add_child(UI.spacer(14))

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
		onward.pressed.connect(func(): go("journal", {"city": next_id}))
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

	var scene := PostcardScene.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(scene)
	# In the tree first: setup starts video playback and measures the artwork,
	# neither of which works on a node that is not yet parented.
	scene.setup(city_id)

	# Shape the card to the art so a painted postcard's own printed edge is not
	# cropped off; procedural skies keep the 3:2 default.
	var aspect: float = scene.art_aspect() if scene.has_art else PICTURE_ASPECT
	stage.custom_minimum_size = Vector2(card_w, card_w / aspect)

	var plate := Control.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(plate)

	var card_h := card_w / aspect

	# Type colour follows the painting, not the palette: a dark canvas needs
	# light lettering and vice versa, and the artwork is the only thing that
	# knows which it is.
	var dark_art := scene.has_art and scene.caption_luma < 0.45
	var type_col: Color = palette[0].lightened(0.55) if dark_art else palette[2]
	var halo: Color = Color(0, 0, 0, 0.55) if dark_art else Color(palette[0], 0.55)

	var title := UI.label(String(GameData.text(city["name"])).to_upper(),
			int(card_h * 0.115), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", type_col)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", halo)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = card_h * 0.70
	title.offset_bottom = card_h * 0.85
	plate.add_child(title)

	var sub := UI.label(String(GameData.text(city["country"])).to_upper(),
			int(card_h * 0.048), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color",
			type_col.darkened(0.10) if dark_art else palette[1].darkened(0.15))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = card_h * 0.855
	sub.offset_bottom = card_h * 0.93
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
