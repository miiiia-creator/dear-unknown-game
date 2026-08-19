class_name AppScreen
extends Control
## Base class for every screen. Main creates one, hands it `app` and `args`,
## then calls build().

const MAX_WIDTH := 980.0

var app: Node
var args: Dictionary = {}


func build() -> void:
	pass


## Screens that own a running timer or unsaved state override this.
func can_leave() -> bool:
	return true


## What the parent screen needs to rebuild itself — a puzzle hands its city up.
func parent_args() -> Dictionary:
	return {}


## Page gutter. A 36pt margin is generous on a laptop and wasteful on a phone,
## where it eats a sixth of the screen.
func page_margin() -> float:
	return 14.0 if get_viewport_rect().size.x < 620.0 else 36.0


## Content width, capped but never wider than what the margins actually leave.
## These two used to disagree — the column asked for viewport minus 48 while the
## scaffold reserved 72 — so every page overflowed by 24pt. On a desktop the
## 980pt cap hid it; on a phone it clipped the right-hand edge off everything.
func column_width() -> float:
	return minf(MAX_WIDTH, get_viewport_rect().size.x - page_margin() * 2.0)


func is_narrow() -> bool:
	return get_viewport_rect().size.x < 620.0


## How many tiles fit across at the current width, so phones get fewer columns.
func columns_for(min_tile: float, most: int = 4) -> int:
	return clampi(int(column_width() / min_tile), 1, most)


func go(screen: String, next_args: Dictionary = {}) -> void:
	app.go(screen, next_args)


func replace(screen: String, next_args: Dictionary = {}) -> void:
	app.replace(screen, next_args)


func back() -> void:
	app.back()


## Standard sub-page layout: back link, title, scrolling body.
## Returns the VBox callers should fill.
func scaffold(title_text: String, subtitle: String = "") -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, gutter)
	margin.add_theme_constant_override("margin_top", 16 if is_narrow() else 26)
	margin.add_theme_constant_override("margin_bottom", 16 if is_narrow() else 26)
	add_child(margin)

	# Centred with side spacers rather than a CenterContainer: CenterContainer
	# shrinks its child to minimum size, which collapses the scroll area to zero.
	var centre := UI.hbox(0)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(centre)
	centre.add_child(UI.grow())

	var column := UI.vbox(14)
	column.custom_minimum_size = Vector2(column_width(), 0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(column)
	centre.add_child(UI.grow())

	# The nav bar covers the top-level sections, so only show a back link where
	# there is a real parent to go up to.
	var here: String = get_meta("screen_name", "")
	if app.PARENT.has(here):
		var up: String = app.PARENT[here]
		var back_btn := UI.quiet_button("←  %s" % up.capitalize(), UI.SMALL)
		back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back_btn.pressed.connect(back)
		column.add_child(back_btn)

	column.add_child(UI.label(title_text, UI.H2, "ink"))
	if subtitle != "":
		column.add_child(UI.paragraph(subtitle, UI.BODY, "ink_soft"))
	column.add_child(UI.hrule())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var body := UI.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body
