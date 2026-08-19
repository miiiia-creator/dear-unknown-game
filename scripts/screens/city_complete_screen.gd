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
	SaveGame.check_achievements()

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := UI.vbox(8)
	column.custom_minimum_size = Vector2(minf(620.0, column_width()), 0)
	centre.add_child(column)

	var progress := GameData.city_progress(city_id)
	column.add_child(UI.label("%s  %s COMPLETE" % [city["flag"],
			String(city["name"]).to_upper()], UI.H2, "ink",
			HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.label("%d / %d discoveries" % [progress.x, progress.y],
			UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UI.spacer(14))

	var card_w := minf(620.0, column_width())
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stage)

	var card := _framed_scene(stage, card_w)

	# Place the stamp against the card's own size, in the quiet lower-right band
	# the artwork leaves free — over the busy part of the picture it just reads
	# as smudge.
	var card_size := stage.custom_minimum_size
	var stamp_size := card_size.y * 0.34
	var stamp := StampView.new()
	stamp.custom_minimum_size = Vector2(stamp_size, stamp_size)
	stamp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Top-right, where a postcard's stamp actually goes, and where the sky gives
	# it a calm ground to sit on.
	stamp.offset_left = card_size.x - stamp_size * 1.22
	stamp.offset_top = stamp_size * 0.18
	stamp.offset_right = stamp.offset_left + stamp_size
	stamp.offset_bottom = stamp.offset_top + stamp_size
	stamp.setup(city_id, -0.16)
	stamp.pivot_offset = Vector2(stamp_size, stamp_size) * 0.5
	stage.add_child(stamp)

	column.add_child(UI.spacer(14))

	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER

	var share := UI.button("📮  Send to a friend", true)
	share.pressed.connect(func(): go("share", {"city": city_id}))
	buttons.add_child(share)

	var passport := UI.button("🛂  Passport")
	passport.pressed.connect(func(): go("passport"))
	buttons.add_child(passport)

	var next_id := GameData.next_city_id(city_id)
	var onward: Button
	if next_id != "":
		var next_city := GameData.city(next_id)
		onward = UI.button("Continue to %s  %s" % [next_city["name"], next_city["flag"]])
		onward.pressed.connect(func(): go("city", {"city": next_id}))
	else:
		onward = UI.button("Back to the map")
		onward.pressed.connect(func(): go("map"))
	buttons.add_child(onward)
	column.add_child(buttons)

	if next_id != "":
		column.add_child(UI.spacer(6))
		column.add_child(UI.label("🔓  %s unlocked" % GameData.city(next_id)["name"],
				UI.SMALL, "accent", HORIZONTAL_ALIGNMENT_CENTER))

	_animate(card, stamp)


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

	var title := UI.label(String(city["name"]).to_upper(),
			int(card_h * 0.115), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", type_col)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", halo)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = card_h * 0.70
	title.offset_bottom = card_h * 0.85
	plate.add_child(title)

	var sub := UI.label("%s  %s" % [city["flag"], String(city["country"]).to_upper()],
			int(card_h * 0.048), "ink", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color",
			type_col.darkened(0.10) if dark_art else palette[1].darkened(0.15))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = card_h * 0.855
	sub.offset_bottom = card_h * 0.93
	plate.add_child(sub)

	_title_plate = plate
	return scene


func _animate(card: PostcardScene, stamp: StampView) -> void:
	_title_plate.modulate.a = 0.0
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(2.4, 2.4)

	var tw := card.play(self)
	tw.parallel().tween_property(_title_plate, "modulate:a", 1.0, 0.6).set_delay(1.4)
	tw.tween_interval(0.15)
	tw.tween_callback(func(): app.toast("🛂  STAMP!", GameData.city(city_id)["name"]))
	tw.parallel().tween_property(stamp, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
