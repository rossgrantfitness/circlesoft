extends Node
## Save slots: 3 manual slots plus an auto-save, as versioned JSON files in user://saves/
## (the project uses a custom user dir, so on disk that is a "LightsLeftOn" folder).
##
##   slot_1.json, slot_2.json, slot_3.json   written by hand at a save lamp
##   auto.json                                written when the party enters a new area; never by hand
##
## Keys are written in insertion order (not sorted), so the bag keeps the order items were first picked up.
## File shape: {"file_format": 1, "slot": n, "saved_at": unix seconds, "summary": {...},
## "game": GameState.to_dict()}. The GameState dictionary carries its own "save_version" and is
## migrated on load (GameState.migrate), so older saves keep working.
##
## Writes are atomic: the text goes to "<file>.tmp", is read back and checked, and only then is
## the old file replaced. A crash or a full disk leaves the old slot exactly as it was.
##
## Config (settings) is not saved here; it has its own file (Config autoload).
##
## Auto-save timing: only on area entry. Connect a scene router with connect_router() (done by
## itself when a SceneRouter autoload has a `room_entered` signal) or call notify_room_entered().
## Nothing else writes the auto-save: not battles, not menus, not time passing.
##
## Autoload (no class_name, so it does not hide the singleton). Tests make their own copy with
## `load("res://scripts/core/save_manager.gd").new()`, point `save_dir` at a temp folder and set
## `game_state` to their own GameState.

signal saved(slot: int)
signal loaded(slot: int)

const SAVE_DIR: String = "user://saves"
const DATA_ID: String = "world/save"
const TEXT_ID: String = "text/save"
const ROOMS_DATA_ID: String = "world/rooms"
const AUTO_SLOT: int = 0
const AUTO_FILE: String = "auto.json"
const SLOT_FILE: String = "slot_%d.json"
const TEMP_SUFFIX: String = ".tmp"
const FILE_FORMAT: int = 1
const DEFAULT_SLOT_COUNT: int = 3
const NO_SLOT: int = -1
const HEADLESS_DISPLAY: String = "headless"
const PATH_GAME_STATE: NodePath = ^"/root/GameState"
const PATH_ROUTER: NodePath = ^"/root/SceneRouter"
const ROUTER_SIGNAL: StringName = &"room_entered"
const PROMPT_SCRIPT: String = "res://scripts/save/save_prompt.gd"

## Where the files go. Tests point this at a temp folder.
var save_dir: String = SAVE_DIR
## GameState to save from / load into. Null means the autoload.
var game_state: Node = null
## Unix time source (seconds). Tests replace it to control "newest".
var clock: Callable = Callable()
## Off: notify_room_entered() does nothing (cutscenes, tests). The autoload turns this off by itself
## in a headless run.
var auto_save_enabled: bool = true
## True while a fight is on (Main sets it): the auto-save never writes then.
var battle_active: bool = false

var _skip_arrival_room: String = ""
var _skip_arrival: bool = false
var _routers: Array[Object] = []
var _lamp_checks_this_session: int = 0


func _ready() -> void:
	# A headless run is a test run: it must never leave an auto-save in the real saves folder (Continue
	# would load it). Tests that want the auto-save point `save_dir` at a temp folder and switch it on.
	if DisplayServer.get_name() == HEADLESS_DISPLAY:
		auto_save_enabled = false
	_connect_router_later.call_deferred()


func _connect_router_later() -> void:
	var router: Node = get_node_or_null(PATH_ROUTER)
	if router != null and router.has_signal(ROUTER_SIGNAL):
		connect_router(router)


## Listens to a router's `room_entered(room_id[, spawn_id])` for the auto-save.
func connect_router(router: Object) -> void:
	if router == null or _routers.has(router) or not router.has_signal(ROUTER_SIGNAL):
		return
	_routers.append(router)
	router.connect(ROUTER_SIGNAL, _on_router_room_entered)


