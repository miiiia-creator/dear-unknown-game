extends Node
## Loads data/cities.json and answers questions about content + progression.
## Autoloaded as `GameData`.

const DATA_PATH := "res://data/cities.json"

var cities: Array = []            ## Array[Dictionary]
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
	for i in cities.size():
		var city: Dictionary = cities[i]
		city["order"] = i
		_city_by_id[city["id"]] = city
		for p in city["puzzles"]:
			p["city_id"] = city["id"]
			_puzzle_by_id[p["id"]] = p


# -- lookups ---------------------------------------------------------------

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
