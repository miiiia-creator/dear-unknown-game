extends Node
## Dev tool. Walks every screen and saves a PNG of each, so layout regressions
## show up without clicking through the game by hand.
##
##   godot --path . -- --tour
##
## Writes to user://shots/ and wipes the save file first, so never run it on a
## profile you care about.

const SHOT_DIR := "user://shots"

var app: Node
var _n := 0


func run(main: Node) -> void:
	app = main
	# A dev tool that hangs is worse than one that fails: if any step errors the
	# coroutine simply stops, and without this the process sits there forever.
	_watchdog()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	SaveGame.reset_everything()

	await _shot("menu")

	# The opening card, mid-reveal and settled.
	app.go("prologue")
	await _wait(2.0)
	await _shot("prologue_front")
	await _wait(3.2)
	await _shot("prologue_back")

	# The journal, which is now the map as well: the pinned world reacts to
	# whichever destination the list below has open.
	app.go("journal", {"city": "tokyo"})
	await _shot("journal_fresh")

	# The card: one face, a point of light, and a picture that develops as the
	# grids are solved. Empty, then with the first one on it.
	DisplayServer.window_set_size(Vector2i(430, 900))
	await _wait(0.6)
	app.go("card", {"city": "tokyo"})
	await _wait(1.4)
	await _shot("card_empty")
	SaveGame.mark_solved("tokyo_pond", 40.0, 0)
	app.go("card", {"city": "tokyo"})
	await _wait(1.2)
	await _shot("card_one")
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await _wait(0.5)

	app.go("puzzle", {"puzzle": "tokyo_torii"})
	await _partial_fill()
	await _shot("puzzle_midway")

	await _solve_current()
	await _shot("puzzle_reveal")

	# Fast-forward Tokyo so the payoff screens have something to show.
	for p in GameData.puzzles_of("tokyo"):
		SaveGame.mark_solved(p["id"], 90.0 + _n * 7.0, 0)
		_n += 1

	app.replace("city_complete", {"city": "tokyo"})
	await _wait(0.6)
	await _shot("city_complete_a")
	await _wait(0.9)
	await _shot("city_complete_b")
	await _wait(1.2)
	await _shot("city_complete")

	app.go("card", {"city": "tokyo"})
	await _wait(1.2)
	await _shot("card_full")

	# A card whose discoveries were solved in more than one ink.
	for p in GameData.puzzles_of("reykjavik"):
		SaveGame.mark_solved(p["id"], 60.0, 0)
	app.go("card", {"city": "reykjavik"})
	await _wait(1.2)
	await _shot("card_full_colour")

	app.go("journal", {"city": "tokyo"})
	await _shot("journal_done")

	# The map lights whichever destination the journal was opened on.
	app.go("journal", {"city": "paris"})
	await _shot("journal_paris")

	app.go("postcards")
	await _wait(0.7)
	await _shot("postcards")
	app.go("postcards", {"card": "tokyo"})
	await _wait(0.9)
	await _shot("postcard_front")

	# Flip to the collection side. Paris is left unfinished on purpose so the
	# empty slots show alongside the filled ones.
	app._current._flip()
	await _wait(0.3)
	await _shot("postcard_back")

	app.go("share", {"city": "tokyo"})
	await _shot("share")

	app.go("journal", {"city": "tokyo"})
	await _shot("journal_progress")

	app.go("settings")
	await _shot("settings")

	Pal.set_mood("evening")
	app.go("journal", {"city": "tokyo"})
	await _shot("journal_evening")

	app.go("puzzle", {"puzzle": "london_bigben"})
	await _partial_fill()
	await _shot("puzzle_evening_15x15")

	# One postcard per destination, to check the palette still distinguishes
	# them now that the sky's structure is fixed and only its warm half is tinted.
	for city in GameData.cities:
		for p in city["puzzles"]:
			SaveGame.mark_solved(p["id"], 100.0, 0)
		app.replace("city_complete", {"city": city["id"]})
		if city["id"] == "tokyo":
			# Catch the mosaic mid-refinement, not just the end state.
			for step in [0.55, 0.95, 1.35, 1.9, 2.6]:
				await _wait(step if step == 0.55 else 0.4)
				await _shot("resolve_%s" % str(step).replace(".", "_"))
		await _wait(4.2)
		await _shot("sky_" + str(city["id"]))
		if city["id"] == "tokyo":
			# The card should have turned itself over by now and be showing the
			# letter — the whole reason the destination was worth finishing.
			await _wait(3.4)
			await _shot("city_complete_letter")

	# The letters, once every card has been earned. Rome's is the longest in the
	# season and New York's is close behind, so if the back of a card cannot
	# hold a letter it shows here.
	for long_one in ["rome", "newyork", "london"]:
		app.go("postcards", {"card": long_one})
		await _wait(0.8)
		app._current._flip()
		await _wait(1.0)
		await _shot("letter_" + long_one)

	# Phone-shaped pass, to catch anything that only breaks when narrow.
	Pal.set_mood("paper")
	DisplayServer.window_set_size(Vector2i(430, 900))
	await _wait(0.5)

	app.go("journal", {"city": "tokyo"})
	await _shot("phone_journal")

	app.go("puzzle", {"puzzle": "tokyo_torii"})
	await _partial_fill()
	await _shot("phone_puzzle")

	app.go("share", {"city": "tokyo"})
	await _shot("phone_share")

	# The one dialog in the game, at the width it has least room in.
	app.go("settings")
	await _wait(0.3)
	app._current._confirm_reset()
	await _wait(0.6)
	await _shot("phone_reset_dialog")
	for w in app._current.get_children():
		if w is Ask:
			(w as Ask).dismiss()
	await _wait(0.3)

	app.go("journal", {"city": "london"})
	await _shot("phone_journal_all")

	# A colour grid, which is a different game: the palette replaces Fill, and
	# the clue numbers take the colour of the run they count.
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await _wait(0.5)
	for p in GameData.puzzles_of("kyoto"):
		SaveGame.mark_solved(p["id"], 60.0, 0)
	app.go("puzzle", {"puzzle": "kyoto_kitty"})
	await _wait(0.6)
	await _partial_fill()
	await _shot("colour_puzzle")

	# Four inks and five: the cases where two of them can quietly turn out to be
	# one, and where the pale end of a palette disappears into the page it is
	# printed on. Open the images, not the error count.
	for p in GameData.puzzles_of("reykjavik"):
		SaveGame.mark_solved(p["id"], 60.0, 0)
	app.go("puzzle", {"puzzle": "reykjavik_sea"})
	await _wait(0.6)
	await _partial_fill()
	await _shot("colour_puzzle_four")

	# Two inks, a brown and a gold — the pair that collapsed into one colour.
	for p in GameData.puzzles_of("sanfrancisco"):
		SaveGame.mark_solved(p["id"], 60.0, 0)
	app.go("puzzle", {"puzzle": "sf_croissant"})
	await _wait(0.6)
	await _partial_fill()
	await _shot("colour_puzzle_two")

	for p in GameData.puzzles_of("bermuda"):
		SaveGame.mark_solved(p["id"], 60.0, 0)
	app.go("puzzle", {"puzzle": "bermuda_triangle"})
	await _wait(0.6)
	await _partial_fill()
	await _shot("colour_puzzle_five")

	# The same grid in the evening, where the page is dark and the correction
	# has to push the inks the other way.
	Pal.set_mood("evening")
	app.go("puzzle", {"puzzle": "bermuda_triangle"})
	await _wait(0.6)
	await _partial_fill()
	await _shot("colour_puzzle_five_evening")
	Pal.set_mood("paper")
	DisplayServer.window_set_size(Vector2i(430, 900))
	await _wait(0.5)

	app.go("postcards", {"card": "tokyo"})
	await _wait(0.9)
	await _shot("phone_postcards")

	app.go("postcards")
	await _wait(0.9)
	await _shot("phone_postcards_opening")

	# The back of the season's opening card, which reads its note from the
	# season the pile says it belongs to — not from whichever one is current.
	app._current._flip()
	await _wait(1.0)
	await _shot("phone_postcards_opening_note")

	# The line is pulled, not tapped. Drag it two cards along and let it settle,
	# which is the whole gesture: the card under the mark is the card you get.
	await _drag_timeline(-150.0)
	await _shot("phone_postcards_dragged")

	# Chinese pass: the content resolver and the CJK fallback both have to hold.
	Pal.set_locale("zh_CN")
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await _wait(0.5)
	app.go("journal", {"city": "tokyo"})
	await _shot("zh_journal")
	app.go("postcards", {"card": "tokyo"})
	await _wait(0.4)
	await _shot("zh_postcard")
	# Upright, where the card turns with the screen.
	Pal.set_locale("en")
	DisplayServer.window_set_size(Vector2i(430, 900))
	await _wait(0.6)
	app.go("postcards", {"card": "tokyo"})
	await _wait(1.0)
	await _shot("phone_card_front")
	app._current._flip()
	await _wait(1.0)
	await _shot("phone_card_back")
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await _wait(0.5)
	Pal.set_locale("zh_CN")
	# Chinese sets denser than English, so the longest letter is the one that
	# decides whether the back of a card still holds a letter at all.
	app.go("postcards", {"card": "rome"})
	await _wait(0.8)
	app._current._flip()
	await _wait(1.0)
	await _shot("zh_letter_rome")
	app.go("prologue")
	await _wait(4.0)
	await _shot("zh_prologue")
	Pal.set_locale("en")

	_font_census()
	print("Screenshots in ", ProjectSettings.globalize_path(SHOT_DIR))
	# A hard quit does not give autoloads a chance to let go of anything, and a
	# screen still holding a film is torn down after the resource cache has
	# started clearing. Land somewhere plain, then hand the music back.
	app.go("journal")
	await _wait(0.4)
	Music.release()
	get_tree().quit()


