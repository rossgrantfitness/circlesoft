extends TestCase
## The action-combat placeholder sounds (LIGHTS ON sandbox): every combat_* id from the brief is in
## sfx.json, on the SFX bus, loads, plays; the ten that fire constantly are short; everything has a
## transient in its first 10 ms; hits are louder than swings; the big moments are the biggest.

const SFX_PATH: String = "res://data/audio/sfx.json"
const BUS_SFX: String = "SFX"
const QUICK_MAX_SEC: float = 0.25
const TRANSIENT_WINDOW_SEC: float = 0.010
const MIN_TRANSIENT_PEAK: float = 0.3
const PCM_16_FULL_SCALE: float = 32768.0
const FLOOR_DB: float = -120.0

const COMBAT_IDS: Array[String] = [
	"combat_swing_light", "combat_swing_heavy",
	"combat_hit_light", "combat_hit_heavy", "combat_hit_launch", "combat_hit_air",
	"combat_parry", "combat_parry_perfect",
	"combat_dash", "combat_air_dash", "combat_jump", "combat_land",
	"combat_lamp_flare", "combat_lights_on_activate", "combat_noise_rank_up",
	"combat_lock_on", "combat_enemy_telegraph", "combat_enemy_death", "combat_brute_slam",
]
## Swings, hits, dash, jump, land: they fire constantly, so each stays under QUICK_MAX_SEC.
const QUICK_IDS: Array[String] = [
	"combat_swing_light", "combat_swing_heavy",
	"combat_hit_light", "combat_hit_heavy", "combat_hit_launch", "combat_hit_air",
	"combat_dash", "combat_air_dash", "combat_jump", "combat_land",
]


func _sfx_defs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("sfx", {})
	return {}


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
			break
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


func _effective_peak_db(id: String) -> float:
	var peak: float = _peak(_read_pcm(_file_of(id))["samples"] as PackedFloat32Array)
	var volume_db: float = float((_sfx_defs().get(id, {}) as Dictionary).get("volume_db", 0.0))
	return (linear_to_db(peak) if peak > 0.0 else FLOOR_DB) + volume_db


func test_every_combat_id_is_in_sfx_json_on_the_sfx_bus_and_loads() -> void:
	var defs: Dictionary = _sfx_defs()
	for id: String in COMBAT_IDS:
		assert_has(defs, id, "'%s' missing from sfx.json" % id)
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		assert_eq(str(def.get("bus", "")), BUS_SFX, "%s is on the SFX bus" % id)
		assert_false(bool(def.get("loop", true)), "%s is a one-shot" % id)
		assert_true(bool(def.get("placeholder", false)), "%s is flagged placeholder until real audio arrives" % id)
		var path: String = str(def.get("file", ""))
		assert_true(ResourceLoader.exists(path), "%s file exists: %s" % [id, path])
		var stream: AudioStream = load(path) as AudioStream
		assert_not_null(stream, "%s loads as an AudioStream" % id)
		if stream != null:
			assert_gt(stream.get_length(), 0.0, "%s has some length" % id)


func test_the_sfx_bus_exists() -> void:
	assert_ge(AudioServer.get_bus_index(BUS_SFX), 0, "an SFX bus exists for the combat sounds")


func test_audio_manager_knows_and_plays_every_combat_id() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	for id: String in COMBAT_IDS:
		assert_true(audio.has_sfx(StringName(id)), id)
		assert_true(audio.play_sfx(StringName(id)), "%s plays without crashing" % id)


func test_the_ten_quick_sounds_are_under_a_quarter_second() -> void:
	assert_eq(QUICK_IDS.size(), 10, "ten quick sounds")
	for id: String in QUICK_IDS:
		var seconds: float = _seconds(id)
		assert_gt(seconds, 0.0, "%s file reads" % id)
		assert_lt(seconds, QUICK_MAX_SEC, "%s is %.3f s, must be under %.2f s" % [id, seconds, QUICK_MAX_SEC])


func test_every_sound_has_a_transient_in_its_first_ten_milliseconds() -> void:
	for id: String in COMBAT_IDS:
		var pcm: Dictionary = _read_pcm(_file_of(id))
		var samples: PackedFloat32Array = pcm["samples"]
		var rate: int = int(pcm["rate"])
		assert_gt(samples.size(), 0, "%s file reads" % id)
		if samples.is_empty():
			continue
		var early: float = _peak(samples, 0, int(TRANSIENT_WINDOW_SEC * rate))
		assert_ge(early, MIN_TRANSIENT_PEAK, "%s hits at once (first-10ms peak %.2f)" % [id, early])
		assert_lt(absf(samples[0]), 0.2, "%s starts near zero (no pop at sample 0)" % id)


func test_the_quick_hits_land_hard_in_the_first_ten_milliseconds() -> void:
	for id: String in ["combat_hit_light", "combat_hit_heavy", "combat_hit_launch", "combat_hit_air", "combat_land", "combat_brute_slam", "combat_parry", "combat_parry_perfect"]:
		var pcm: Dictionary = _read_pcm(_file_of(id))
		var samples: PackedFloat32Array = pcm["samples"]
		var window: int = int(TRANSIENT_WINDOW_SEC * int(pcm["rate"]))
		assert_ge(_peak(samples, 0, window), _peak(samples) * 0.9, "%s: its loudest moment is the first 10 ms" % id)


func test_hits_outweigh_swings_and_the_big_moments_are_the_biggest() -> void:
	assert_gt(_effective_peak_db("combat_hit_light"), _effective_peak_db("combat_swing_light"), "a light hit is louder than a light swing")
	assert_gt(_effective_peak_db("combat_hit_heavy"), _effective_peak_db("combat_hit_light"), "heavy hit louder than light hit")
	assert_gt(_effective_peak_db("combat_hit_heavy"), _effective_peak_db("combat_swing_heavy"), "a heavy hit is louder than a heavy swing")
	assert_gt(_effective_peak_db("combat_parry_perfect"), _effective_peak_db("combat_parry"), "perfect parry is bigger than parry")
	assert_gt(_seconds("combat_parry_perfect"), _seconds("combat_parry"), "perfect parry rings longer")
	assert_gt(_effective_peak_db("combat_lights_on_activate"), _effective_peak_db("combat_parry_perfect"), "Lights On is the biggest sound")
	for id: String in COMBAT_IDS:
		if id != "combat_lights_on_activate":
			assert_ge(_effective_peak_db("combat_lights_on_activate"), _effective_peak_db(id), "Lights On is at least as loud as %s" % id)
	for id: String in ["combat_swing_light", "combat_dash", "combat_air_dash", "combat_jump", "combat_lock_on"]:
		assert_lt(_effective_peak_db(id), _effective_peak_db("combat_hit_heavy"), "%s sits below a heavy hit (it fires constantly)" % id)


func test_the_big_sounds_are_longer_than_the_quick_ones() -> void:
	assert_gt(_seconds("combat_lamp_flare"), 1.0, "the Lamp Flare swell has room to bloom")
	assert_gt(_seconds("combat_lights_on_activate"), 1.5, "Lights On has a long triumphant ring-out")
	assert_gt(_seconds("combat_brute_slam"), 0.6, "the Brute slam has a rumbling tail")
	assert_lt(_seconds("combat_noise_rank_up"), 1.0, "the rank-up sting stays short")
	assert_lt(_seconds("combat_lock_on"), QUICK_MAX_SEC, "lock-on is a tiny click-beep")