func _on_router_room_entered(room_id: String, spawn_id: String = "") -> void:
	notify_room_entered(room_id, spawn_id)


# ---- paths and data ----

func slot_count() -> int:
	return int(DataDB.get_value(DATA_ID, "slots", DEFAULT_SLOT_COUNT))


## True for 0 (the auto-save) and 1..slot_count().
func is_valid_slot(slot: int) -> bool:
	return slot >= AUTO_SLOT and slot <= slot_count()


func slot_path(slot: int) -> String:
	var file_name: String = AUTO_FILE if slot == AUTO_SLOT else SLOT_FILE % slot
	return save_dir.path_join(file_name)


func _state() -> Node:
	return game_state if game_state != null else get_node_or_null(PATH_GAME_STATE)


func _now() -> float:
	if clock.is_valid():
		return float(clock.call())
	return Time.get_unix_time_from_system()


# ---- saving ----

## Saves by hand into a manual slot (1..3). The auto-save slot (0) is refused. Returns true on success.
func save_slot(slot: int) -> bool:
	if slot < 1 or slot > slot_count():
		return false
	return _write_slot(slot)


## Writes the auto-save. Does nothing (false) during a battle. Only area entry should call this.
func auto_save() -> bool:
	if battle_active:
		return false
	return _write_slot(AUTO_SLOT)


## Called when the party has entered an area. Records where we are, then writes the auto-save
## unless this arrival is the one a load just produced.
func notify_room_entered(room_id: String, spawn_id: String = "") -> void:
	var state: Node = _state()
	if state == null or room_id.is_empty():
		return
	var place: Dictionary = state.call("get_location")
	if spawn_id.is_empty() and str(place.get("room", "")) == room_id:
		spawn_id = str(place.get("spawn", ""))
	state.call("set_location", room_id, spawn_id)
	if _skip_arrival:
		var was_load: bool = _skip_arrival_room == room_id
		_skip_arrival = false
		if was_load:
			return
	if auto_save_enabled:
		auto_save()


func _write_slot(slot: int) -> bool:
	var state: Node = _state()
	if state == null:
		return false
	var game: Dictionary = state.call("to_dict")
	var body: Dictionary = {
		"file_format": FILE_FORMAT,
		"slot": slot,
		"saved_at": _now(),
		"summary": _summary_of(game),
		"game": game,
	}
	if not write_atomic(slot_path(slot), JSON.stringify(body, "\t", false)):
		return false
	saved.emit(slot)
	return true


## Writes text to `path` through "<path>.tmp": write, read back and compare, then replace the old
## file. On any failure the old file is untouched and the temp file is removed. Returns true on success.
func write_atomic(path: String, text: String) -> bool:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		push_warning("SaveManager: can't make %s" % path.get_base_dir())
		return false
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: can't write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temp_path) != text:
		DirAccess.remove_absolute(temp_path)
		return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		push_warning("SaveManager: can't replace %s (%s)" % [path, error_string(rename_error)])
		return false
	return true


# ---- loading ----

## Loads a slot (0 = the auto-save) into GameState. Returns false, changing nothing, when the slot
## is empty, unreadable, or was written by a newer game.
func load_slot(slot: int) -> bool:
	var state: Node = _state()
	if state == null or not is_valid_slot(slot):
		return false
	var game: Dictionary = _read_game(slot)
	if game.is_empty():
		return false
	state.call("from_dict", game)
	var place: Dictionary = state.call("get_location")
	_skip_arrival = true
	_skip_arrival_room = str(place.get("room", ""))
	loaded.emit(slot)
	return true


## Loads the newest save, manual or auto. Returns false when there is none.
func continue_game() -> bool:
	var slot: int = newest_slot()
	return slot != NO_SLOT and load_slot(slot)