## Where the font memory goes: every (face, size) pair the game has asked for
## keeps its own rasterised atlas, and a CJK face carries several hundred
## glyphs in each one.
func _font_census() -> void:
	var ts := TextServerManager.get_primary_interface()
	var faces := {"ui": Pal.ui_font, "letter": Pal.letter_font, "mono": Pal.mono_font}
	var grand := 0
	print("[font] ---- glyph atlas census ----")
	var seen := {}
	for label in faces:
		var f: Font = faces[label]
		if f == null:
			continue
		for rid in f.get_rids():
			if seen.has(rid):
				continue
			seen[rid] = true
			var fname: String = ts.font_get_name(rid)
			var sizes: Array = ts.font_get_size_cache_list(rid)
			var bytes := 0
			var dims: Array = []
			for sz in sizes:
				for i in ts.font_get_texture_count(rid, sz):
					var img: Image = ts.font_get_texture_image(rid, sz, i)
					if img != null:
						bytes += img.get_width() * img.get_height() * 4
				dims.append(int((sz as Vector2i).x))
			dims.sort()
			grand += bytes
			print("[font] %-24s %6.2f MB  %2d sizes %s" % [
					fname, bytes / 1048576.0, sizes.size(), str(dims)])
	print("[font] TOTAL %.2f MB" % (grand / 1048576.0))


