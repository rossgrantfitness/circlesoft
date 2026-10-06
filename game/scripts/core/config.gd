extends Node
## Player settings (user://config.json): text speed, voice volume, Auto-Timing. The rest of the
## Config screen (volumes, remap, ...) arrives with task M3-10; this holds what the field menu and
## the speech bubbles need now. Autoload, no class_name.
##
## Voice volume is a 0..1 number; changing it also tells AudioManager.set_voice_volume() when that
## exists. Tests build their own copy with `load("res://scripts/core/config.gd").new()` and point
## `save_path` at a scratch file.

signal setting_changed(key: String)

const DEFAULT_PATH: String = "user://config.json"
const TYPING_DATA_ID: String = "ui/dialogue_ui"
const AUDIO_NAME: NodePath = ^"AudioManager"
const AUDIO_VOICE_VOLUME: StringName = &"set_voice_volume"
const KEY_TEXT_SPEED: String = "text_speed"
const KEY_VOICE_VOLUME: String = "voice_volume"
const KEY_AUTO_TIMING: String = "auto_timing"
const DEFAULT_VOICE_VOLUME: float = 0.8

var save_path: String = DEFAULT_PATH
var text_speed: String = "normal"
var voice_volume: float = DEFAULT_VOICE_VOLUME
var auto_timing: bool = false


func _ready() -> void:
	text_speed = default_text_speed()
	load_file()
	_push_voice_volume()


# ---- text speed ----

## Speed ids in menu order (slow, normal, fast), from data/ui/dialogue_ui.json.
func get_text_speed_ids() -> Array[String]:
	var ids: Array[String] = []
	var speeds: Dictionary = DataDB.get_value(TYPING_DATA_ID, "typing.speeds", {})
	for id: String in speeds:
		ids.append(id)
	return ids


func default_text_speed() -> String:
	return str(DataDB.get_value(TYPING_DATA_ID, "typing.default_speed", "normal"))


## Characters per second for the current text speed.
func get_text_cps() -> float:
	return text_speed_cps(text_speed)


func text_speed_cps(speed_id: String) -> float:
	var fallback: float = float(DataDB.get_value(TYPING_DATA_ID, "typing.speeds.%s" % default_text_speed(), 30.0))
	return float(DataDB.get_value(TYPING_DATA_ID, "typing.speeds.%s" % speed_id, fallback))


func set_text_speed(speed_id: String) -> void:
	if not get_text_speed_ids().has(speed_id) or speed_id == text_speed:
		return
	text_speed = speed_id
	setting_changed.emit(KEY_TEXT_SPEED)


## Moves one step along slow / normal / fast (clamped, no wrap). Returns true when it changed.
func step_text_speed(direction: int) -> bool:
	var ids: Array[String] = get_text_speed_ids()
	var index: int = clampi(ids.find(text_speed) + direction, 0, ids.size() - 1)
	var before: String = text_speed
	set_text_speed(ids[index])
	return text_speed != before


# ---- voice volume and auto-timing ----

func set_voice_volume(value: float) -> void:
	var clamped: float = clampf(snappedf(value, 0.01), 0.0, 1.0)
	if is_equal_approx(clamped, voice_volume):
		return
	voice_volume = clamped
	_push_voice_volume()
	setting_changed.emit(KEY_VOICE_VOLUME)


func set_auto_timing(enabled: bool) -> void:
	if enabled == auto_timing:
		return
	auto_timing = enabled
	setting_changed.emit(KEY_AUTO_TIMING)


func _push_voice_volume() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node_or_null(AUDIO_NAME) if tree != null else null
	if audio != null and audio.has_method(AUDIO_VOICE_VOLUME):
		audio.call(AUDIO_VOICE_VOLUME, voice_volume)


# ---- saving ----

func to_dict() -> Dictionary:
	return {KEY_TEXT_SPEED: text_speed, KEY_VOICE_VOLUME: voice_volume, KEY_AUTO_TIMING: auto_timing}


func from_dict(data: Dictionary) -> void:
	if data.has(KEY_TEXT_SPEED):
		set_text_speed(str(data[KEY_TEXT_SPEED]))
	if data.has(KEY_VOICE_VOLUME):
		set_voice_volume(float(data[KEY_VOICE_VOLUME]))
	if data.has(KEY_AUTO_TIMING):
		set_auto_timing(bool(data[KEY_AUTO_TIMING]))


## Writes the settings file. Returns true on success.
func save_file() -> bool:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


## Reads the settings file if there is one. Returns true when a file was read.
func load_file() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		from_dict(parsed)
		return true
	return false
