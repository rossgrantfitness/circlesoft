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
const FILE_COMBO: String = "combo.json"
const FILE_HACKS: String = "hacks.json"

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


## The one-button combo rules (data/combat/combo.json).
static func combo() -> Dictionary:
	return combat_file(FILE_COMBO)


## Red's hacks: the battery, the four hacks and the automatic rules (data/combat/hacks.json).
static func hacks() -> Dictionary:
	return combat_file(FILE_HACKS)


static func timing_windows() -> Dictionary:
	return read_json(TIMING_WINDOWS_PATH)


## The parry rating window {nice_ms, rad_ms, totally_rad_ms} from timing_windows.json.
static func parry_window() -> Dictionary:
	var parry: Dictionary = timing_windows().get("parry", {})
	return {"nice_ms": float(parry.get("nice_ms", 220.0)), "rad_ms": float(parry.get("rad_ms", 130.0)),
			"totally_rad_ms": float(parry.get("totally_rad_ms", 70.0))}


## How much damage a guard soaks per rating: {nice, rad, totally_rad}, 0..1, from timing_windows.json
## `parry.block_reduction`. Falls back to the shared top-level `block_reduction` table when the parry block has none.
static func parry_block_reduction() -> Dictionary:
	var windows: Dictionary = timing_windows()
	var parry: Dictionary = windows.get("parry", {})
	var own: Variant = parry.get("block_reduction", null)
	if own is Dictionary and not (own as Dictionary).is_empty():
		return own
	return windows.get("block_reduction", {})


## How long before contact a parry press is still listened to (ms).
static func parry_listen_ms() -> int:
	var parry: Dictionary = timing_windows().get("parry", {})
	return int(parry.get("listen_before_ms", timing_windows().get("listen_before_ms", 400)))


static func clear_cache() -> void:
	_cache.clear()
