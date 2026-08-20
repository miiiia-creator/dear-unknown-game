extends Node
## Loads data/cities.json and answers questions about content + progression.
## Autoloaded as `GameData`.

const DATA_PATH := "res://data/cities.json"

var cities: Array = []            ## Array[Dictionary]
var seasons: Array = []
var _city_by_id: Dictionary = {}
var _puzzle_by_id: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s — run tools/build_content.py first." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("cities.json is not valid JSON")
		return

	cities = parsed.get("cities", [])
	seasons = parsed.get("seasons", [])
	for i in cities.size():
		var city: Dictionary = cities[i]
		city["order"] = i
		_city_by_id[city["id"]] = city
		for p in city["puzzles"]:
			p["city_id"] = city["id"]
			_puzzle_by_id[p["id"]] = p


# -- text ------------------------------------------------------------------

## Resolve a translatable content value.
##
## Authored content — city names, discovery names, the letters — carries its
## own translations rather than going through the UI translation table, because
## it is writing rather than interface, and the letters in particular have to be
## composed per language instead of translated line by line.
##
## Anything that is already a plain string passes through, so half-migrated data
## keeps working.
static func text(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return str(value)
	var d: Dictionary = value
	var locale := TranslationServer.get_locale()
	if d.has(locale):
		return str(d[locale])
	# zh_TW should still find zh_CN before falling back to English.
	var base := locale.split("_")[0]
	for key in d.keys():
		if str(key).begins_with(base):
			return str(d[key])
	return str(d.get("en", ""))


# -- lookups ---------------------------------------------------------------

# -- seasons ---------------------------------------------------------------

func season(season_id: String) -> Dictionary:
	for s in seasons:
		if s["id"] == season_id:
			return s
	return {}


## The season a city belongs to.
func season_of(city_id: String) -> Dictionary:
	return season(str(city(city_id).get("season", "")))


## The season the player is currently working through — the first with any
## destination still unfinished, otherwise the last one.
func current_season() -> Dictionary:
	for s in seasons:
		for cid in s["cities"]:
			if not is_city_complete(cid):
				return s
	return seasons[-1] if not seasons.is_empty() else {}


## The card that opens a season. Card zero: nobody earns it.
func opening_of(season_id: String) -> Dictionary:
	return season(season_id).get("opening", {})


## "Season One — The Last Ones", for wherever the season needs naming.
func season_label(season_id: String) -> String:
	var s := season(season_id)
	if s.is_empty():
		return ""
	const WORDS := ["", "One", "Two", "Three", "Four", "Five", "Six"]
	var n: int = int(s.get("number", 0))
	var word: String = WORDS[n] if n < WORDS.size() else str(n)
	return "Season %s — %s" % [word, text(s.get("title", ""))]


func city(city_id: String) -> Dictionary:
	return _city_by_id.get(city_id, {})


func puzzle(puzzle_id: String) -> Dictionary:
	return _puzzle_by_id.get(puzzle_id, {})


func puzzles_of(city_id: String) -> Array:
	return city(city_id).get("puzzles", [])


func city_ids() -> Array:
	var out: Array = []
	for c in cities:
		out.append(c["id"])
	return out


func first_city_id() -> String:
	return cities[0]["id"] if not cities.is_empty() else ""


func next_city_id(city_id: String) -> String:
	var c := city(city_id)
	if c.is_empty():
		return ""
	var i: int = c["order"] + 1
	return cities[i]["id"] if i < cities.size() else ""


func city_palette(city_id: String) -> Array:
	var raw: Array = city(city_id).get("palette", ["#DDDDDD", "#888888", "#333333"])
	var out: Array = []
	for hex in raw:
		out.append(Color(hex))
	return out


func total_puzzle_count() -> int:
	var n := 0
	for c in cities:
		n += c["puzzles"].size()
	return n


# -- progression -----------------------------------------------------------

## A city is playable once every earlier city has been completed.
func is_city_unlocked(city_id: String) -> bool:
	var c := city(city_id)
	if c.is_empty():
		return false
	if c["order"] == 0:
		return true
	var prev: Dictionary = cities[c["order"] - 1]
	return is_city_complete(prev["id"])


## A destination can exist on the map before its discoveries are drawn. That is
## a normal state while a season is being written, not a bug, and every screen
## that offers to play a city has to ask this first.
func is_city_written(city_id: String) -> bool:
	return not puzzles_of(city_id).is_empty()


func is_city_complete(city_id: String) -> bool:
	var list := puzzles_of(city_id)
	if list.is_empty():
		return false
	for p in list:
		if not SaveGame.is_solved(p["id"]):
			return false
	return true


func city_progress(city_id: String) -> Vector2i:
	var list := puzzles_of(city_id)
	var done := 0
	for p in list:
		if SaveGame.is_solved(p["id"]):
			done += 1
	return Vector2i(done, list.size())


## Puzzles unlock in order; the next unsolved one is the only locked-edge case.
func is_puzzle_unlocked(puzzle_id: String) -> bool:
	var p := puzzle(puzzle_id)
	if p.is_empty():
		return false
	if not is_city_unlocked(p["city_id"]):
		return false
	var list := puzzles_of(p["city_id"])
	for q in list:
		if q["id"] == puzzle_id:
			return true
		if not SaveGame.is_solved(q["id"]):
			return false
	return false


## The puzzle the CONTINUE button should open.
func next_puzzle_for(city_id: String) -> Dictionary:
	for p in puzzles_of(city_id):
		if not SaveGame.is_solved(p["id"]):
			return p
	return {}


## City the player should resume in: first unlocked-but-unfinished one.
func current_city_id() -> String:
	for c in cities:
		if is_city_unlocked(c["id"]) and not is_city_complete(c["id"]):
			return c["id"]
	# Everything done — park on the last city.
	return cities[-1]["id"] if not cities.is_empty() else ""


func discovered_count() -> int:
	var n := 0
	for c in cities:
		for p in c["puzzles"]:
			if SaveGame.is_solved(p["id"]):
				n += 1
	return n


func completed_city_count() -> int:
	var n := 0
	for c in cities:
		if is_city_complete(c["id"]):
			n += 1
	return n
