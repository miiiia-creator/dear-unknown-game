extends AppScreen
## Spike. One 5x5x5 block, to find out whether a solid can be solved with one
## thumb on a phone held upright.
##
## Not wired into the game: reached by `?solid` in the browser or `-- --solid`
## on the desktop, and it touches no save data. The question it exists to answer
## is not "does this work" — the model has tests — but "is this any good", which
## nothing but a thumb can answer.

const SHAPE := [
	# A chair, five cubes on a side. Bottom layer first.
	["#####", "#####", "#####", "#####", "#####"],
	["#####", "#####", "#####", "#####", "#####"],
	["#####", "#...#", "#...#", "#...#", "#...#"],
	["#####", "#...#", "....#", "....#", "#...#"],
	["#####", ".....", ".....", ".....", "....."],
]

var _solid: Solid
var _view: SolidView
var _marking := false
var _status: Label
var _mode: Button


func build() -> void:
	_solid = Solid.new(SHAPE)

	# The block gets the screen. It was in a panel under a heading and three
	# lines of explanation, which left it a third of a phone — and an isometric
	# top face is only a quarter as tall as it is wide, so a cell was six points
	# high and the numbers on it could not be read at all.
	var root := UI.vbox(8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gutter := int(page_margin())
	root.offset_left = gutter
	root.offset_right = -gutter
	root.offset_top = 6
	root.offset_bottom = -gutter
	add_child(root)

	var bar := UI.hbox(12)
	var out := UI.quiet_button(tr("Journal"), UI.SMALL)
	out.pressed.connect(func(): go("journal"))
	bar.add_child(out)
	bar.add_child(UI.label(tr("A solid"), UI.H3, "ink"))
	bar.add_child(UI.grow())
	_status = UI.label("", UI.SMALL, "ink_faint")
	bar.add_child(_status)
	root.add_child(bar)
	root.add_child(UI.hrule())

	_view = SolidView.new()
	_view.puzzle = _solid
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.cube_picked.connect(_touch)
	_view.cube_marked.connect(_note)
	root.add_child(_view)

	var tools := UI.hbox(8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_mode = UI.button(tr("Chisel"), true)
	_mode.custom_minimum_size = Vector2(104, 44)
	_mode.pressed.connect(func():
		_marking = not _marking
		_mode.text = tr("Keep") if _marking else tr("Chisel")
		UI.restyle_button(_mode, not _marking))
	tools.add_child(_mode)
	for entry in [["\u21b6", -1], ["\u21b7", 1]]:
		var b := UI.button(str(entry[0]))
		b.custom_minimum_size = Vector2(56, 44)
		var by: int = entry[1]
		b.pressed.connect(func(): _view.rotate_by(by))
		tools.add_child(b)
	var over := UI.button(tr("Flip"))
	over.custom_minimum_size = Vector2(70, 44)
	over.pressed.connect(func(): _view.flip())
	tools.add_child(over)
	root.add_child(tools)
	_report()


func _touch(cell: Vector3i) -> void:
	if _marking:
		_note(cell)
		return
	if _solid.chisel(cell):
		Sfx.play("mark")
	else:
		Sfx.play("locked")
	_report()


func _note(cell: Vector3i) -> void:
	if _solid.mark(cell):
		Sfx.play("fill")
	_report()


func _report() -> void:
	_view.queue_redraw()
	if _solid.solved():
		_status.text = tr("Found it — %d mistakes") % _solid.mistakes
		Sfx.play("solved")
		return
	var left := 0
	for y in _solid.size.y:
		for z in _solid.size.z:
			for x in _solid.size.x:
				var c := Vector3i(x, y, z)
				if _solid.present(c) and not _solid.solid_at(c):
					left += 1
	_status.text = tr("%d to go · %d mistakes") % [left, _solid.mistakes]
