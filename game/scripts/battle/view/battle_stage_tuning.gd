class_name BattleStageTuning
extends RefCounted
## Typed reads of data/battle_stage/stage.json for the battle stage (camera, formation, motion, cues,
## shake, the K.O. beat, the static transition, backdrops). Build one with BattleStageTuning.from_db(node)
## in the game (the node is the DataDB autoload), or from_dict(...) in tests.
## A missing key logs an error and reads as 0 / empty, so a data typo is loud instead of silently wrong.

const TUNING_ID: String = "battle_stage/stage"
const CAMERA_ID: String = "battle_stage/camera_shots"
const PATH_SEPARATOR: String = "."
const DEFAULT_BACKDROP: String = "default"

var data: Dictionary = {}


static func from_db(db: Node) -> BattleStageTuning:
	if db == null:
		push_error("BattleStageTuning: no DataDB available")
		return BattleStageTuning.new()
	return from_dict(db.call("get_dict", TUNING_ID))


static func from_db_id(db: Node, id: String) -> BattleStageTuning:
	if db == null:
		push_error("BattleStageTuning: no DataDB available")
		return BattleStageTuning.new()
	return from_dict(db.call("get_dict", id))


static func from_dict(source: Dictionary) -> BattleStageTuning:
	var tuning: BattleStageTuning = BattleStageTuning.new()
	tuning.data = source
	return tuning


## Looks up "a.b.c" in the data. Returns `fallback` (and logs unless quiet) when anything is missing.
func raw(path: String, quiet: bool = false) -> Variant:
	var node: Variant = data
	for part: String in path.split(PATH_SEPARATOR, false):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			if not quiet:
				push_error("BattleStageTuning: missing '%s' in %s" % [path, TUNING_ID])
			return null
	return node


func has(path: String) -> bool:
	return raw(path, true) != null


func number(path: String) -> float:
	var value: Variant = raw(path)
	if value is float or value is int:
		return float(value)
	return 0.0


func integer(path: String) -> int:
	return int(number(path))


func flag(path: String) -> bool:
	return bool(raw(path))


func text(path: String) -> String:
	var value: Variant = raw(path)
	return str(value) if value != null else ""


func color(path: String) -> Color:
	var value: Variant = raw(path)
	return color_of(value)


func vec3(path: String) -> Vector3:
	return vec3_of(raw(path))


func vec2(path: String) -> Vector2:
	var value: Variant = raw(path)
	if value is Array and (value as Array).size() >= 2:
		var list: Array = value
		return Vector2(float(list[0]), float(list[1]))
	return Vector2.ZERO


func dict(path: String) -> Dictionary:
	var value: Variant = raw(path)
	if value is Dictionary:
		return value
	return {}


func list(path: String) -> Array:
	var value: Variant = raw(path)
	if value is Array:
		return value
	return []


func vec3_list(path: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for item: Variant in list(path):
		out.append(vec3_of(item))
	return out


func string_list(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for item: Variant in list(path):
		out.append(str(item))
	return out


## A backdrop's settings: the "default" backdrop with the named one's keys laid over it.
func backdrop(requested: String) -> Dictionary:
	var id: String = str(dict("backdrop_aliases").get(requested, requested))
	var base: Dictionary = dict("backdrops.%s" % DEFAULT_BACKDROP).duplicate(true)
	if id != DEFAULT_BACKDROP:
		var all: Dictionary = dict("backdrops")
		if all.has(id) and all[id] is Dictionary:
			for key: Variant in (all[id] as Dictionary):
				base[key] = (all[id] as Dictionary)[key]
	return base


## The slot position for a side ("party" / "enemy"). Slots past the end reuse the last one, shifted.
func slot_position(side: String, slot: int) -> Vector3:
	var slots: Array[Vector3] = vec3_list("formation.%s" % side)
	if slots.is_empty():
		return Vector3.ZERO
	if slot < slots.size():
		return slots[maxi(slot, 0)]
	return slots[slots.size() - 1] + Vector3(0.0, 0.0, 1.2) * float(slot - slots.size() + 1)


static func color_of(value: Variant) -> Color:
	if value is String:
		return Color.html(value)
	if value is Array and (value as Array).size() >= 3:
		var channels: Array = value
		var alpha: float = float(channels[3]) if channels.size() > 3 else 1.0
		return Color(float(channels[0]), float(channels[1]), float(channels[2]), alpha)
	return Color.MAGENTA


static func vec3_of(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		var channels: Array = value
		return Vector3(float(channels[0]), float(channels[1]), float(channels[2]))
	return Vector3.ZERO
