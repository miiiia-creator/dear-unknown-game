extends Control
## Router + chrome. Owns the background, the screen stack and the toast layer.

const SCREENS := {
	"menu": preload("res://scripts/screens/main_menu.gd"),
	"map": preload("res://scripts/screens/world_map.gd"),
	"city": preload("res://scripts/screens/city_screen.gd"),
	"puzzle": preload("res://scripts/screens/puzzle_screen.gd"),
	"journal": preload("res://scripts/screens/journal_screen.gd"),
	"postcards": preload("res://scripts/screens/postcards_screen.gd"),
	"passport": preload("res://scripts/screens/passport_screen.gd"),
	"settings": preload("res://scripts/screens/settings_screen.gd"),
	"share": preload("res://scripts/screens/share_screen.gd"),
	"city_complete": preload("res://scripts/screens/city_complete_screen.gd"),
}

## Which nav section each screen belongs to, for the persistent bar's highlight.
const SECTION := {
	"map": "map", "city": "map", "puzzle": "map", "city_complete": "map",
	"journal": "journal",
	"postcards": "postcards", "share": "postcards",
	"passport": "passport",
	"settings": "settings",
}

## Where "up" goes from each screen. A hub-and-spoke app has a real hierarchy,
## so declaring the parent beats guessing from a visit history.
const PARENT := {
	"puzzle": "city", "city": "map", "city_complete": "map",
	"share": "postcards",
}

const NAV_HEIGHT := 52.0

var _bg: ColorRect
var _nav: Control
var _host: Control
var _toasts: VBoxContainer
var _current: AppScreen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Pal.c("bg")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_host)

	_nav = Control.new()
	_nav.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_nav.custom_minimum_size = Vector2(0, NAV_HEIGHT)
	_nav.offset_bottom = NAV_HEIGHT
	add_child(_nav)

	# Bottom-anchored so a toast never lands on the screen title.
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toasts.offset_top = -140
	_toasts.offset_bottom = -18
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	Pal.theme_changed.connect(_on_theme_changed)
	SaveGame.achievement_unlocked.connect(_on_achievement)
	get_tree().root.size_changed.connect(_on_window_resized)
	_apply_content_scale()

	go("menu")

	if "--tour" in OS.get_cmdline_user_args():
		var tour: Node = load("res://scripts/tools/screen_tour.gd").new()
		add_child(tour)
		tour.run(self)


## Stretch is disabled so the viewport reports real space.
##
## Desktop windows are already in points, so 1:1 is correct there — scaling by
## raw DPI would shrink the usable width and fire the phone breakpoints on a
## Retina laptop. Only handheld screens, which hand us a pixel-sized window,
## need dividing down to points.
func _apply_content_scale() -> void:
	var factor := 1.0
	if OS.has_feature("mobile"):
		factor = clampf(DisplayServer.screen_get_scale(), 1.0, 3.0)
	get_window().content_scale_factor = factor


var _relayout_pending := false


func _on_window_resized() -> void:
	# Breakpoints (nav labels, grid columns, stacked forms) are decided at build
	# time, so a resize past one needs a rebuild. Deferred to coalesce the burst
	# of resize events you get while dragging a window edge.
	if _relayout_pending or _current == null:
		return
	_relayout_pending = true
	_do_relayout.call_deferred()


func _do_relayout() -> void:
	_relayout_pending = false
	if _current == null:
		return
	# Never yank a puzzle out from under the player: the board redraws itself.
	if current_screen_name() == "puzzle":
		_build_nav("puzzle")
		return
	_swap(current_screen_name(), _current.args, false)


func _on_theme_changed() -> void:
	_bg.color = Pal.c("bg")
	if _current:
		# Cheapest correct re-skin: rebuild the screen with the new palette.
		var name: String = _current.get_meta("screen_name", "menu")
		var a: Dictionary = _current.args
		_swap(name, a, false)


# -- routing ---------------------------------------------------------------

func go(screen: String, args: Dictionary = {}) -> void:
	if _current and not _current.can_leave():
		return
	_swap(screen, args, true)


## Alias kept for readability at call sites that mean "move on", not "drill in".
func replace(screen: String, args: Dictionary = {}) -> void:
	_swap(screen, args, true)


## Up one level, following the declared hierarchy. Screens that need to carry
## an argument upwards (a puzzle knows its city) supply it via parent_args().
func back() -> void:
	var here := current_screen_name()
	var target: String = PARENT.get(here, "menu")
	var up_args: Dictionary = _current.parent_args() if _current else {}
	_swap(target, up_args, true)


func _swap(screen: String, args: Dictionary, animate: bool) -> void:
	if not SCREENS.has(screen):
		push_error("Unknown screen: " + screen)
		return
	if _current:
		_current.queue_free()
		_current = null

	var node: AppScreen = SCREENS[screen].new()
	node.set_meta("screen_name", screen)
	node.app = self
	node.args = args
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(node)
	node.build()
	_current = node

	_build_nav(screen)

	if animate:
		node.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.16)


# -- persistent navigation -------------------------------------------------

func _build_nav(screen: String) -> void:
	for child in _nav.get_children():
		child.queue_free()

	# The title screen is its own navigation; a bar on top of it is noise.
	var visible_here := screen != "menu"
	_nav.visible = visible_here
	_host.offset_top = NAV_HEIGHT if visible_here else 0.0
	if not visible_here:
		return

	var plate := ColorRect.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.color = Pal.c("panel")
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.add_child(plate)

	var rule := ColorRect.new()
	rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rule.color = Pal.c("line")
	rule.custom_minimum_size = Vector2(0, 1)
	rule.offset_top = -1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav.add_child(rule)

	var row := UI.hbox(4)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	_nav.add_child(row)

	var home := UI.quiet_button("✈  Dear, Unknown", UI.SMALL)
	home.pressed.connect(func(): go("menu"))
	row.add_child(home)
	row.add_child(UI.grow())

	var here: String = SECTION.get(screen, "")
	for entry in [["🗺", "Map", "map"], ["📖", "Journal", "journal"],
			["📮", "Postcards", "postcards"], ["🛂", "Passport", "passport"],
			["⚙", "Settings", "settings"]]:
		var section: String = entry[2]
		var active := section == here
		# Narrow windows drop the words and keep the icons.
		var wide := size.x > 720.0
		var b := UI.quiet_button(("%s  %s" % [entry[0], entry[1]]) if wide else entry[0],
				UI.SMALL)
		if active:
			b.add_theme_color_override("font_color", Pal.c("accent"))
		b.pressed.connect(func(): go(section))
		row.add_child(b)


func current_screen_name() -> String:
	return _current.get_meta("screen_name", "") if _current else ""


# -- toasts ----------------------------------------------------------------

func toast(text: String, sub: String = "") -> void:
	var box := UI.panel(10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(2)
	v.add_child(UI.label(text, UI.BODY, "ink", HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		v.add_child(UI.label(sub, UI.SMALL, "ink_soft", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(v)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(box)

	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


func _on_achievement(id: String, title: String) -> void:
	toast("🏆  " + title, SaveGame.ACHIEVEMENTS[id]["desc"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_screen_name() != "menu":
			back()
			get_viewport().set_input_as_handled()
