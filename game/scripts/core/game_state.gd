extends Node
## Run state: the bag (item id -> count), story flags, the party and each member's state (level,
## xp, hp, juice, skills, boosters, gear), credits, play time, where the party is (room + spawn),
## the story beat, opened crates and picked-up items, and the hero's name.
##
## to_dict() / from_dict() are the save format ("save_version" inside). Old dictionaries load
## through a migration chain (see MIGRATIONS); the unversioned format from before the save system
## is version 1 and is kept as a test fixture (tests/fixtures/saves/).
##
## Autoload (no class_name, so it does not hide the singleton). Tests make their own copy with
## `load("res://scripts/core/game_state.gd").new()` and call load_party()/reset().

signal item_changed(item_id: String, count: int)
signal flag_changed(flag_id: String, value: bool)

const PARTY_DATA_ID: String = "party/party"
const ITEMS_DATA_ID: String = "items/items"
const MAX_STACK: int = 99
const KEY_DEFAULT_PARTY: String = "default_party"
const KEY_MEMBERS: String = "members"
const KEY_STARTING_ITEMS: String = "starting_items"
const KEY_ITEMS: String = "items"
## Bump when the saved shape changes and add a step to MIGRATIONS (key = the version it upgrades FROM).
const SAVE_VERSION: int = 2
const MIGRATIONS: Dictionary[int, StringName] = {1: &"_migrate_1_to_2"}
const MEMBER_SAVE_KEYS: Array[String] = ["level", "xp", "hp", "hp_max", "juice", "juice_max", "skills", "bonus", "equipment"]
const INT_MEMBER_KEYS: Array[String] = ["level", "xp", "hp", "hp_max", "juice", "juice_max"]
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "armor", "charm"]
const SAVE_DATA_ID: String = "world/save"
const ROOMS_DATA_ID: String = "world/rooms"
const KEY_NEW_GAME: String = "new_game"
## party.json "new_game": {party: [ids], level: n, items: {id: count}} (see start_new_game).
const KEY_PARTY_NEW_GAME: String = "new_game"
const DEFAULT_HERO_NAME: String = "Red"
const HERO_ID: String = "red"
const PLAY_TIME_STEP_S: float = 0.001

var _bag: Dictionary[String, int] = {}
var _flags: Dictionary[String, bool] = {}
var _party_ids: Array[String] = []
var _default_party_ids: Array[String] = []
var _members: Dictionary[String, Dictionary] = {}
var _starting_items: Dictionary[String, int] = {}
var _new_game_party: Dictionary = {}
var _base_members: Dictionary[String, Dictionary] = {}
var _credits: int = 0
var _play_time_s: float = 0.0
var _location: Dictionary = {"room": "", "spawn": ""}
var _story_beat: String = ""
var _opened: Dictionary[String, bool] = {}
var _hero_name: String = DEFAULT_HERO_NAME

## While true, _process adds the frame time to the play time. Main turns it on in the field and
## off on the title screen. Off by default so tests and menus never tick it.
var playing: bool = false


func _ready() -> void:
	load_party(DataDB.get_dict(PARTY_DATA_ID))
	reset()


func _process(delta: float) -> void:
	if playing:
		tick_play_time(delta)


## Reads a party document: {"default_party": [ids], "members": {id: {...}}, "starting_items": {id: n}}.
func load_party(doc: Dictionary) -> void:
	_party_ids.clear()
	_default_party_ids.clear()
	_members.clear()
	_base_members.clear()
	_starting_items.clear()
	var members: Dictionary = doc.get(KEY_MEMBERS, {})
	for id: String in members:
		_members[id] = (members[id] as Dictionary).duplicate(true)
		_base_members[id] = (members[id] as Dictionary).duplicate(true)
	for id: Variant in doc.get(KEY_DEFAULT_PARTY, []):
		if _members.has(str(id)):
			_party_ids.append(str(id))
			_default_party_ids.append(str(id))
	var starting: Dictionary = doc.get(KEY_STARTING_ITEMS, {})
	for id: String in starting:
		_starting_items[id] = int(starting[id])
	_new_game_party = (doc.get(KEY_PARTY_NEW_GAME, {}) as Dictionary).duplicate(true)
	_sync_starting_stats()


## The starting numbers have one source: the growth table plus the starting gear, through
## StatCalc.sync_maximums (party.json carries no HP or Juice). Every member that has a growth table
## gets its maximums from it and starts at full HP and Juice; the result is also the base that
## reset() goes back to.
func _sync_starting_stats() -> void:
	var growth: Dictionary = BattleData.shared().growth
	for id: String in _members:
		if not growth.has(id):
			continue
		_members[id].erase("hp")
		_members[id].erase("juice")
		StatCalc.sync_maximums(id, {}, self)
		_base_members[id] = _members[id].duplicate(true)


