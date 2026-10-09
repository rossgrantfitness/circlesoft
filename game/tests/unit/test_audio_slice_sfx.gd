extends TestCase
## The vertical-slice placeholder sounds (VS-32): hacks, boss patterns, the junk mech, the robots, market and
## junkyard ambience, music stand-ins. Every id from docs/audio_requests.md rows 70 to 115 (and every id the code or
## data asks for) is in sfx.json, flagged placeholder, on the right bus, loads, plays; loops really loop; the quick
## ones are quick; the loudness ladder holds (mech slam on top, ambience under effects, music under ambience).
## Built by scripts/tools/make_slice_sfx.py.

const SFX_PATH: String = "res://data/audio/sfx.json"
const DATA_ROOT_DIR: String = "res://data"
const BUS_SFX: String = "SFX"
const BUS_MUSIC: String = "Music"
const TRANSIENT_WINDOW_SEC: float = 0.010
const MIN_TRANSIENT_PEAK: float = 0.3
const MAX_START_SAMPLE: float = 0.2
const MAX_END_SAMPLE: float = 0.05
const MIN_SEAM_ENERGY: float = 0.1
const SEAM_WINDOW_SEC: float = 0.02
const PCM_16_FULL_SCALE: float = 32768.0
const FLOOR_DB: float = -120.0
const MUSIC_PREFIX: String = "music_"
const DATA_SOUND_KEYS: Array[String] = ["sfx", "sounds", "audio", "step_sound", "land_sound", "sting_at_start", "sting_at_lock"]

const HACK_IDS: Array[String] = [
	"hack_zap_cast", "hack_zap_fly", "hack_zap_hit", "hack_emp", "hack_emp_hit", "hack_overclock_link", "hack_overclock_loop",
	"hack_overclock_end", "hack_reboot", "hack_battery_full", "hack_denied", "hack_locked", "hack_unlocked",
	"hack_target_door", "hack_target_crane_loop", "hack_target_line_off", "hack_target_terminal",
]
const BOSS_IDS: Array[String] = [
	"boss_stomp_windup", "boss_stomp_ring", "boss_sweep_line", "boss_sweep_beam", "boss_drone_drop", "boss_quiet_hours",
	"boss_quiet_hours_cut", "boss_relay_break", "boss_topple", "boss_jack_in", "boss_kasp_whistle",
]
const MECH_IDS: Array[String] = [
	"mech_assemble", "scale_switch", "mech_step", "mech_idle_loop", "mech_telegraph", "mech_sting_windup", "mech_sting_lock",
	"mech_swing", "mech_slam", "mech_barrage", "mech_roar", "mech_plate_break", "mech_core_hit", "mech_core_alarm", "mech_defeat",
]
const ROBOT_IDS: Array[String] = [
	"robot_step_small", "robot_step_huge", "robot_hatch", "robot_bay_doors", "robot_dock_clank", "robot_power_up",
	"robot_servo_small_loop", "robot_servo_huge_loop", "robot_swing_huge", "robot_hit_huge",
	"robot_smash_scrap", "robot_smash_scrap_2", "robot_smash_scrap_3",
]
const AMBIENCE_IDS: Array[String] = [
	"amb_market_night", "amb_market_music", "amb_market_radio", "amb_market_arcade", "amb_market_noodles",
	"amb_market_charger", "amb_market_chimes", "amb_market_drones", "amb_market_patrol", "amb_junkyard",
]
const MUSIC_IDS: Array[String] = [
	"music_market", "music_battle_regular", "music_battle_tough", "music_battle_boss", "music_hushmaster", "music_junk_mech",
]
## Loops (sfx.json "loop": true). The market's one-shots (drones, patrol) are not loops.
const LOOP_IDS: Array[String] = [
	"hack_zap_fly", "hack_overclock_loop", "hack_target_crane_loop", "boss_sweep_line", "boss_sweep_beam",
	"mech_idle_loop", "mech_core_alarm", "robot_servo_small_loop", "robot_servo_huge_loop",
	"amb_market_night", "amb_market_music", "amb_market_radio", "amb_market_arcade", "amb_market_noodles",
	"amb_market_charger", "amb_market_chimes", "amb_junkyard",
	"music_market", "music_battle_regular", "music_battle_tough", "music_battle_boss", "music_hushmaster", "music_junk_mech",
]
## Anything that answers a press or lands a hit: loud inside its first 10 ms.
const TRANSIENT_IDS: Array[String] = [
	"hack_zap_cast", "hack_zap_hit", "hack_emp", "hack_emp_hit", "hack_overclock_link", "hack_overclock_end", "hack_reboot",
	"hack_battery_full", "hack_denied", "hack_unlocked", "hack_target_door", "hack_target_terminal",
	"boss_stomp_ring", "boss_quiet_hours_cut", "boss_relay_break", "mech_step", "mech_slam", "mech_core_hit",
	"mech_sting_lock", "mech_plate_break", "robot_step_small", "robot_dock_clank", "robot_hit_huge",
	"robot_smash_scrap", "robot_smash_scrap_2", "robot_smash_scrap_3", "robot_hatch",
]
## Lengths from the brief: id -> longest allowed, in seconds.
const MAX_SECONDS: Dictionary[String, float] = {
	"hack_zap_cast": 0.4, "hack_zap_hit": 0.25, "hack_battery_full": 0.3, "hack_denied": 0.3, "hack_unlocked": 0.31,
	"hack_target_terminal": 0.5, "boss_kasp_whistle": 0.6, "robot_step_small": 0.3, "hack_emp_hit": 0.31,
	"hack_overclock_end": 0.55, "boss_quiet_hours_cut": 0.65, "amb_market_drones": 2.1,
}
## ... and the long ones: id -> shortest allowed.
const MIN_SECONDS: Dictionary[String, float] = {
	"mech_assemble": 6.0, "mech_defeat": 5.0, "boss_jack_in": 1.8, "boss_topple": 2.5, "mech_slam": 1.3, "robot_step_huge": 1.2,
	"amb_market_night": 12.0, "amb_junkyard": 12.0, "amb_market_patrol": 8.0, "mech_roar": 2.0,
}


