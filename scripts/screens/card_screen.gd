extends AppScreen
## A city's card, and the way into its puzzles.
##
## A blank card with one point of light on it. Touch the light and the first
## grid opens; solving it leaves its picture on the card and lights the next
## point, so the card develops as the city is worked through — the postcard is
## the level select, and filling it in is the progress bar.
##
## One face, and it does not turn. The card used to arrive letter-side up and
## turn over on a tap, which meant the whole letter was sitting there before a
## single grid had been solved — the ending on the page from the first move,
## and the journal's own rule is that a letter stays sealed until its city is
## finished. It arrives where it is earned: on the finishing screen, and on the
## back of the card in Postcards afterwards. Here there is only the picture,
## developing.

const SLOT_RISE := 0.5

## This screen paints its own dark room over whatever the page is, so its type
## is picked for that room rather than from the palette — `ink_faint` reads on
## paper and disappears into the backdrop in the evening.
const ON_DARK := Color(0.72, 0.72, 0.70)

var city_id: String
var _stage: Control
var _back: CardBack


## Back goes to the journal with this destination open, rather than to whichever
## one the save happens to think is current.
func parent_args() -> Dictionary:
	return {"city": city_id}


func build() -> void:
	city_id = args.get("city", GameData.current_city_id())

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	root.offset_left = gutter
	root.offset_right = -gutter
	root.offset_top = 8
	root.offset_bottom = -gutter
	add_child(root)

	# Everything but the card goes dark, so looking at one feels like holding it
	# up rather than reading a page that happens to have a card on it.
	var _backdrop := ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.04, 0.045, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, 0)

	# A way back, for anyone who looks for one at the top of a page. The way
	# most people will actually leave is by pressing the dark around the card:
	# the screen holds a card up out of the page, so putting it down is what a
	# press on the page means.
	var top := UI.hbox(0)
	# Only the link takes a press; the rest of the strip is still card.
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var out := UI.quiet_button(tr("Journal"), UI.SMALL)
	out.add_theme_color_override("font_color", ON_DARK)
	out.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	out.pressed.connect(back)
	top.add_child(out)
	root.add_child(top)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_stage)

	_back = CardBack.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.city_id = city_id
	_back._measure()
	_back.slot_picked.connect(_open)
	_back.dismissed.connect(back)
	_stage.add_child(_back)
	_back.play_arrival()

	root.add_child(UI.spacer(10))
	root.add_child(_hint())


func _hint() -> Control:
	var text := tr("Tap the light")
	if _next_puzzle() == "":
		text = ""
	var label := UI.label(text, UI.SMALL, "ink_faint", HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_color", ON_DARK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _next_puzzle() -> String:
	for p in GameData.puzzles_of(city_id):
		if not SaveGame.is_solved(p["id"]):
			return p["id"]
	return ""


## The strips above and below the card, which the card's own control does not
## cover. Same meaning as the dark beside it: put the card down.
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		back()


func _open(puzzle_id: String) -> void:
	go("puzzle", {"puzzle": puzzle_id})