## The parsed file of a slot, or {} when it is missing or broken.
func read_file(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse() reports a broken file as an error code instead of an engine error message.
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	return json.data


## The GameState dictionary inside a slot's file, or {} when missing, broken or from a newer game.
func _read_game(slot: int) -> Dictionary:
	var file: Dictionary = read_file(slot)
	if file.is_empty():
		return {}
	# A bare GameState dictionary (no envelope) is accepted too.
	var game: Variant = file.get("game", file if file.has("bag") else null)
	if not (game is Dictionary):
		return {}
	var state: Node = _state()
	if state != null and int((game as Dictionary).get("save_version", 1)) > int(state.call("save_version")):
		return {}
	return game


# ---- looking at slots ----

## True when any slot (or the auto-save) holds a readable save.
func has_any_save() -> bool:
	return newest_slot() != NO_SLOT


## The slot with the most recent save (0 = auto), or -1 when there is none. Broken files are skipped.
func newest_slot() -> int:
	var best: int = NO_SLOT
	var best_time: float = -INF
	for slot: int in range(AUTO_SLOT, slot_count() + 1):
		if _read_game(slot).is_empty():
			continue
		var saved_at: float = float(read_file(slot).get("saved_at", 0.0))
		if saved_at >= best_time:
			best = slot
			best_time = saved_at
	return best


## What a slot shows: {slot, place, play_time_s, party: [{id, level}], credits, saved_at, hero_name}.
## An empty slot gives {}; a file that can't be read gives {"corrupt": true, "slot": n}.
func slot_summary(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {}
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var game: Dictionary = _read_game(slot)
	if game.is_empty():
		return {"corrupt": true, "slot": slot}
	var summary: Dictionary = _summary_of(migrated(game))
	summary["slot"] = slot
	summary["saved_at"] = float(read_file(slot).get("saved_at", 0.0))
	return summary


func migrated(game: Dictionary) -> Dictionary:
	var state: Node = _state()
	return state.call("migrate", game) as Dictionary if state != null else game


func _summary_of(game: Dictionary) -> Dictionary:
	var members: Dictionary = game.get("member_state", {})
	var party: Array = []
	for id: Variant in game.get("party", []):
		var level: int = int((members.get(str(id), {}) as Dictionary).get("level", 1))
		party.append({"id": str(id), "level": level})
	var place: Dictionary = game.get("location", {})
	return {
		"place": place_name(str(place.get("room", ""))),
		"play_time_s": float(game.get("play_time_s", 0.0)),
		"party": party,
		"credits": int(game.get("credits", 0)),
		"hero_name": str(game.get("hero_name", "")),
	}


## The display name of a room id: rooms.json "name", else data/text/save.json "places", else a tidied id.
func place_name(room_id: String) -> String:
	if room_id.is_empty():
		return str(DataDB.get_value(TEXT_ID, "unknown_place", "Somewhere"))
	var room_name: String = str(DataDB.get_value(ROOMS_DATA_ID, "rooms.%s.name" % room_id, ""))
	if not room_name.is_empty():
		return room_name
	var named: String = str(DataDB.get_value(TEXT_ID, "places.%s" % room_id, ""))
	return named if not named.is_empty() else room_id.replace("_", " ").capitalize()


# ---- save lamps ----

## True for the first lamp check since the game started (the full one), false after (the short one).
func is_first_lamp_check() -> bool:
	return _lamp_checks_this_session == 0


## A lamp check has been played (full or short); the next one is short.
func note_lamp_check_done() -> void:
	_lamp_checks_this_session += 1


## Opens the save screen on the UI stage and returns it (a SavePrompt). `rest` heals the party first
## (Red's home, inns); save lamps in dungeons pass false. `player` is frozen while it is open.
## Call when the lamp check is over; SaveLamp does the check and then calls this.
func open_lamp_menu(rest: bool = false, player: Node = null) -> Node:
	var script: GDScript = load(PROMPT_SCRIPT) as GDScript
	var tree: SceneTree = get_tree()
	if script == null or tree == null:
		return null
	return script.call("open", tree, self, rest, player) as Node
