extends Node
## Buses, sound effects and the gibberish "voice" for dialogue. Autoload: AudioManager.
##
## Data lives in data/audio/: voices.json (one voice per speaker) and sfx.json (sound id -> file,
## bus, volume). Dropping in real audio means changing a file path in sfx.json, or replacing the
## placeholder WAVs in game/audio/; no code changes.
##
## Callers:
##   AudioManager.play_sfx(&"menu_tick")
##   AudioManager.play_voice(&"otis", "H")      # the dialogue runner calls this once per typed character
##   AudioManager.reset_voice()                  # optional, at the start of each line (a speaker change resets too)
## Config menu hooks: set_bus_volume, set_bus_muted, set_voice_volume, set_voices_enabled, get_settings / apply_settings.
##
## Headless / no audio device: the logic still runs (so tests can check what would play) but no
## players are created and nothing is played. A missing id or file logs one warning and stays silent.

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_VOICE: StringName = &"Voice"
const BUSES: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_VOICE]

const DATA_ROOT: String = "/root/DataDB"
const VOICES_DATA_ID: String = "audio/voices"
const SFX_DATA_ID: String = "audio/sfx"
const SFX_KEY: String = "sfx"
const HEADLESS_DISPLAY: String = "headless"
const SFX_POOL_SIZE: int = 8
const DEFAULT_VOICE_POOL_SIZE: int = 4
const SILENT_DB: float = -80.0
const DEFAULT_VOLUME: float = 1.0

var _gibberish: GibberishVoice = GibberishVoice.new()
var _sfx_defs: Dictionary = {}
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[String, bool] = {}
var _volumes: Dictionary[StringName, float] = {}
var _muted: Dictionary[StringName, bool] = {}
var _voices_enabled: bool = true
var _playback_enabled: bool = false
var _voice_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice_player: int = 0
var _next_sfx_player: int = 0

# What was last asked for (tests and the debug overlay read these).
var last_voice_blip: GibberishVoice.Blip = null
var voice_blips_played: int = 0
var last_sfx_id: StringName = &""
var sfx_played: int = 0
## A multiplier on every sound effect's pitch (the combat sandbox's giant robots set it low so big bodies sound big, CS-21).
## 1.0 = the file's own pitch. Set it with set_scale_feel().
var sfx_pitch_mult: float = 1.0
var _scale_lowpass_hz: float = 0.0


func _ready() -> void:
	ensure_buses()
	var db: Node = get_node_or_null(DATA_ROOT)
	if db != null:
		load_voice_data(db.call("get_dict", VOICES_DATA_ID))
		load_sfx_data(db.call("get_dict", SFX_DATA_ID))
	set_playback_enabled(DisplayServer.get_name() != HEADLESS_DISPLAY)


# ---- data ----

## Loads voices.json contents. Returns the list of problems (also logged as warnings).
func load_voice_data(doc: Dictionary) -> Array[String]:
	var problems: Array[String] = _gibberish.load_data(doc)
	for problem: String in problems:
		push_warning("AudioManager: voices.json: %s" % problem)
	return problems