func _sfx_defs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("sfx", {})
	return {}


func _all_ids() -> Array[String]:
	var ids: Array[String] = []
	for group: Array[String] in [HACK_IDS, BOSS_IDS, MECH_IDS, ROBOT_IDS, AMBIENCE_IDS, MUSIC_IDS]:
		ids.append_array(group)
	return ids


## Reads a 16-bit mono PCM WAV straight from disk (the imported sample may be compressed).
func _read_pcm(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var out: Dictionary = {"rate": 0, "samples": PackedFloat32Array()}
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return out
	var pos: int = 12
	var data_start: int = -1
	var data_len: int = 0
	while pos + 8 <= bytes.size():
		var chunk_id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_len: int = bytes.decode_u32(pos + 4)
		if chunk_id == "fmt ":
			out["rate"] = bytes.decode_u32(pos + 12)
		elif chunk_id == "data":
			data_start = pos + 8
			data_len = mini(chunk_len, bytes.size() - data_start)
		pos += 8 + chunk_len + (chunk_len % 2)
	if data_start < 0:
		return out
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(data_len / 2)
	for i: int in samples.size():
		samples[i] = bytes.decode_s16(data_start + i * 2) / PCM_16_FULL_SCALE
	out["samples"] = samples
	return out


func _file_of(id: String) -> String:
	return str((_sfx_defs().get(id, {}) as Dictionary).get("file", ""))


func _seconds(id: String) -> float:
	var pcm: Dictionary = _read_pcm(_file_of(id))
	var rate: int = int(pcm["rate"])
	return float((pcm["samples"] as PackedFloat32Array).size()) / float(rate) if rate > 0 else 0.0


func _peak(samples: PackedFloat32Array, from: int = 0, to: int = -1) -> float:
	var end: int = samples.size() if to < 0 else mini(to, samples.size())
	var peak: float = 0.0
	for i: int in range(from, end):
		peak = maxf(peak, absf(samples[i]))
	return peak


func _rms(samples: PackedFloat32Array, from: int, to: int) -> float:
	var end: int = mini(to, samples.size())
	if end <= from:
		return 0.0
	var sum: float = 0.0
	for i: int in range(from, end):
		sum += samples[i] * samples[i]
	return sqrt(sum / float(end - from))


func _effective_peak_db(id: String) -> float:
	var peak: float = _peak(_read_pcm(_file_of(id))["samples"] as PackedFloat32Array)
	var volume_db: float = float((_sfx_defs().get(id, {}) as Dictionary).get("volume_db", 0.0))
	return (linear_to_db(peak) if peak > 0.0 else FLOOR_DB) + volume_db


## Every sound id the data names, found by walking data/**/*.json for the keys that hold sound ids.
func _referenced_ids(dir_path: String, found: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub != "audio":
			_referenced_ids("%s/%s" % [dir_path, sub], found)
	for file: String in dir.get_files():
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [dir_path, file]))
			if parsed != null:
				_walk(parsed, "%s/%s" % [dir_path, file], found, false)


