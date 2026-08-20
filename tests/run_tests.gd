extends SceneTree
## Headless tests for the pure-logic classes.
##
##   godot --headless --script tests/run_tests.gd
##
## Runs without autoloads, so it only covers Nonogram and ShareCode. Content
## validation (unique solutions) lives in tools/build_content.py.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_clues()
	test_editing()
	test_hint_and_completion()
	test_line_satisfied()
	test_save_restore()
	test_share_round_trip()
	test_share_rejects_garbage()
	test_sound_wiring()

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok   ", label)
	else:
		_failed += 1
		print("  FAIL ", label)


func equal(label: String, actual: Variant, expected: Variant) -> void:
	check("%s  (got %s, want %s)" % [label, actual, expected] if actual != expected
			else label, actual == expected)


# --------------------------------------------------------------------------

const ART := [
	"..#..",
	".###.",
	".###.",
	"#####",
	"#####",
]


func test_clues() -> void:
	print("\nclues")
	var n := Nonogram.new(ART)
	equal("width", n.width, 5)
	equal("height", n.height, 5)
	equal("row 0", n.row_clues[0], [1])
	equal("row 3", n.row_clues[3], [5])
	equal("col 0", n.col_clues[0], [2])
	equal("col 2", n.col_clues[2], [5])
	equal("total filled", n.total_filled(), 1 + 3 + 3 + 5 + 5)

	equal("gap clue", Nonogram.clues_of([1, 0, 1, 1, 0, 1]), [1, 2, 1])
	equal("empty line reads as 0", Nonogram.clues_of([0, 0, 0]), [0])


func test_editing() -> void:
	print("\nediting")
	var n := Nonogram.new(ART)

	n.begin_stroke()
	n.set_cell(0, 2, Nonogram.FILLED)
	n.set_cell(1, 1, Nonogram.FILLED)
	n.end_stroke()
	equal("stroke applied", n.filled_count(), 2)

	check("undo available", n.can_undo())
	n.undo()
	equal("one undo reverts the whole stroke", n.filled_count(), 0)
	check("stack is empty again", not n.can_undo())

	n.begin_stroke()
	n.set_cell(0, 2, Nonogram.FILLED)
	check("re-setting the same value is a no-op",
			not n.set_cell(0, 2, Nonogram.FILLED))
	n.end_stroke()

	n.reset()
	equal("reset clears the board", n.filled_count(), 0)
	check("reset clears undo", not n.can_undo())

	check("out of bounds is refused", not n.set_cell(-1, 0, Nonogram.FILLED))
	check("out of bounds is refused (high)", not n.set_cell(0, 99, Nonogram.FILLED))


func test_hint_and_completion() -> void:
	print("\nhints and completion")
	var n := Nonogram.new(ART)
	check("empty board is not complete", not n.is_complete())

	var guard := 0
	while not n.is_complete() and guard < 200:
		n.take_hint()
		guard += 1
	check("hints alone finish the puzzle", n.is_complete())
	equal("hint count tracked", n.hints_used, guard)

	# A board filled everywhere is wrong, not complete.
	var m := Nonogram.new(ART)
	for r in m.height:
		for c in m.width:
			m.set_cell(r, c, Nonogram.FILLED)
	check("over-filled board is not complete", not m.is_complete())
	equal("mistakes are reported", m.mistakes().size(),
			m.width * m.height - m.total_filled())

	# Marks must not count towards completion.
	var k := Nonogram.new(ART)
	for r in k.height:
		for c in k.width:
			k.set_cell(r, c, Nonogram.FILLED if k.solution[r][c] == 1 else Nonogram.MARKED)
	check("marks do not block completion", k.is_complete())


func test_line_satisfied() -> void:
	print("\ncrossing off finished lines")
	var n := Nonogram.new(ART)
	check("nothing satisfied on an empty board", not n.row_satisfied(3))

	# Row 3 is "#####" — fill it.
	for c in n.width:
		n.set_cell(3, c, Nonogram.FILLED)
	check("full row matches its clue", n.row_satisfied(3))

	# Row 0 is "..#.." — clue [1]. Any single cell satisfies the numbers, even
	# in the wrong column. That is the documented local-only behaviour.
	n.set_cell(0, 0, Nonogram.FILLED)
	check("a misplaced single still satisfies clue [1]", n.row_satisfied(0))
	n.set_cell(0, 1, Nonogram.FILLED)
	check("two adjacent cells no longer match clue [1]", not n.row_satisfied(0))

	# Marks must not count as filled.
	var m := Nonogram.new(ART)
	for c in m.width:
		m.set_cell(3, c, Nonogram.MARKED)
	check("marks do not satisfy a line", not m.row_satisfied(3))

	var k := Nonogram.new(ART)
	for r in k.height:
		if k.solution[r][2] == 1:
			k.set_cell(r, 2, Nonogram.FILLED)
	check("column 2 satisfied when filled correctly", k.col_satisfied(2))


