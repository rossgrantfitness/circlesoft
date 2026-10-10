extends Node
## Player settings (user://config.json), everything the Config screen (scripts/ui/config_screen.gd)
## shows: text speed, auto-advance, skip seen cutscenes, the four volumes (Master / Music / SFX /
## Voice), the three battle timing options (Auto-Timing, Wide Windows, timing offset in ms),
## vibration, and the button remap. Older settings files without the newer keys still load
## (missing keys keep their defaults). Autoload, no class_name.
##
## Volumes are 0..1 numbers; changing one also tells AudioManager.set_bus_volume() when that exists.
## Button remaps are stored as overrides (see InputRemap) and written into the InputMap when the
## game starts and whenever one changes (`apply_bindings_live`). Tests build their own copy with
## `load("res://scripts/core/config.gd").new()`, point `save_path` at a scratch file and turn
## `apply_bindings_live` off.

signal setting_changed(key: String)

const DEFAULT_PATH: String = "user://config.json"
const TYPING_DATA_ID: String = "ui/dialogue_ui"
const AUDIO_NAME: NodePath = ^"AudioManager"
const AUDIO_VOICE_VOLUME: StringName = &"set_voice_volume"
const KEY_TEXT_SPEED: String = "text_speed"
const KEY_VOICE_VOLUME: String = "voice_volume"
const KEY_AUTO_TIMING: String = "auto_timing"
const KEY_WIDE_WINDOWS: String = "wide_windows"
const KEY_TIMING_OFFSET: String = "timing_offset_ms"
const KEY_MASTER_VOLUME: String = "master_volume"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_AUTO_ADVANCE: String = "auto_advance"
const KEY_SKIP_SEEN: String = "skip_seen_cutscenes"
const KEY_VIBRATION: String = "vibration"
const KEY_DYNAMIC_CAMERA: String = "dynamic_battle_camera"
const KEY_BINDINGS: String = "bindings"
## Volume names in screen order, and the AudioManager bus each one drives.
const VOLUME_BUSES: Dictionary = {"master": &"Master", "music": &"Music", "sfx": &"SFX", "voice": &"Voice"}
const AUDIO_SET_BUS: StringName = &"set_bus_volume"
const BATTLE_UI_DATA_ID: String = "ui/battle_ui"
const DEFAULT_VOICE_VOLUME: float = 0.8
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0
## Fallbacks for the timing offset range; the real numbers are in data/ui/battle_ui.json ("settings").
const DEFAULT_OFFSET_MIN_MS: int = -200
const DEFAULT_OFFSET_MAX_MS: int = 200
const DEFAULT_OFFSET_STEP_MS: int = 10

var save_path: String = DEFAULT_PATH
var text_speed: String = "normal"
var voice_volume: float = DEFAULT_VOICE_VOLUME
## Every Clutch press lands as "Rad!" by itself.
var auto_timing: bool = false
## Bigger timing windows, but you still press.
var wide_windows: bool = false
## Milliseconds added to when presses count (for laggy TVs and headphones). Positive = later.
var timing_offset_ms: int = 0
var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
## Finished text pages turn by themselves after a short read time.
var auto_advance: bool = false
## Cutscenes the player has already seen can be skipped (the cutscene system reads this).
var skip_seen_cutscenes: bool = false
## Controller rumble. Stored now; the first game system to rumble reads it.
var vibration: bool = true
## "Battle camera: Dynamic / Calm". Dynamic (true, the default) pans around during battle; Calm uses the old fixed
## framing for players who want a steadier picture. The battle stage reads it when a fight starts.
var dynamic_battle_camera: bool = true
## Button remaps that differ from the project defaults: {group: {"key": code, "pad": code}}.
var bindings: Dictionary = {}
## On: set_binding / clear_bindings write straight into the InputMap. Tests turn it off.
var apply_bindings_live: bool = true


func _ready() -> void:
	text_speed = default_text_speed()
	load_file()
	# AudioManager is set up after this autoload, so tell it the volumes once everything is ready.
	_push_volumes.call_deferred()
	if not bindings.is_empty():
		InputRemap.apply(bindings)


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


func set_wide_windows(enabled: bool) -> void:
	if enabled == wide_windows:
		return
	wide_windows = enabled
	setting_changed.emit(KEY_WIDE_WINDOWS)