func _watchdog() -> void:
	await get_tree().create_timer(300.0).timeout
	push_error("Screen tour did not finish within 300s — quitting.")
	get_tree().quit(1)


func _screen() -> Node:
	return app._current


## Fill roughly the first third of the solution, so the board looks played-in.
func _partial_fill() -> void:
	await _wait(0.2)
	var s := _screen()
	var n: Nonogram = s.nono
	var budget := int(n.total_filled() * 0.45)
	for r in n.height:
		for c in n.width:
			if budget <= 0:
				break
			if n.solution[r][c] == 1:
				n.set_cell(r, c, Nonogram.FILLED)
				budget -= 1
			elif (r + c) % 4 == 0:
				n.set_cell(r, c, Nonogram.MARKED)
	s.board.queue_redraw()
	await _wait(0.2)


func _solve_current() -> void:
	var s := _screen()
	var n: Nonogram = s.nono
	for r in n.height:
		for c in n.width:
			n.set_cell(r, c, Nonogram.FILLED if n.solution[r][c] == 1 else Nonogram.MARKED)
	s.board.queue_redraw()
	s._on_solved()
	await _wait(1.6)


## Pull the postcard timeline sideways the way a thumb would, in steps, so the
## drag threshold and the fling both see something like real input.
func _drag_timeline(by: float) -> void:
	var line: PostcardTimeline = _screen()._line
	var mid := line.size * 0.5
	line._gui_input(_press(mid, true))
	for step in 10:
		var move := InputEventMouseMotion.new()
		move.position = mid + Vector2(by * float(step + 1) / 10.0, 0.0)
		line._gui_input(move)
		await _wait(0.016)
	line._gui_input(_press(mid + Vector2(by, 0.0), false))
	await _wait(1.2)


func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	return e


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	var img := app.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, name])