func _walk(node: Variant, source: String, found: Dictionary, in_sound_block: bool) -> void:
	if node is Dictionary:
		for key: Variant in (node as Dictionary).keys():
			var value: Variant = (node as Dictionary)[key]
			var name: String = str(key)
			var is_sound_key: bool = DATA_SOUND_KEYS.has(name) or name.ends_with("_sfx")
			if value is String:
				if (is_sound_key or in_sound_block) and not name.begins_with("_") and not (value as String).is_empty():
					found[value] = source
			else:
				_walk(value, source, found, is_sound_key)
	elif node is Array:
		for item: Variant in (node as Array):
			_walk(item, source, found, false)


# ---- the data ----

func test_every_slice_id_is_in_sfx_json_flagged_placeholder_on_the_right_bus_and_loads() -> void:
	var defs: Dictionary = _sfx_defs()
	for id: String in _all_ids():
		assert_has(defs, id, "'%s' missing from sfx.json" % id)
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		var expected_bus: String = BUS_MUSIC if id.begins_with(MUSIC_PREFIX) else BUS_SFX
		assert_eq(str(def.get("bus", "")), expected_bus, "%s is on the %s bus" % [id, expected_bus])
		assert_true(bool(def.get("placeholder", false)), "%s is flagged placeholder until real audio arrives" % id)
		assert_eq(bool(def.get("loop", false)), LOOP_IDS.has(id), "%s: loop flag matches the brief" % id)
		var path: String = str(def.get("file", ""))
		assert_true(ResourceLoader.exists(path), "%s file exists: %s" % [id, path])
		var stream: AudioStream = load(path) as AudioStream
		assert_not_null(stream, "%s loads as an AudioStream" % id)
		if stream != null:
			assert_gt(stream.get_length(), 0.0, "%s has some length" % id)


func test_every_sound_id_the_data_asks_for_is_in_sfx_json() -> void:
	var defs: Dictionary = _sfx_defs()
	var theme: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/ui_theme.json"))
	var theme_keys: Dictionary = (theme as Dictionary).get("sfx", {}) if theme is Dictionary else {}
	var found: Dictionary = {}
	_referenced_ids(DATA_ROOT_DIR, found)
	assert_gt(found.size(), 20, "the walker found the data's sound ids (found %d)" % found.size())
	for id: Variant in found.keys():
		# Menus name a theme key ("confirm"), which ui_theme.json maps to a real id; everything else is a real id.
		var ok: bool = defs.has(str(id)) or theme_keys.has(str(id))
		assert_true(ok, "'%s' (named in %s) is not in sfx.json" % [id, found[id]])
	for key: Variant in theme_keys.keys():
		assert_true(defs.has(str(theme_keys[key])), "ui theme sfx '%s' -> '%s' is not in sfx.json" % [key, theme_keys[key]])