## Loads sfx.json contents. Returns the list of problems (also logged as warnings).
func load_sfx_data(doc: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_sfx_defs = doc.get(SFX_KEY, {})
	for sfx_id: String in _sfx_defs:
		var def: Dictionary = _sfx_defs[sfx_id]
		if str(def.get("file", "")).is_empty():
			problems.append("sfx '%s' has no file" % sfx_id)
		if not BUSES.has(StringName(str(def.get("bus", BUS_SFX)))):
			problems.append("sfx '%s' uses unknown bus '%s'" % [sfx_id, def.get("bus", "")])
	for problem: String in problems:
		push_warning("AudioManager: sfx.json: %s" % problem)
	return problems


func has_sfx(id: StringName) -> bool:
	return _sfx_defs.has(str(id))


func sfx_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in _sfx_defs.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func get_sfx_path(id: StringName) -> String:
	return str((_sfx_defs.get(str(id), {}) as Dictionary).get("file", ""))


func get_voice_logic() -> GibberishVoice:
	return _gibberish


# ---- scale feel (robot scale test) ----

const SCALE_LOWPASS_NAME: String = "scale_lowpass"


## Makes every sound effect lower and duller (a big body) or normal again: `pitch` multiplies each sound's pitch (1.0 = as
## recorded), `lowpass_hz` > 0 muffles the SFX bus above that frequency (0 = off).
func set_scale_feel(pitch: float, lowpass_hz: float = 0.0) -> void:
	sfx_pitch_mult = clampf(pitch, 0.1, 4.0)
	_scale_lowpass_hz = maxf(lowpass_hz, 0.0)
	var index: int = AudioServer.get_bus_index(BUS_SFX)
	if index < 0:
		return
	var found: int = -1
	for i: int in AudioServer.get_bus_effect_count(index):
		var effect: AudioEffect = AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectLowPassFilter and effect.resource_name == SCALE_LOWPASS_NAME:
			found = i
	if _scale_lowpass_hz <= 0.0:
		if found >= 0:
			AudioServer.remove_bus_effect(index, found)
		return
	if found < 0:
		var filter: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		filter.resource_name = SCALE_LOWPASS_NAME
		filter.cutoff_hz = _scale_lowpass_hz
		AudioServer.add_bus_effect(index, filter)
	else:
		(AudioServer.get_bus_effect(index, found) as AudioEffectLowPassFilter).cutoff_hz = _scale_lowpass_hz


func get_scale_lowpass_hz() -> float:
	return _scale_lowpass_hz


# ---- buses and volume ----

## Creates Music, SFX and Voice under Master if they do not exist yet. Safe to call twice.
func ensure_buses() -> void:
	for bus: StringName in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, BUS_MASTER)
		if not _volumes.has(bus):
			_volumes[bus] = DEFAULT_VOLUME
			_muted[bus] = false


## linear is 0.0 (silent) to 1.0 (full). Returns false for an unknown bus.
func set_bus_volume(bus: StringName, linear: float) -> bool:
	if not BUSES.has(bus):
		return false
	_volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)
	return true


func get_bus_volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULT_VOLUME)


func set_bus_muted(bus: StringName, muted: bool) -> bool:
	if not BUSES.has(bus):
		return false
	_muted[bus] = muted
	_apply_bus(bus)
	return true


func is_bus_muted(bus: StringName) -> bool:
	return _muted.get(bus, false)


## Config menu: the dialogue babble's own volume slider.
func set_voice_volume(linear: float) -> void:
	set_bus_volume(BUS_VOICE, linear)


## Config menu: turn the babble off entirely (dialogue text still types, silently).
func set_voices_enabled(enabled: bool) -> void:
	_voices_enabled = enabled


func are_voices_enabled() -> bool:
	return _voices_enabled


## Config menu: mute everything.
func set_all_muted(muted: bool) -> void:
	set_bus_muted(BUS_MASTER, muted)


## Volumes and mutes in a shape Config can save to user://config.json.
func get_settings() -> Dictionary:
	var out: Dictionary = {"voices_enabled": _voices_enabled}
	for bus: StringName in BUSES:
		out["%s_volume" % bus] = get_bus_volume(bus)
		out["%s_muted" % bus] = is_bus_muted(bus)
	return out


## Applies a dictionary made by get_settings(). Missing keys keep their current value.
func apply_settings(settings: Dictionary) -> void:
	for bus: StringName in BUSES:
		var volume_key: String = "%s_volume" % bus
		var muted_key: String = "%s_muted" % bus
		if settings.has(volume_key):
			set_bus_volume(bus, float(settings[volume_key]))
		if settings.has(muted_key):
			set_bus_muted(bus, bool(settings[muted_key]))
	if settings.has("voices_enabled"):
		set_voices_enabled(bool(settings["voices_enabled"]))


