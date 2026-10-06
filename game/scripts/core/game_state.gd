extends Node
## Run state, kept small for the dialogue and menu tests: the bag (item id -> count), story flags,
## and the party list. The save-system task (M3-9) grows this; to_dict / from_dict are here so a
## save round trip already works for what exists.
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
const MEMBER_SAVE_KEYS: Array[String] = ["level", "xp", "hp", "hp_max", "juice", "juice_max"]

var _bag: Dictionary[String, int] = {}
var _flags: Dictionary[String, bool] = {}
var _party_ids: Array[String] = []
var _members: Dictionary[String, Dictionary] = {}
var _starting_items: Dictionary[String, int] = {}
var _credits: int = 0


func _ready() -> void:
	load_party(DataDB.get_dict(PARTY_DATA_ID))
	reset()


## Reads a party document: {"default_party": [ids], "members": {id: {...}}, "starting_items": {id: n}}.
func load_party(doc: Dictionary) -> void:
	_party_ids.clear()
	_members.clear()
	_starting_items.clear()
	var members: Dictionary = doc.get(KEY_MEMBERS, {})
	for id: String in members:
		_members[id] = (members[id] as Dictionary).duplicate(true)
	for id: Variant in doc.get(KEY_DEFAULT_PARTY, []):
		if _members.has(str(id)):
			_party_ids.append(str(id))
	var starting: Dictionary = doc.get(KEY_STARTING_ITEMS, {})
	for id: String in starting:
		_starting_items[id] = int(starting[id])


## Back to a fresh run: starting bag, no flags, full party list.
func reset() -> void:
	_bag.clear()
	_flags.clear()
	_credits = 0
	for id: String in _starting_items:
		_bag[id] = clampi(_starting_items[id], 0, MAX_STACK)


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


# ---- save round trip ----

func to_dict() -> Dictionary:
	var member_state: Dictionary = {}
	for id: String in _members:
		var member: Dictionary = _members[id]
		var kept: Dictionary = {}
		for key: String in MEMBER_SAVE_KEYS:
			if member.has(key):
				kept[key] = member[key]
		member_state[id] = kept
	return {"bag": _bag.duplicate(), "flags": _flags.duplicate(), "party": _party_ids.duplicate(),
		"credits": _credits, "member_state": member_state}


func from_dict(data: Dictionary) -> void:
	_bag.clear()
	_flags.clear()
	var bag: Dictionary = data.get("bag", {})
	for id: String in bag:
		_bag[id] = int(bag[id])
	var flags: Dictionary = data.get("flags", {})
	for id: String in flags:
		_flags[id] = bool(flags[id])
	_credits = int(data.get("credits", 0))
	var member_state: Dictionary = data.get("member_state", {})
	for id: String in member_state:
		update_member(id, member_state[id])
	var party: Array = data.get("party", [])
	if not party.is_empty():
		_party_ids.clear()
		for id: Variant in party:
			if _members.has(str(id)):
				_party_ids.append(str(id))
