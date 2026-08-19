extends Node
## Local save. Autoloaded as `SaveGame`.
##
## One JSON file in user://. No accounts, no cloud — Steam Cloud can be pointed
## at this same file later without changing the format.

const PATH := "user://around_the_world.save"
const VERSION := 1

signal progress_changed
signal achievement_unlocked(id: String, title: String)

## Mirrors the Steam achievement list. `check` runs after every save write.
const ACHIEVEMENTS := {
	"first_steps": {"title": "First Steps", "desc": "Complete your first puzzle."},
	"first_stamp": {"title": "First Stamp", "desc": "Complete your first destination."},
	"frequent_traveler": {"title": "Frequent Traveller", "desc": "Complete 3 destinations."},
	"around_the_world": {"title": "Every Address", "desc": "Complete every destination."},
	"souvenir_collector": {"title": "Souvenir Collector", "desc": "Discover 25 objects."},
	"unaided": {"title": "No Hints Needed", "desc": "Solve a 15x15 puzzle without a hint."},
	"postmaster": {"title": "Wish You Were Here", "desc": "Send a postcard to a friend."},
}

var data: Dictionary = {}


func _ready() -> void:
	load_file()


func _default() -> Dictionary:
	return {
		"version": VERSION,
		"solved": {},          # puzzle_id -> {"time": secs, "hints": n, "at": unix}
		"in_progress": {},     # puzzle_id -> {"grid": "0121...", "time": secs, "hints": n}
		"postcards": [],       # city ids, in the order they were earned
		"stamps": {},          # city_id -> unix timestamp
		"sent": [],            # postcards shared with friends
		"achievements": {},    # id -> unix
		"settings": {"mood": "paper", "cross_hair": true, "mark_done": true},
		"stats": {"seconds_played": 0.0, "puzzles_solved": 0},
	}


func load_file() -> void:
	data = _default()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable — starting fresh.")
		return
	# Merge so new fields added in later versions get defaults.
	for key in parsed.keys():
		data[key] = parsed[key]
	Pal.set_mood(data["settings"].get("mood", "paper"))


func save_file() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save file")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func save_path() -> String:
	return ProjectSettings.globalize_path(PATH)


# -- puzzles ---------------------------------------------------------------

func is_solved(puzzle_id: String) -> bool:
	return data["solved"].has(puzzle_id)


func solve_record(puzzle_id: String) -> Dictionary:
	return data["solved"].get(puzzle_id, {})


## Half-finished boards. The nav bar makes it easy to wander off mid-puzzle, so
## the grid is kept as a flat digit string ("0" empty, "1" filled, "2" marked).
func save_progress(puzzle_id: String, state: Array, seconds: float, hints: int) -> void:
	var flat := ""
	for row in state:
		for v in row:
			flat += str(v)
	if flat.count("0") == flat.length():
		clear_progress(puzzle_id)   # untouched board — nothing worth keeping
		return
	data["in_progress"][puzzle_id] = {
		"grid": flat, "time": seconds, "hints": hints,
	}
	save_file()


func load_progress(puzzle_id: String) -> Dictionary:
	return data["in_progress"].get(puzzle_id, {})


func clear_progress(puzzle_id: String) -> void:
	if data["in_progress"].erase(puzzle_id):
		save_file()


func mark_solved(puzzle_id: String, seconds: float, hints: int) -> void:
	clear_progress(puzzle_id)
	var previous: Dictionary = data["solved"].get(puzzle_id, {})
	var best: float = seconds
	if previous.has("time"):
		best = min(float(previous["time"]), seconds)
	data["solved"][puzzle_id] = {
		"time": best,
		"hints": hints,
		"at": int(Time.get_unix_time_from_system()),
	}
	data["stats"]["puzzles_solved"] = data["solved"].size()
	save_file()
	progress_changed.emit()


# -- cities ----------------------------------------------------------------

func has_postcard(city_id: String) -> bool:
	return city_id in data["postcards"]


func grant_city_rewards(city_id: String) -> void:
	if not has_postcard(city_id):
		data["postcards"].append(city_id)
	if not data["stamps"].has(city_id):
		data["stamps"][city_id] = int(Time.get_unix_time_from_system())
	save_file()
	progress_changed.emit()


func stamp_date(city_id: String) -> String:
	if not data["stamps"].has(city_id):
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(int(data["stamps"][city_id]))
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
					 "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	return "%02d %s %d" % [dt["day"], MONTHS[dt["month"] - 1], dt["year"]]


# -- sharing ---------------------------------------------------------------

func record_sent(city_id: String, to_name: String, code: String) -> void:
	data["sent"].append({
		"city": city_id,
		"to": to_name,
		"code": code,
		"at": int(Time.get_unix_time_from_system()),
	})
	save_file()
	progress_changed.emit()


func sent_postcards() -> Array:
	return data["sent"]


# -- settings --------------------------------------------------------------

func setting(key: String, fallback: Variant = null) -> Variant:
	return data["settings"].get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_file()


# -- achievements ----------------------------------------------------------

func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)


func unlock(id: String) -> void:
	if has_achievement(id) or not ACHIEVEMENTS.has(id):
		return
	data["achievements"][id] = int(Time.get_unix_time_from_system())
	save_file()
	# Where a real Steam build would call Steam.setAchievement(id).
	achievement_unlocked.emit(id, ACHIEVEMENTS[id]["title"])


## Re-evaluate every achievement condition. Cheap, so just call it after events.
func check_achievements() -> void:
	if data["solved"].size() >= 1:
		unlock("first_steps")
	if data["solved"].size() >= 25:
		unlock("souvenir_collector")
	var complete := GameData.completed_city_count()
	if complete >= 1:
		unlock("first_stamp")
	if complete >= 3:
		unlock("frequent_traveler")
	if complete >= GameData.cities.size() and GameData.cities.size() > 0:
		unlock("around_the_world")
	if not data["sent"].is_empty():
		unlock("postmaster")


func reset_everything() -> void:
	data = _default()
	save_file()
	progress_changed.emit()