func _apply_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var linear: float = get_bus_volume(bus)
	AudioServer.set_bus_volume_db(index, SILENT_DB if linear <= 0.0 else linear_to_db(linear))
	AudioServer.set_bus_mute(index, is_bus_muted(bus))


# ---- playback switch ----

## True only when sound can actually come out. Off when headless; tests can force it either way.
func set_playback_enabled(enabled: bool) -> void:
	_playback_enabled = enabled
	if enabled and _voice_players.is_empty():
		_build_players()
		_preload_voice_streams()


func is_playback_enabled() -> bool:
	return _playback_enabled


func _build_players() -> void:
	var voice_count: int = DEFAULT_VOICE_POOL_SIZE
	for _i: int in range(voice_count):
		_voice_players.append(_make_player(BUS_VOICE))
	for _i: int in range(SFX_POOL_SIZE):
		_sfx_players.append(_make_player(BUS_SFX))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _preload_voice_streams() -> void:
	for path: String in _gibberish.all_stream_paths():
		_get_stream(path)


func _get_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		_warn_once(path, "AudioManager: missing audio file %s (playing silence)" % path)
		return null
	var loaded: Resource = ResourceLoader.load(path)
	if loaded is AudioStream:
		_streams[path] = loaded
		return loaded as AudioStream
	_warn_once(path, "AudioManager: %s is not an audio stream" % path)
	return null


func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


# ---- SFX ----

## Plays a sound effect by id (see data/audio/sfx.json). Returns false for an unknown id.
func play_sfx(id: StringName) -> bool:
	var def: Dictionary = _sfx_defs.get(str(id), {})
	if def.is_empty():
		_warn_once("sfx:%s" % id, "AudioManager: unknown sfx id '%s'" % id)
		return false
	last_sfx_id = id
	sfx_played += 1
	if not _playback_enabled or _sfx_players.is_empty():
		return true
	var stream: AudioStream = _get_stream(str(def.get("file", "")))
	if stream == null:
		return true
	var player: AudioStreamPlayer = _pick_sfx_player()
	player.stream = stream
	player.bus = StringName(str(def.get("bus", BUS_SFX)))
	player.volume_db = float(def.get("volume_db", 0.0))
	player.pitch_scale = maxf(0.01, float(def.get("pitch_scale", 1.0)) * sfx_pitch_mult)
	if player.is_inside_tree():
		player.play()
	return true


func _pick_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	return _sfx_players[_next_sfx_player]


# ---- gibberish voice ----

## Call once for every character the dialogue text types out. Picks the speaker's voice, skips
## spaces, applies the every-Nth-letter throttle, and plays a short syllable (or nothing).
## pitch_offset_semitones lets one NPC sound a little higher or lower than the shared voice.
## Red (and any silent speaker) never makes a sound. Returns true when a blip was started.
func play_voice(speaker_id: StringName, character: String, pitch_offset_semitones: float = 0.0) -> bool:
	if not _voices_enabled:
		return false
	var blip: GibberishVoice.Blip = _gibberish.step(speaker_id, character, pitch_offset_semitones)
	if blip == null:
		return false
	last_voice_blip = blip
	voice_blips_played += 1
	if _playback_enabled and not _voice_players.is_empty():
		_play_blip(blip)
	return true


## Start of a new line of dialogue: forget the throttle and pause state.
func reset_voice() -> void:
	_gibberish.reset()


func _play_blip(blip: GibberishVoice.Blip) -> void:
	var stream: AudioStream = _get_stream(blip.stream_path)
	if stream == null:
		return
	_next_voice_player = (_next_voice_player + 1) % _voice_players.size()
	var player: AudioStreamPlayer = _voice_players[_next_voice_player]
	player.stream = stream
	player.pitch_scale = blip.pitch_scale
	player.volume_db = blip.volume_db
	if player.is_inside_tree():
		player.play()