func test_the_ids_the_code_expected_exist() -> void:
	var defs: Dictionary = _sfx_defs()
	for id: String in ["hack_zap_hit", "hack_emp_hit", "mech_sting_windup", "mech_sting_lock"]:
		assert_has(defs, id, id)


func test_every_room_music_key_has_a_stand_in() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	var rooms: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice/rooms.json"))
	assert_true(rooms is Dictionary, "slice rooms load")
	var checked: int = 0
	var text: String = JSON.stringify(rooms)
	for key: String in ["market", "battle_regular", "battle_tough", "battle_boss"]:
		assert_ne(audio.resolve_music_id(StringName(key)), "", "music key '%s' has a stand-in track" % key)
		checked += 1
	assert_true(text.contains("\"music\":\"market\"") or text.contains("\"music\": \"market\""), "the slice rooms still ask for 'market'")
	assert_eq(checked, 4)


# ---- the files ----

func test_loops_really_loop_and_have_no_fade_at_the_seam() -> void:
	for id: String in LOOP_IDS:
		var stream: AudioStreamWAV = load(_file_of(id)) as AudioStreamWAV
		assert_not_null(stream, "%s is a WAV stream" % id)
		if stream != null:
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s carries a forward loop" % id)
		if id.begins_with(MUSIC_PREFIX):
			continue
		var pcm: Dictionary = _read_pcm(_file_of(id))
		var samples: PackedFloat32Array = pcm["samples"]
		var window: int = int(SEAM_WINDOW_SEC * int(pcm["rate"]))
		var overall: float = _rms(samples, 0, samples.size())
		assert_ge(_rms(samples, 0, window), overall * MIN_SEAM_ENERGY, "%s has sound right at the loop start" % id)
		assert_ge(_rms(samples, samples.size() - window, samples.size()), overall * MIN_SEAM_ENERGY, "%s has sound right at the loop end (no fade)" % id)


func test_one_shots_start_and_end_without_a_click() -> void:
	for id: String in _all_ids():
		if LOOP_IDS.has(id):
			continue
		var samples: PackedFloat32Array = _read_pcm(_file_of(id))["samples"]
		assert_gt(samples.size(), 0, "%s file reads" % id)
		if samples.is_empty():
			continue
		assert_lt(absf(samples[0]), MAX_START_SAMPLE, "%s starts near zero (no pop at sample 0)" % id)
		assert_lt(absf(samples[samples.size() - 1]), MAX_END_SAMPLE, "%s ends near zero" % id)


func test_hits_and_presses_have_a_transient_in_the_first_ten_milliseconds() -> void:
	for id: String in TRANSIENT_IDS:
		var pcm: Dictionary = _read_pcm(_file_of(id))
		var samples: PackedFloat32Array = pcm["samples"]
		var early: float = _peak(samples, 0, int(TRANSIENT_WINDOW_SEC * int(pcm["rate"])))
		assert_ge(early, MIN_TRANSIENT_PEAK, "%s hits at once (first-10ms peak %.2f)" % [id, early])


func test_lengths_match_the_brief() -> void:
	for id: String in MAX_SECONDS:
		assert_lt(_seconds(id), MAX_SECONDS[id], "%s is %.3f s, must be under %.2f s" % [id, _seconds(id), MAX_SECONDS[id]])
	for id: String in MIN_SECONDS:
		assert_gt(_seconds(id), MIN_SECONDS[id], "%s is %.3f s, must be over %.2f s" % [id, _seconds(id), MIN_SECONDS[id]])


func test_the_three_smash_variants_are_different_files() -> void:
	var a: PackedByteArray = FileAccess.get_file_as_bytes(_file_of("robot_smash_scrap"))
	var b: PackedByteArray = FileAccess.get_file_as_bytes(_file_of("robot_smash_scrap_2"))
	var c: PackedByteArray = FileAccess.get_file_as_bytes(_file_of("robot_smash_scrap_3"))
	assert_ne(a, b, "variant B differs from A")
	assert_ne(a, c, "variant C differs from A")
	assert_ne(b, c, "variant C differs from B")