## Back to a fresh run: starting bag, no flags, starting member stats, the new-game place and beat.
func reset() -> void:
	_bag.clear()
	_flags.clear()
	_opened.clear()
	_credits = 0
	_play_time_s = 0.0
	_hero_name = DEFAULT_HERO_NAME
	for id: String in _base_members:
		_members[id] = _base_members[id].duplicate(true)
	for id: String in _starting_items:
		_bag[id] = clampi(_starting_items[id], 0, MAX_STACK)
	_party_ids = _default_party_ids.duplicate()
	_apply_new_game_place()


## A real New Game (the title's): reset(), then the story's start. Red walks alone (party.json
## "new_game".party), every member starts at "new_game".level (Red's first fight is at level 1), and
## the bag gets "new_game".items (the delivery crate she is smuggling). reset() on its own still
## gives the whole roster, which is what most tests and the debug rooms want. Otis and Mox join
## later through join_party().
func start_new_game() -> void:
	reset()
	var level: int = int(_new_game_party.get("level", 0))
	if level > 0:
		var growth: Dictionary = BattleData.shared().growth
		for id: String in _members:
			if not growth.has(id):
				continue
			_members[id]["level"] = level
			_members[id]["xp"] = 0
			_members[id].erase("hp")
			_members[id].erase("juice")
			StatCalc.sync_maximums(id, {}, self)
	var party: Array[String] = []
	for id: Variant in _new_game_party.get("party", []):
		if _members.has(str(id)):
			party.append(str(id))
	if not party.is_empty():
		_party_ids = party
	var items: Dictionary = _new_game_party.get("items", {})
	for item_id: String in items:
		add_item(item_id, int(items[item_id]))


func _apply_new_game_place() -> void:
	var start: Dictionary = _new_game_data()
	_location = {"room": str(start.get("room", "")), "spawn": str(start.get("spawn", ""))}
	_story_beat = str(start.get("story_beat", ""))


## Where a new game starts: the router's start room (rooms.json) and its default spawn when it has
## them, else data/world/save.json "new_game". The story beat always comes from save.json.
func _new_game_data() -> Dictionary:
	var doc: Dictionary = DataDB.get_dict(SAVE_DATA_ID)
	var start: Dictionary = (doc.get(KEY_NEW_GAME, {}) as Dictionary).duplicate()
	var start_room: String = str(DataDB.get_value(ROOMS_DATA_ID, "start_room", ""))
	if not start_room.is_empty():
		start["room"] = start_room
		start["spawn"] = str(DataDB.get_value(ROOMS_DATA_ID, "rooms.%s.default_spawn" % start_room, start.get("spawn", "")))
	return start


# ---- bag ----

## Adds `count` of an item (capped at 99). Returns how many were actually added.
func add_item(item_id: String, count: int = 1) -> int:
	if item_id.is_empty() or count <= 0:
		return 0
	var before: int = item_count(item_id)
	_bag[item_id] = mini(before + count, MAX_STACK)
	item_changed.emit(item_id, _bag[item_id])
	return _bag[item_id] - before


## Removes `count` items. Returns false (and changes nothing) when the bag has fewer than that.
func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or item_count(item_id) < count:
		return false
	var left: int = item_count(item_id) - count
	if left == 0:
		_bag.erase(item_id)
	else:
		_bag[item_id] = left
	item_changed.emit(item_id, left)
	return true


func item_count(item_id: String) -> int:
	return _bag.get(item_id, 0)


func has_item(item_id: String) -> bool:
	return item_count(item_id) > 0


## Item ids in the bag, in the order they were first added.
func get_item_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_bag.keys())
	return ids


## Display name and description for an item id from items.json (falls back to a tidied id).
func get_item_info(item_id: String) -> Dictionary:
	var doc: Variant = DataDB.get_json(ITEMS_DATA_ID)
	var list: Array = []
	if doc is Dictionary:
		list = (doc as Dictionary).get(KEY_ITEMS, [])
	elif doc is Array:
		list = doc
	for entry: Variant in list:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
			return {"id": item_id, "name": str(entry.get("name", item_id)), "desc": str(entry.get("desc", ""))}
	return {"id": item_id, "name": item_id.replace("_", " ").capitalize(), "desc": ""}


# ---- flags ----

func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	var changed: bool = get_flag(flag_id) != value
	_flags[flag_id] = value
	if changed:
		flag_changed.emit(flag_id, value)


func get_flag(flag_id: String) -> bool:
	return _flags.get(flag_id, false)


func clear_flag(flag_id: String) -> void:
	set_flag(flag_id, false)


# ---- party ----

## The party in order, as copies: {id, name, level, hp, hp_max, juice, juice_max, accent, initial}.
func get_party() -> Array[Dictionary]:
	var party: Array[Dictionary] = []
	for id: String in _party_ids:
		party.append(get_member(id))
	return party


