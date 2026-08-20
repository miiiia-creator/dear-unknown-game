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

	app.go("map")
	await _shot("world_map")

	app.go("journal", {"city": "tokyo"})
	await _shot("city_fresh")

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

	app.go("journal", {"city": "tokyo"})
	await _shot("city_done")

	app.go("journal")
	await _shot("journal")

	app.go("postcards")
	await _wait(0.7)
	await _shot("postcards")
	app.go("postcards", {"card": "tokyo"})
	await _wait(0.9)
	await _shot("postcard_front")

	# Flip to the collection side. Paris is left unfinished on purpose so the
	# empty slots show alongside the filled ones.
	app._current._do_flip()
	await _wait(0.3)
	await _shot("postcard_back")

	app.go("share", {"city": "tokyo"})
	await _shot("share")

	app.go("map")
	await _shot("world_map_progress")

	app.go("settings")
	await _shot("settings")

	Pal.set_mood("evening")
	app.go("journal", {"city": "tokyo"})
	await _shot("city_evening")

	app.go("puzzle", {"puzzle": "tokyo_tower"})
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
		app._current._do_flip()
		await _wait(1.0)
		await _shot("letter_" + long_one)

	# Phone-shaped pass, to catch anything that only breaks when narrow.
	Pal.set_mood("paper")
	DisplayServer.window_set_size(Vector2i(430, 900))
	await _wait(0.5)

	app.go("journal", {"city": "tokyo"})
	await _shot("phone_city")

	app.go("puzzle", {"puzzle": "tokyo_torii"})
	await _partial_fill()
	await _shot("phone_puzzle")

	app.go("share", {"city": "tokyo"})
	await _shot("phone_share")

	app.go("map")
	await _shot("phone_map")

	app.go("postcards", {"card": "tokyo"})
	await _wait(0.9)
	await _shot("phone_postcards")

	app.go("postcards")
	await _wait(0.9)
	await _shot("phone_postcards_opening")

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
	app._current._do_flip()
	await _wait(1.0)
	await _shot("phone_card_back")
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await _wait(0.5)
	Pal.set_locale("zh_CN")
	# Chinese sets denser than English, so the longest letter is the one that
	# decides whether the back of a card still holds a letter at all.
	app.go("postcards", {"card": "rome"})
	await _wait(0.8)
	app._current._do_flip()
	await _wait(1.0)
	await _shot("zh_letter_rome")
	app.go("prologue")
	await _wait(4.0)
	await _shot("zh_prologue")
	Pal.set_locale("en")

	print("Screenshots in ", ProjectSettings.globalize_path(SHOT_DIR))
	# A hard quit does not give autoloads a chance to let go of anything, and a
	# screen still holding a film is torn down after the resource cache has
	# started clearing. Land somewhere plain, then hand the music back.
	app.go("map")
	await _wait(0.4)
	Music.release()
	get_tree().quit()


func _watchdog() -> void:
	await get_tree().create_timer(180.0).timeout
	push_error("Screen tour did not finish within 180s — quitting.")
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	var img := app.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, name])