## Sets the timing offset, clamped to the allowed range.
func set_timing_offset_ms(value: int) -> void:
	var clamped: int = clampi(value, get_timing_offset_min_ms(), get_timing_offset_max_ms())
	if clamped == timing_offset_ms:
		return
	timing_offset_ms = clamped
	setting_changed.emit(KEY_TIMING_OFFSET)


## Moves the offset one step (direction -1 or +1). Clamped, no wrap. Returns true when it changed.
func step_timing_offset(direction: int) -> bool:
	var before: int = timing_offset_ms
	set_timing_offset_ms(timing_offset_ms + direction * get_timing_offset_step_ms())
	return timing_offset_ms != before


func get_timing_offset_min_ms() -> int:
	return int(DataDB.get_value(BATTLE_UI_DATA_ID, "settings.timing_offset_min_ms", DEFAULT_OFFSET_MIN_MS))


func get_timing_offset_max_ms() -> int:
	return int(DataDB.get_value(BATTLE_UI_DATA_ID, "settings.timing_offset_max_ms", DEFAULT_OFFSET_MAX_MS))


func get_timing_offset_step_ms() -> int:
	return maxi(1, int(DataDB.get_value(BATTLE_UI_DATA_ID, "settings.timing_offset_step_ms", DEFAULT_OFFSET_STEP_MS)))


## The three battle timing options, ready to copy into a BattleSetup.
func get_battle_timing() -> Dictionary:
	return {"auto_timing": auto_timing, "wide_windows": wide_windows, "timing_offset_ms": timing_offset_ms}


func _push_voice_volume() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node_or_null(AUDIO_NAME) if tree != null else null
	if audio != null and audio.has_method(AUDIO_VOICE_VOLUME):
		audio.call(AUDIO_VOICE_VOLUME, voice_volume)


## Tells AudioManager every volume (the autoload only; copies made by tests have no AudioManager).
func _push_volumes() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node_or_null(AUDIO_NAME) if tree != null else null
	if audio == null or not audio.has_method(AUDIO_SET_BUS):
		_push_voice_volume()
		return
	for volume_id: String in VOLUME_BUSES:
		audio.call(AUDIO_SET_BUS, VOLUME_BUSES[volume_id], get_volume(volume_id))


# ---- volumes, auto-advance, skip, vibration ----

## A volume by name: "master", "music", "sfx" or "voice".
func get_volume(volume_id: String) -> float:
	match volume_id:
		"master":
			return master_volume
		"music":
			return music_volume
		"sfx":
			return sfx_volume
		"voice":
			return voice_volume
	return 1.0


## Sets a volume by name (0..1, snapped to 0.01) and tells AudioManager.
func set_volume(volume_id: String, value: float) -> void:
	if volume_id == "voice":
		set_voice_volume(value)
		return
	if not VOLUME_BUSES.has(volume_id):
		return
	var clamped: float = clampf(snappedf(value, 0.01), 0.0, 1.0)
	if is_equal_approx(clamped, get_volume(volume_id)):
		return
	match volume_id:
		"master":
			master_volume = clamped
		"music":
			music_volume = clamped
		"sfx":
			sfx_volume = clamped
	_push_volume(volume_id)
	setting_changed.emit("%s_volume" % volume_id)


