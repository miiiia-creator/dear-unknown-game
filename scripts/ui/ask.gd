class_name Ask
extends Control
## The one question the game ever asks, and it asks it on paper.
##
## This used to be Godot's ConfirmationDialog, which arrives in the engine's own
## theme: dark plate, white lettering, square buttons, a system title bar with a
## close cross. Every other surface in the game is a sheet of paper on a desk,
## and the one moment the game asks whether you are sure looked like it belonged
## to a different program — which is exactly the moment you want somebody to
## trust what they are reading.
##
## Built as a Control rather than a Window for the same reason the screens are:
## a subwindow is sized and placed by the platform, and on a phone it was being
## centred at a width wider than the screen it was centred in.

signal confirmed

const BACKDROP := Color(0.04, 0.04, 0.045, 0.88)


static func open(host: Control, title: String, body: String,
		yes: String, no: String = "") -> Ask:
	var ask := Ask.new()
	host.add_child(ask)
	# Built after it is in the tree: it measures the viewport, and `tr` is not
	# available from a static function.
	ask._build(title, body, yes, no if no != "" else ask.tr("Cancel"))
	return ask


func _build(title: String, body: String, yes: String, no: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = BACKDROP
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := UI.panel(6)
	# Never wider than the screen it is being centred in, which is the whole
	# reason this exists.
	panel.custom_minimum_size = Vector2(
			minf(420.0, get_viewport_rect().size.x - 32.0), 0)
	centre.add_child(panel)

	var column := UI.vbox(12)
	panel.add_child(column)
	column.add_child(UI.label(title, UI.H3, "ink"))
	column.add_child(UI.paragraph(body, UI.BODY, "ink_soft"))
	column.add_child(UI.spacer(2))

	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := UI.quiet_button(no, UI.SMALL)
	cancel.pressed.connect(dismiss)
	row.add_child(cancel)
	var go := UI.button(yes, true)
	go.pressed.connect(func():
		confirmed.emit()
		dismiss())
	row.add_child(go)
	column.add_child(row)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.14)


func dismiss() -> void:
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


## The paper around the question means no, the same as it does on a card.
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		dismiss()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()
