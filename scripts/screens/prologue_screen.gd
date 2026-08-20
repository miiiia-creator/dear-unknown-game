extends AppScreen
## The first thing a new player sees: a postcard from M, and one destination.
##
## It runs before the title screen rather than after it, because the premise —
## somebody is writing to a person they cannot find — is what makes solving the
## first grid mean anything. A menu first would make it a puzzle app with a
## story bolted on.

var _card: OpeningCardView
var _start: Control


func build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := UI.vbox(0)
	column.custom_minimum_size = Vector2(minf(540.0, column_width()), 0)
	centre.add_child(column)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, minf(540.0, column_width()) / 1.5)
	column.add_child(stage)

	_card = OpeningCardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_card)

	column.add_child(UI.spacer(28))

	# The single destination under the card. One choice is not a menu; it is an
	# instruction, which is what a player needs at this moment.
	var first: Dictionary = GameData.cities[0] if not GameData.cities.is_empty() else {}
	_start = UI.vbox(2)
	_start.modulate.a = 0.0
	column.add_child(_start)

	var go_btn := UI.quiet_button(GameData.text(first.get("name", "")), UI.H2)
	go_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_btn.pressed.connect(_begin)
	_start.add_child(go_btn)
	_start.add_child(UI.label(GameData.text(first.get("country", "")).to_upper(),
			UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER))

	_play()


func _play() -> void:
	_card.modulate.a = 0.0
	_card.face = "front"
	_card.dots = 0.0
	_card.note = 0.0

	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	tw.tween_property(_card, "dots", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.7)
	# A 2D flip: squash to nothing, swap the face, open again.
	tw.tween_callback(func(): Sfx.play("flip"))
	tw.tween_property(_card, "scale:x", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_card.face = "back"
		_card.pivot_offset = Vector2(_card.size.x * 0.5, 0.0))
	tw.tween_property(_card, "scale:x", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_card, "note", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(_start, "modulate:a", 1.0, 0.9)


func _ready() -> void:
	# The card is centred, so it should flip about its middle.
	await get_tree().process_frame
	if _card:
		_card.pivot_offset = Vector2(_card.size.x * 0.5, 0.0)


func _begin() -> void:
	var first: Dictionary = GameData.cities[0] if not GameData.cities.is_empty() else {}
	var puzzles: Array = first.get("puzzles", [])
	if puzzles.is_empty():
		go("menu")
		return
	go("puzzle", {"puzzle": puzzles[0]["id"]})


## Skip on a tap or a key, the way you can skip any opening.
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	if _start.modulate.a < 1.0:
		_card.modulate.a = 1.0
		_card.face = "back"
		_card.dots = 1.0
		_card.note = 1.0
		_card.scale.x = 1.0
		_start.modulate.a = 1.0
		accept_event()
