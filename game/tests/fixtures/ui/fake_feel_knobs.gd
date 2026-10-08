class_name FakeFeelKnobs
extends RefCounted
## Stands in for FeelKnobs in the sandbox UI tests: the same calls (knobs, get_f / get_b / get_s,
## set_value, save_user, changed), built from data/combat/feel.json, and Save writes into a scratch
## folder instead of user://feel. Records what the panel did.

signal changed(id: String, value: Variant)

var save_dir: String = ""
var save_count: int = 0
var fail_save: bool = false
var _knobs: Array[Dictionary] = []
var _values: Dictionary = {}


func _init() -> void:
	for knob: Variant in DataDB.get_value("combat/feel", "knobs", []):
		var copy: Dictionary = (knob as Dictionary).duplicate(true)
		_knobs.append(copy)
		_values[str(copy["id"])] = copy["value"]


func knobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for knob: Dictionary in _knobs:
		var copy: Dictionary = knob.duplicate(true)
		copy["value"] = _values[str(knob["id"])]
		out.append(copy)
	return out


func get_f(id: String) -> float:
	return float(_values.get(id, 0.0))


func get_b(id: String) -> bool:
	return bool(_values.get(id, false))


func get_s(id: String) -> String:
	return str(_values.get(id, ""))


func set_value(id: String, value: Variant) -> void:
	if not _values.has(id):
		return
	_values[id] = value
	changed.emit(id, value)


func save_user() -> String:
	if fail_save:
		return ""
	save_count += 1
	var path: String = save_dir.path_join("feel_current.json")
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({"version": 1, "values": _values}))
	file.close()
	return path
