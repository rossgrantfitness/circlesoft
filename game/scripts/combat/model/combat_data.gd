class_name CombatData
extends RefCounted
## Loads the combat JSON files straight from res://data/combat/ (and the parry window from the battle
## timing file) without needing the DataDB autoload, so the pure model classes work in any test or tool.
## Results are cached and shared: treat them as read-only (duplicate(true) before changing anything).

const DIR: String = "res://data/combat/"
const TIMING_WINDOWS_PATH: String = "res://data/battle/timing_windows.json"
const FILE_MOVES: String = "moves.json"
const FILE_FEEL: String = "feel.json"
const FILE_HIT_FEEL: String = "hit_feel.json"
const FILE_STYLE: String = "style.json"
const FILE_ENEMIES: String = "enemies.json"
const FILE_SANDBOX: String = "sandbox.json"

static var _cache: Dictionary = {}


## Parses a JSON file that has an object at the top. Empty (with an error logged) if it is missing or broken.
static func read_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
		else:
			push_error("CombatData: %s is not a JSON object" % path)
	else:
		push_error("CombatData: %s is missing" % path)
	_cache[path] = out
	return out


static func combat_file(file_name: String) -> Dictionary:
	return read_json(DIR + file_name)


static func moves() -> Dictionary:
	return combat_file(FILE_MOVES)


static func feel() -> Dictionary:
	return combat_file(FILE_FEEL)


static func hit_feel() -> Dictionary:
	return combat_file(FILE_HIT_FEEL)


static func style() -> Dictionary:
	return combat_file(FILE_STYLE)


static func enemies() -> Dictionary:
	return combat_file(FILE_ENEMIES)


static func timing_windows() -> Dictionary:
	return read_json(TIMING_WINDOWS_PATH)


## The parry rating window {nice_ms, rad_ms, totally_rad_ms} from timing_windows.json.
static func parry_window() -> Dictionary:
	var parry: Dictionary = timing_windows().get("parry", {})
	return {"nice_ms": float(parry.get("nice_ms", 220.0)), "rad_ms": float(parry.get("rad_ms", 130.0)),
			"totally_rad_ms": float(parry.get("totally_rad_ms", 70.0))}


## How long before contact a parry press is still listened to (ms).
static func parry_listen_ms() -> int:
	var parry: Dictionary = timing_windows().get("parry", {})
	return int(parry.get("listen_before_ms", timing_windows().get("listen_before_ms", 400)))


static func clear_cache() -> void:
	_cache.clear()