func get_member(member_id: String) -> Dictionary:
	if not _members.has(member_id):
		return {}
	var copy: Dictionary = _members[member_id].duplicate(true)
	copy["id"] = member_id
	return copy


func get_party_ids() -> Array[String]:
	return _party_ids.duplicate()


## Puts the party in a new order (the Party page). `ids` must be the same members, each once, and
## Red stays first (the leader). Returns false and changes nothing otherwise. The order is saved
## in to_dict()'s "party" list and comes back with from_dict().
func set_party_order(ids: Array[String]) -> bool:
	if ids.size() != _party_ids.size() or ids.is_empty() or (_party_ids.has(HERO_ID) and ids[0] != HERO_ID):
		return false
	var seen: Dictionary[String, bool] = {}
	for id: String in ids:
		if not _party_ids.has(id) or seen.has(id):
			return false
		seen[id] = true
	_party_ids = ids.duplicate()
	return true


## Who is in the party right now, in order (Red first). Battles, the field menu and the walking crew
## all read this. join_party / leave_party change it; set_party_order reorders it.
func get_active_party() -> Array[String]:
	return _party_ids.duplicate()


func is_in_party(member_id: String) -> bool:
	return _party_ids.has(member_id)


## Adds a known member to the end of the party (Otis after the dock fight, Mox at the crate scene).
## False (and nothing changes) for an unknown member or one already in.
func join_party(member_id: String) -> bool:
	if not _members.has(member_id) or _party_ids.has(member_id):
		return false
	_party_ids.append(member_id)
	return true


## Takes a member out of the party (their stats are kept for when they return). Red can never leave.
func leave_party(member_id: String) -> bool:
	if member_id == HERO_ID or not _party_ids.has(member_id):
		return false
	_party_ids.erase(member_id)
	return true


## Merges fields (level, xp, hp, hp_max, juice, juice_max, ...) into a party member. Used by the
## battle results; unknown members are ignored.
func update_member(member_id: String, fields: Dictionary) -> void:
	if not _members.has(member_id):
		return
	var member: Dictionary = _members[member_id]
	for key: String in fields:
		member[key] = fields[key]


# ---- credits ----

func get_credits() -> int:
	return _credits


func add_credits(amount: int) -> void:
	_credits = maxi(_credits + amount, 0)


# ---- play time ----

func get_play_time_s() -> float:
	return _play_time_s


## Adds seconds of play (the autoload does this itself while `playing`).
func tick_play_time(delta: float) -> void:
	if delta > 0.0:
		_play_time_s += delta


# ---- where we are, and the story ----

## {room, spawn} as copies. Empty strings mean "the start of the game".
func get_location() -> Dictionary:
	return _location.duplicate()


## Where the party is. Called by the scene router on every room change and by save lamps.
func set_location(room_id: String, spawn_id: String = "") -> void:
	_location = {"room": room_id, "spawn": spawn_id}


func get_story_beat() -> String:
	return _story_beat


func set_story_beat(beat_id: String) -> void:
	_story_beat = beat_id


func get_hero_name() -> String:
	return _hero_name


func set_hero_name(hero_name: String) -> void:
	var cleaned: String = hero_name.strip_edges()
	_hero_name = cleaned if not cleaned.is_empty() else DEFAULT_HERO_NAME
	if _members.has(HERO_ID):
		_members[HERO_ID]["name"] = _hero_name


# ---- opened crates and picked-up items ----

## Remembers that a crate or pickup (by its id in placements.json) has been opened or taken.
func mark_opened(opened_id: String) -> void:
	if not opened_id.is_empty():
		_opened[opened_id] = true


func is_opened(opened_id: String) -> bool:
	return _opened.has(opened_id)


func get_opened_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_opened.keys())
	return ids


# ---- gear ----

## {weapon, armor, charm} item ids ("" = nothing). Always has all three keys.
func get_equipment(member_id: String) -> Dictionary:
	var result: Dictionary = {}
	var stored: Dictionary = _members.get(member_id, {}).get("equipment", {})
	for slot: String in EQUIPMENT_SLOTS:
		result[slot] = str(stored.get(slot, ""))
	return result


## Stores an item id in a slot. This does not check owners or armor weight; Equipment.equip() does.
## Returns false for an unknown member or slot.
func set_equipment(member_id: String, slot: String, item_id: String) -> bool:
	if not _members.has(member_id) or not EQUIPMENT_SLOTS.has(slot):
		return false
	var gear: Dictionary = get_equipment(member_id)
	gear[slot] = item_id
	_members[member_id]["equipment"] = gear
	return true


# ---- resting ----

## Full HP and Juice for every member (Red's home, inns, the Camp Stove).
func rest_party() -> void:
	for id: String in _members:
		var member: Dictionary = _members[id]
		if member.has("hp_max"):
			member["hp"] = member["hp_max"]
		if member.has("juice_max"):
			member["juice"] = member["juice_max"]