# ---- the loudness ladder ----

func test_the_mech_slam_is_the_loudest_sound_in_the_slice() -> void:
	var slam: float = _effective_peak_db("mech_slam")
	for id: String in HACK_IDS + BOSS_IDS + MECH_IDS + ROBOT_IDS:
		assert_ge(slam, _effective_peak_db(id), "mech_slam is at least as loud as %s" % id)


func test_ambience_sits_under_effects_and_music_under_ambience() -> void:
	var quiet_effect: float = _effective_peak_db("hack_zap_hit")
	for id: String in AMBIENCE_IDS:
		assert_lt(_effective_peak_db(id), quiet_effect, "%s sits under a hack hit" % id)
	for id: String in MUSIC_IDS:
		assert_lt(_effective_peak_db(id), _effective_peak_db("amb_market_night"), "%s sits under the market bed" % id)


func test_the_market_is_loud_and_the_junkyard_is_not() -> void:
	assert_gt(_effective_peak_db("amb_market_night"), _effective_peak_db("amb_junkyard"), "the market bed is louder than the junkyard")
	var market: PackedFloat32Array = _read_pcm(_file_of("amb_market_night"))["samples"]
	var junk: PackedFloat32Array = _read_pcm(_file_of("amb_junkyard"))["samples"]
	assert_gt(_rms(market, 0, market.size()) + 0.0, 0.08, "the market bed is dense, not a whisper")
	assert_gt(junk.size(), 0)


func test_the_player_telegraphs_stay_distinct_from_the_enemy_ones() -> void:
	assert_lt(_seconds("hack_denied"), _seconds("mech_telegraph"), "the refusal blip is much shorter than a mech horn")
	assert_gt(_seconds("mech_telegraph"), 1.0, "the mech horn is a long blast")
	assert_gt(_effective_peak_db("mech_telegraph"), _effective_peak_db("hack_denied"), "the mech horn is louder than the refusal blip")


# ---- AudioManager ----

func test_audio_manager_knows_and_plays_every_one_shot() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	for id: String in _all_ids():
		assert_true(audio.has_sfx(StringName(id)), id)
		if not LOOP_IDS.has(id):
			assert_true(audio.play_sfx(StringName(id)), "%s plays without crashing" % id)


func test_audio_manager_starts_and_stops_loops() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	assert_true(audio.play_loop(&"amb_junkyard"), "the junkyard bed starts")
	assert_true(audio.is_loop_playing(&"amb_junkyard"), "and is running")
	assert_true(audio.play_loop(&"amb_junkyard"), "starting it twice is fine")
	assert_true(audio.play_sfx(&"hack_overclock_loop"), "play_sfx on a loop id routes to play_loop")
	assert_true(audio.is_loop_playing(&"hack_overclock_loop"), "so the hum is running")
	assert_false(audio.play_loop(&"hack_zap_hit"), "a one-shot is not a loop")
	assert_false(audio.play_loop(&"no_such_sound_id"), "an unknown id is refused")
	audio.stop_loop(&"amb_junkyard")
	assert_false(audio.is_loop_playing(&"amb_junkyard"), "the bed stops")
	audio.stop_all_loops()
	assert_false(audio.is_loop_playing(&"hack_overclock_loop"), "stop_all_loops stops the rest")


func test_audio_manager_plays_music_by_the_datas_short_name() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	assert_true(audio.play_music(&"market"), "'market' (the rooms.json key) plays")
	assert_eq(audio.current_music_id, &"music_market", "and resolves to the full id")
	assert_true(audio.play_music(&"music_battle_boss"), "a full id plays too")
	assert_eq(audio.current_music_id, &"music_battle_boss")
	assert_false(audio.play_music(&""), "an empty key stops the music")
	assert_eq(audio.current_music_id, &"", "so nothing is current")
	audio.stop_music()