func _push_volume(volume_id: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node_or_null(AUDIO_NAME) if tree != null else null
	if audio != null and audio.has_method(AUDIO_SET_BUS):
		audio.call(AUDIO_SET_BUS, VOLUME_BUSES[volume_id], get_volume(volume_id))


func set_auto_advance(enabled: bool) -> void:
	if enabled == auto_advance:
		return
	auto_advance = enabled
	setting_changed.emit(KEY_AUTO_ADVANCE)


func set_skip_seen_cutscenes(enabled: bool) -> void:
	if enabled == skip_seen_cutscenes:
		return
	skip_seen_cutscenes = enabled
	setting_changed.emit(KEY_SKIP_SEEN)


func set_dynamic_battle_camera(enabled: bool) -> void:
	if enabled == dynamic_battle_camera:
		return
	dynamic_battle_camera = enabled
	setting_changed.emit(KEY_DYNAMIC_CAMERA)


func set_vibration(enabled: bool) -> void:
	if enabled == vibration:
		return
	vibration = enabled
	setting_changed.emit(KEY_VIBRATION)


# ---- button remap ----

## Every remappable button's current binding: {group: {"key": code, "pad": code}}.
func get_effective_bindings() -> Dictionary:
	return InputRemap.effective(bindings)


## Binds `group`'s keyboard key (kind "key") or controller button (kind "pad") to `code`. A group
## that must differ from it and already holds the code takes the old one (a swap). Returns the
## group it swapped with, or "" for none.
func set_binding(group: String, kind: String, code: int) -> String:
	var current: Dictionary = InputRemap.effective(bindings)
	if not current.has(group) or InputRemap.is_reserved(kind, code):
		return ""
	var swapped_with: String = InputRemap.holder_of(current, kind, code, group)
	var updated: Dictionary = InputRemap.rebind(current, group, kind, code)
	var overrides: Dictionary = InputRemap.overrides_from(updated)
	if overrides == bindings:
		return ""
	bindings = overrides
	if apply_bindings_live:
		InputRemap.apply(bindings)
	setting_changed.emit(KEY_BINDINGS)
	return swapped_with


## Back to the project's default buttons.
func clear_bindings() -> void:
	if bindings.is_empty():
		return
	bindings = {}
	if apply_bindings_live:
		InputRemap.apply(bindings)
	setting_changed.emit(KEY_BINDINGS)


# ---- saving ----

func to_dict() -> Dictionary:
	return {
		KEY_TEXT_SPEED: text_speed,
		KEY_VOICE_VOLUME: voice_volume,
		KEY_AUTO_TIMING: auto_timing,
		KEY_WIDE_WINDOWS: wide_windows,
		KEY_TIMING_OFFSET: timing_offset_ms,
		KEY_MASTER_VOLUME: master_volume,
		KEY_MUSIC_VOLUME: music_volume,
		KEY_SFX_VOLUME: sfx_volume,
		KEY_AUTO_ADVANCE: auto_advance,
		KEY_SKIP_SEEN: skip_seen_cutscenes,
		KEY_VIBRATION: vibration,
		KEY_DYNAMIC_CAMERA: dynamic_battle_camera,
		KEY_BINDINGS: bindings.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	if data.has(KEY_TEXT_SPEED):
		set_text_speed(str(data[KEY_TEXT_SPEED]))
	if data.has(KEY_VOICE_VOLUME):
		set_voice_volume(float(data[KEY_VOICE_VOLUME]))
	if data.has(KEY_AUTO_TIMING):
		set_auto_timing(bool(data[KEY_AUTO_TIMING]))
	if data.has(KEY_WIDE_WINDOWS):
		set_wide_windows(bool(data[KEY_WIDE_WINDOWS]))
	if data.has(KEY_TIMING_OFFSET):
		set_timing_offset_ms(int(data[KEY_TIMING_OFFSET]))
	if data.has(KEY_MASTER_VOLUME):
		set_volume("master", float(data[KEY_MASTER_VOLUME]))
	if data.has(KEY_MUSIC_VOLUME):
		set_volume("music", float(data[KEY_MUSIC_VOLUME]))
	if data.has(KEY_SFX_VOLUME):
		set_volume("sfx", float(data[KEY_SFX_VOLUME]))
	if data.has(KEY_AUTO_ADVANCE):
		set_auto_advance(bool(data[KEY_AUTO_ADVANCE]))
	if data.has(KEY_SKIP_SEEN):
		set_skip_seen_cutscenes(bool(data[KEY_SKIP_SEEN]))
	if data.has(KEY_VIBRATION):
		set_vibration(bool(data[KEY_VIBRATION]))
	if data.has(KEY_DYNAMIC_CAMERA):
		set_dynamic_battle_camera(bool(data[KEY_DYNAMIC_CAMERA]))
	if data.get(KEY_BINDINGS) is Dictionary:
		bindings = _clean_bindings(data[KEY_BINDINGS])


## Keeps only well-formed {group: {"key": int, "pad": int}} entries from a loaded file.
func _clean_bindings(raw: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for group: Variant in raw:
		if not raw[group] is Dictionary:
			continue
		for kind: String in [InputRemap.KIND_KEY, InputRemap.KIND_PAD]:
			if (raw[group] as Dictionary).has(kind):
				if not clean.has(str(group)):
					clean[str(group)] = {}
				clean[str(group)][kind] = int((raw[group] as Dictionary)[kind])
	return clean


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