# ---- save round trip ----

## Everything a save needs, as plain JSON-safe data.
func to_dict() -> Dictionary:
	var member_state: Dictionary = {}
	for id: String in _members:
		var member: Dictionary = _members[id]
		var kept: Dictionary = {}
		for key: String in MEMBER_SAVE_KEYS:
			if member.has(key):
				var value: Variant = member[key]
				if INT_MEMBER_KEYS.has(key):
					value = int(value)
				elif value is Dictionary or value is Array:
					value = value.duplicate(true)
				kept[key] = value
		member_state[id] = kept
	var opened: Array = _opened.keys()
	opened.sort()
	return {"save_version": SAVE_VERSION, "bag": _bag.duplicate(), "flags": _flags.duplicate(),
		"party": _party_ids.duplicate(), "credits": _credits, "member_state": member_state,
		"play_time_s": snappedf(_play_time_s, PLAY_TIME_STEP_S), "location": _location.duplicate(),
		"story_beat": _story_beat, "opened": opened, "hero_name": _hero_name}


## Loads a dictionary from to_dict() of any version. Old versions are migrated first. Anything
## the dictionary does not mention goes back to its starting value, so loading never mixes the
## old run with the saved one.
func from_dict(data: Dictionary) -> void:
	var current: Dictionary = migrate(data)
	reset()
	_bag.clear()
	var bag: Dictionary = current.get("bag", {})
	for id: String in bag:
		_bag[id] = int(bag[id])
	var flags: Dictionary = current.get("flags", {})
	for id: String in flags:
		_flags[id] = bool(flags[id])
	_credits = int(current.get("credits", 0))
	_play_time_s = maxf(0.0, float(current.get("play_time_s", 0.0)))
	var place: Dictionary = current.get("location", {})
	_location = {"room": str(place.get("room", "")), "spawn": str(place.get("spawn", ""))}
	_story_beat = str(current.get("story_beat", ""))
	for id: Variant in current.get("opened", []):
		mark_opened(str(id))
	var member_state: Dictionary = current.get("member_state", {})
	for id: String in member_state:
		update_member(id, _clean_member_fields(member_state[id]))
	set_hero_name(str(current.get("hero_name", DEFAULT_HERO_NAME)))
	var party: Array = current.get("party", [])
	if not party.is_empty():
		_party_ids.clear()
		for id: Variant in party:
			if _members.has(str(id)):
				_party_ids.append(str(id))


## JSON turns every number into a float; the stat fields go back to ints.
func _clean_member_fields(fields: Dictionary) -> Dictionary:
	var cleaned: Dictionary = fields.duplicate(true)
	for key: String in INT_MEMBER_KEYS:
		if cleaned.has(key):
			cleaned[key] = int(cleaned[key])
	return cleaned


## What Main takes before a fight (and any "go back to this moment" feature).
func snapshot() -> Dictionary:
	return to_dict()


## Goes back to a snapshot but keeps the clock running forward: Retry does not rewind play time.
func restore_snapshot(data: Dictionary) -> void:
	var kept_time: float = _play_time_s
	from_dict(data)
	_play_time_s = maxf(_play_time_s, kept_time)


# ---- save versions ----

## The version to_dict() writes. A save from a higher number came from a newer game.
func save_version() -> int:
	return SAVE_VERSION


## The dictionary brought up to SAVE_VERSION (a copy; the argument is not changed). A dictionary
## with no "save_version" is the version-1 format from before the save system.
func migrate(data: Dictionary) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	var version: int = int(current.get("save_version", 1))
	while version < SAVE_VERSION:
		if not MIGRATIONS.has(version):
			push_warning("GameState: no migration from save version %d" % version)
			break
		current = call(MIGRATIONS[version], current) as Dictionary
		version += 1
		current["save_version"] = version
	return current


## 1 -> 2: adds play time, location, story beat, opened ids, hero name and gear. A version-1 save
## has none of them, so the new-game values stand in.
func _migrate_1_to_2(old: Dictionary) -> Dictionary:
	var start: Dictionary = _new_game_data()
	var upgraded: Dictionary = old.duplicate(true)
	if not upgraded.has("play_time_s"):
		upgraded["play_time_s"] = 0.0
	if not upgraded.has("location"):
		upgraded["location"] = {"room": str(start.get("room", "")), "spawn": str(start.get("spawn", ""))}
	if not upgraded.has("story_beat"):
		upgraded["story_beat"] = str(start.get("story_beat", ""))
	if not upgraded.has("opened"):
		upgraded["opened"] = []
	if not upgraded.has("hero_name"):
		upgraded["hero_name"] = DEFAULT_HERO_NAME
	return upgraded
