class_name FeelKnobs
extends RefCounted
## The feel knobs (contract 4.9): every number Ross tunes by playing, read from data/combat/feel.json.
## Systems call get_f / get_b / get_s at the moment they use a value (never cache it), so a slider
## move in the feel panel works straight away. Pure: no nodes. Saving writes to user://feel/.

signal changed(id: String, value: Variant)

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://feel"
const CURRENT_FILE: String = "feel_current.json"
const TYPE_FLOAT: String = "float"
const TYPE_INT: String = "int"
const TYPE_BOOL: String = "bool"
const TYPE_CHOICE: String = "choice"

var _knobs: Array[Dictionary] = []
var _index: Dictionary = {}        # id -> position in _knobs
var _defaults: Dictionary = {}     # id -> studio default value


static func load_defaults() -> FeelKnobs:
	return from_data(CombatData.feel())


static func from_data(doc: Dictionary) -> FeelKnobs:
	var knobs: FeelKnobs = FeelKnobs.new()
	var list: Array = doc.get("knobs", [])
	for entry: Variant in list:
		if entry is Dictionary:
			knobs._add(entry)
	return knobs


func _add(entry: Dictionary) -> void:
	var knob: Dictionary = entry.duplicate(true)
	var id: String = str(knob.get("id", ""))
	if id.is_empty() or _index.has(id):
		return
	knob["id"] = id
	var start: Variant = _coerce(knob, knob.get("value"))
	if start == null:
		start = _fallback_for(knob)
	knob["value"] = start
	_defaults[id] = knob["value"]
	_index[id] = _knobs.size()
	_knobs.append(knob)


func has(id: String) -> bool:
	return _index.has(id)


func ids() -> Array[String]:
	var out: Array[String] = []
	for knob: Dictionary in _knobs:
		out.append(str(knob["id"]))
	return out


## The knobs to SHOW (the feel panel binds to this): every knob with its current value (and "default"), in file order,
## except those tied to a feature switch that is off (`"feature": "lamp_flare"` in feel.json). Copies: changing them changes nothing.
## Hidden knobs keep their values, still save and load, and come back when the switch does. `all_knobs()` has them all.
func knobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for knob: Dictionary in all_knobs():
		if not is_hidden(str(knob["id"])):
			out.append(knob)
	return out


## True if the knob belongs to a feature switch that is off.
func is_hidden(id: String) -> bool:
	if not _index.has(id):
		return false
	var feature: String = str((_knobs[int(_index[id])] as Dictionary).get("feature", ""))
	return not feature.is_empty() and not Features.is_on(StringName(feature))


## Every knob, hidden or not.
func all_knobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for knob: Dictionary in _knobs:
		var copy: Dictionary = knob.duplicate(true)
		copy["default"] = _defaults[str(knob["id"])]
		out.append(copy)
	return out


func knob(id: String) -> Dictionary:
	if not _index.has(id):
		return {}
	var copy: Dictionary = (_knobs[int(_index[id])] as Dictionary).duplicate(true)
	copy["default"] = _defaults[id]
	return copy


func get_f(id: String) -> float:
	if not _index.has(id):
		return 0.0
	var value: Variant = (_knobs[int(_index[id])] as Dictionary)["value"]
	if value is float or value is int:
		return float(value)
	return 0.0


func get_b(id: String) -> bool:
	if not _index.has(id):
		return false
	var value: Variant = (_knobs[int(_index[id])] as Dictionary)["value"]
	if value is bool:
		return value
	return false


func get_s(id: String) -> String:
	if not _index.has(id):
		return ""
	return str((_knobs[int(_index[id])] as Dictionary)["value"])


func default_of(id: String) -> Variant:
	return _defaults.get(id, null)


func is_default(id: String) -> bool:
	return _index.has(id) and _defaults[id] == (_knobs[int(_index[id])] as Dictionary)["value"]


## Change one knob. Numbers are clamped to min/max, choices must be one of the options (else ignored).
func set_value(id: String, value: Variant) -> void:
	if not _index.has(id):
		return
	var knob_entry: Dictionary = _knobs[int(_index[id])]
	var coerced: Variant = _coerce(knob_entry, value)
	if coerced == null:
		return
	if typeof(coerced) == typeof(knob_entry["value"]) and coerced == knob_entry["value"]:
		return
	knob_entry["value"] = coerced
	changed.emit(id, coerced)


## Apply a {id: value} map. Unknown ids are ignored; numbers are clamped.
func overlay(values: Dictionary) -> void:
	for id: Variant in values.keys():
		set_value(str(id), values[id])


func reset_to_defaults() -> void:
	for id: String in ids():
		set_value(id, _defaults[id])


func current_values() -> Dictionary:
	var out: Dictionary = {}
	for knob_entry: Dictionary in _knobs:
		out[str(knob_entry["id"])] = knob_entry["value"]
	return out


## {version, saved_at, build, values: {id: value}}: the file Ross sends back.
func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"build": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"values": current_values(),
	}


## Writes feel_current.json plus a dated copy (feel_YYYY-MM-DD_HHMM.json) and returns the absolute path of
## feel_current.json ("" if it could not be written). `dir` is only changed by tests.
func save_user(dir: String = SAVE_DIR) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var text: String = JSON.stringify(to_save_dict(), "  ")
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	var dated: String = "feel_%04d-%02d-%02d_%02d%02d.json" % [stamp["year"], stamp["month"], stamp["day"], stamp["hour"], stamp["minute"]]
	var current_path: String = dir.path_join(CURRENT_FILE)
	for path: String in [current_path, dir.path_join(dated)]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return ""
		file.store_string(text)
		file.close()
	return ProjectSettings.globalize_path(current_path)


## Reads feel_current.json (if there) over the current values. True if a file was applied.
func load_user(dir: String = SAVE_DIR) -> bool:
	var path: String = dir.path_join(CURRENT_FILE)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var values: Variant = (parsed as Dictionary).get("values", null)
	if not (values is Dictionary):
		return false
	overlay(values)
	return true


func _fallback_for(knob_entry: Dictionary) -> Variant:
	match str(knob_entry.get("type", TYPE_FLOAT)):
		TYPE_BOOL:
			return false
		TYPE_CHOICE:
			var options: Array = knob_entry.get("options", [])
			return str(options[0]) if not options.is_empty() else ""
		TYPE_INT:
			return 0
		_:
			return 0.0


## Returns a value of the knob's own type inside its limits, or null if `value` cannot be used.
func _coerce(knob_entry: Dictionary, value: Variant) -> Variant:
	var kind: String = str(knob_entry.get("type", TYPE_FLOAT))
	match kind:
		TYPE_BOOL:
			if value is bool:
				return value
			if value is int or value is float:
				return float(value) != 0.0
			return null
		TYPE_CHOICE:
			var options: Array = knob_entry.get("options", [])
			if options.has(str(value)):
				return str(value)
			return null
		TYPE_INT:
			if not (value is int or value is float):
				return null
			return int(roundf(clampf(float(value), float(knob_entry.get("min", -1.0e9)), float(knob_entry.get("max", 1.0e9)))))
		_:
			if not (value is int or value is float):
				return null
			return clampf(float(value), float(knob_entry.get("min", -1.0e9)), float(knob_entry.get("max", 1.0e9)))
