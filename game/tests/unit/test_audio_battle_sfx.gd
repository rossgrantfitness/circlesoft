extends TestCase
## The battle sound effects: every battle_* id promised in docs/battle_api.md exists in sfx.json,
## its file loads, and the placeholders keep the design-doc promises (the ding is a sharp cue, the
## ratings climb, TOTALLY RAD is the loudest sound, the jingles are short).

const SFX_PATH: String = "res://data/audio/sfx.json"
const SFX_SECTION_HEADING: String = "## SFX ids"
const ID_PREFIX: String = "battle_"
const MIN_EXPECTED_IDS: int = 18
const DING_PEAK_WINDOW_SEC: float = 0.010
const DING_MAX_LENGTH_SEC: float = 0.3
const JINGLE_MIN_SEC: float = 1.5
const JINGLE_MAX_SEC: float = 3.0
const GAME_OVER_MAX_SEC: float = 3.5
const PCM_16_FULL_SCALE: float = 32768.0
const FLOOR_DB: float = -120.0


## The ids in the "SFX ids" section of battle_api.md (the backticked battle_* names only).
func _api_ids() -> Array[String]:
	var ids: Array[String] = []
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/battle_api.md").simplify_path())
	var start: int = text.find(SFX_SECTION_HEADING)
	if start < 0:
		return ids
	var end: int = text.find("\n## ", start + SFX_SECTION_HEADING.length())
	var section: String = text.substr(start, (end - start) if end >= 0 else -1)
	var regex: RegEx = RegEx.create_from_string("`(battle_[a-z_]+)`")
	for found: RegExMatch in regex.search_all(section):
		var id: String = found.get_string(1)
		if not ids.has(id):
			ids.append(id)
	return ids


func _sfx_defs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SFX_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("sfx", {})
	return {}


## Reads a 16-bit mono PCM WAV straight from disk (the imported sample may be compressed).
## Returns {rate, samples: PackedFloat32Array}; empty samples if it could not be read.
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


func _volume_db_of(id: String) -> float:
	return float((_sfx_defs().get(id, {}) as Dictionary).get("volume_db", 0.0))


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


func _rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum: float = 0.0
	for s: float in samples:
		sum += s * s
	return sqrt(sum / samples.size())


func _to_db(linear: float) -> float:
	return linear_to_db(linear) if linear > 0.0 else FLOOR_DB


## Peak and RMS after the volume_db set in sfx.json, in dB: how loud it really plays.
func _effective_peak_db(id: String) -> float:
	return _to_db(_peak((_read_pcm(_file_of(id))["samples"] as PackedFloat32Array))) + _volume_db_of(id)


func _effective_rms_db(id: String) -> float:
	return _to_db(_rms((_read_pcm(_file_of(id))["samples"] as PackedFloat32Array))) + _volume_db_of(id)


func test_api_doc_lists_the_battle_sfx_ids() -> void:
	var ids: Array[String] = _api_ids()
	assert_ge(ids.size(), MIN_EXPECTED_IDS, "found %d ids in battle_api.md: %s" % [ids.size(), ids])
	for id: String in ["battle_ding", "battle_rating_totally_rad", "battle_victory", "battle_game_over"]:
		assert_has(ids, id)


func test_every_battle_id_in_the_api_doc_is_in_sfx_json_and_loads() -> void:
	var defs: Dictionary = _sfx_defs()
	for id: String in _api_ids():
		assert_has(defs, id, "'%s' is in docs/battle_api.md but missing from sfx.json" % id)
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		assert_eq(str(def.get("bus", "")), "SFX", "%s bus" % id)
		assert_false(bool(def.get("loop", true)), "%s must be a one-shot" % id)
		assert_true(bool(def.get("placeholder", false)), "%s should be flagged placeholder until real audio arrives" % id)
		var path: String = str(def.get("file", ""))
		assert_true(ResourceLoader.exists(path), "%s file exists: %s" % [id, path])
		var stream: AudioStream = load(path) as AudioStream
		assert_not_null(stream, "%s loads as an AudioStream" % id)
		if stream != null:
			assert_gt(stream.get_length(), 0.0, "%s has some length" % id)


func test_audio_manager_knows_every_battle_id() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio, "AudioManager autoload")
	if audio == null:
		return
	for id: String in _api_ids():
		assert_true(audio.has_sfx(StringName(id)), id)
		assert_true(audio.play_sfx(StringName(id)), "%s plays without crashing" % id)


func test_ding_is_short_and_peaks_in_the_first_ten_milliseconds() -> void:
	var pcm: Dictionary = _read_pcm(_file_of("battle_ding"))
	var samples: PackedFloat32Array = pcm["samples"]
	var rate: int = int(pcm["rate"])
	assert_gt(samples.size(), 0, "ding file reads")
	if samples.is_empty():
		return
	var window: int = int(DING_PEAK_WINDOW_SEC * rate)
	var early: float = _peak(samples, 0, window)
	var later: float = _peak(samples, window)
	assert_ge(early, later, "the loudest part of the ding is in its first 10 ms")
	assert_gt(early, 0.5, "the ding hits hard right away")
	assert_lt(_seconds("battle_ding"), DING_MAX_LENGTH_SEC, "the ding is short")


func test_ratings_climb_and_totally_rad_is_the_loudest_sound() -> void:
	var nice: String = "battle_rating_nice"
	var rad: String = "battle_rating_rad"
	var total: String = "battle_rating_totally_rad"
	assert_lt(_effective_peak_db(nice), _effective_peak_db(rad), "nice quieter than rad (peak)")
	assert_lt(_effective_peak_db(rad), _effective_peak_db(total), "rad quieter than totally rad (peak)")
	assert_lt(_effective_rms_db(nice), _effective_rms_db(rad), "nice quieter than rad (rms)")
	assert_lt(_effective_rms_db(rad), _effective_rms_db(total), "rad quieter than totally rad (rms)")
	assert_gt(_seconds(total), _seconds(rad), "totally rad is the splashiest (longest)")
	for id: String in _api_ids():
		if id == total:
			continue
		assert_gt(_effective_peak_db(total), _effective_peak_db(id), "totally rad out-peaks %s" % id)
		assert_gt(_effective_rms_db(total), _effective_rms_db(id), "totally rad out-rumbles %s" % id)


func test_jingles_are_short() -> void:
	var victory: float = _seconds("battle_victory")
	assert_ge(victory, JINGLE_MIN_SEC, "victory jingle length %.2f" % victory)
	assert_le(victory, JINGLE_MAX_SEC, "victory jingle length %.2f" % victory)
	assert_lt(_seconds("battle_game_over"), GAME_OVER_MAX_SEC, "game over stays short")