func test_save_restore() -> void:
	print("\nin-progress save")
	var n := Nonogram.new(ART)
	n.set_cell(0, 2, Nonogram.FILLED)
	n.set_cell(1, 0, Nonogram.MARKED)
	var flat := n.to_flat()
	equal("flat string length", flat.length(), n.width * n.height)

	var restored := Nonogram.new(ART)
	check("apply_flat accepts a matching grid", restored.apply_flat(flat))
	equal("filled cell restored", restored.get_cell(0, 2), Nonogram.FILLED)
	equal("marked cell restored", restored.get_cell(1, 0), Nonogram.MARKED)
	equal("untouched cell restored", restored.get_cell(4, 4), Nonogram.EMPTY)
	equal("round trip is identical", restored.to_flat(), flat)

	check("undo does not reach across a restore", not restored.can_undo())

	# A grid saved against different art must be refused, not misapplied.
	var bigger := Nonogram.new([
		"..........", "..........", "..........", "..........", "..........",
		"..........", "..........", "..........", "..........", "..#.......",
	])
	check("mismatched grid is rejected", not bigger.apply_flat(flat))
	check("garbage is rejected", not restored.apply_flat("nonsense"))


func test_share_round_trip() -> void:
	print("\nshare codes")
	var code := ShareCode.build("tokyo", "tokyo_torii",
			"Wish you were here — 東京は最高だった！", "Mia", "Sam")
	check("code is url-safe",
			not ("+" in code or "/" in code or "=" in code or " " in code))

	var back := ShareCode.decode(code)
	equal("version", back.get("v"), 1)
	equal("city", back.get("c"), "tokyo")
	equal("puzzle", back.get("p"), "tokyo_torii")
	equal("message survives unicode", back.get("m"),
			"Wish you were here — 東京は最高だった！")
	equal("from", back.get("f"), "Mia")
	equal("to", back.get("t"), "Sam")

	equal("url has the code in the fragment", ShareCode.url_for(code),
			ShareCode.BASE_URL + "#" + code)

	# Whitespace from a sloppy copy-paste must not break decoding.
	equal("padded code still decodes", ShareCode.decode("  " + code + "\n").get("c"),
			"tokyo")


func test_share_rejects_garbage() -> void:
	print("\nbad share codes")
	check("empty string", ShareCode.decode("").is_empty())
	check("not base64", ShareCode.decode("!!!!").is_empty())
	check("base64 but not json", ShareCode.decode(
			Marshalls.utf8_to_base64("hello")).is_empty())
	check("json but not a postcard", ShareCode.decode(
			Marshalls.utf8_to_base64('{"hello":1}')).is_empty())
	check("a whole url decodes", ShareCode.decode(
			ShareCode.url_for(ShareCode.build("rome", "rome_pizza", "", "", "")))
			.get("c") == "rome")


## Sfx.play() takes a string, so a typo is silent until someone plays that far
## into the game and notices nothing happened. This walks the source instead:
## every name the screens ask for has to exist in the bank, and every entry in
## the bank has to have a clip behind it.
##
## It reads the constant off the script rather than instantiating the autoload,
## which is what lets it run in this file's no-autoload world.
func test_sound_wiring() -> void:
	print("\nsound wiring")
	var script: GDScript = load("res://scripts/autoload/audio.gd")
	var bank: Dictionary = script.get_script_constant_map().get("BANK", {})
	check("the bank has sounds in it", not bank.is_empty())

	for name in bank.keys():
		var clips: Array = bank[name]["clips"]
		var ok := not clips.is_empty()
		for clip in clips:
			ok = ok and clip is AudioStream
		check("%s has clips" % name, ok)

	var used := _sounds_asked_for("res://scripts")
	check("the game asks for sounds at all", used.size() > 4)
	for name in used:
		check("Sfx.play(\"%s\") exists" % name, bank.has(name))


## Every literal name passed to Sfx.play() anywhere under a directory.
##
## Line-based rather than a match on the whole call, because half the call sites
## choose their sound inline — `Sfx.play("fill" if filling else "mark")` — and a
## regex tight enough to exclude the docstring in audio.gd would miss both of
## the names in that line. Comment lines are skipped for the same reason.
func _sounds_asked_for(dir_path: String) -> Array:
	var re := RegEx.new()
	re.compile("\"([a-z_]+)\"")
	var found: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := dir_path + "/" + entry
		if dir.current_is_dir():
			for name in _sounds_asked_for(path):
				if not name in found:
					found.append(name)
		elif entry.ends_with(".gd"):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				for line in f.get_as_text().split("\n"):
					if not "Sfx.play(" in line or line.strip_edges().begins_with("#"):
						continue
					for m in re.search_all(line):
						if not m.get_string(1) in found:
							found.append(m.get_string(1))
				f.close()
		entry = dir.get_next()
	dir.list_dir_end()
	return found
