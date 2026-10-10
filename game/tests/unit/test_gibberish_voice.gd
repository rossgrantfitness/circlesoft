extends TestCase
## The gibberish voice: data files load, every speaker (except Red) has a voice, the letter ->
## syllable mapping is deterministic, spaces and punctuation behave, and the Nth-letter throttle works.

const VOICES_PATH: String = "res://data/audio/voices.json"
const SFX_PATH: String = "res://data/audio/sfx.json"
const SPEAKERS: Array[StringName] = [&"otis", &"mox", &"zero_old", &"kasp", &"vela", &"ruo", &"townsfolk"]
const RED: StringName = &"red"
const LETTERS: String = "abcdefghijklmnopqrstuvwxyz"


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _make_voice(doc: Dictionary = {}) -> GibberishVoice:
	var voice: GibberishVoice = GibberishVoice.new()
	var problems: Array[String] = voice.load_data(_read_json(VOICES_PATH) if doc.is_empty() else doc)
	assert_eq(problems.size(), 0, "voices.json problems: %s" % [problems])
	return voice


## voices.json with every voice forced to play every letter, for punctuation tests.
func _every_letter_doc() -> Dictionary:
	var doc: Dictionary = _read_json(VOICES_PATH)
	for voice_id: String in doc["voices"]:
		doc["voices"][voice_id]["every_nth_letter"] = 1
	return doc


func _feed(voice: GibberishVoice, speaker: StringName, text: String) -> Array[GibberishVoice.Blip]:
	var out: Array[GibberishVoice.Blip] = []
	for i: int in range(text.length()):
		out.append(voice.step(speaker, text.substr(i, 1)))
	return out


func _count_played(blips: Array[GibberishVoice.Blip]) -> int:
	var count: int = 0
	for blip: GibberishVoice.Blip in blips:
		if blip != null:
			count += 1
	return count


func _effective_hz(voice: GibberishVoice, speaker: StringName, ref_hz: Dictionary) -> float:
	var blip: GibberishVoice.Blip = voice.make_blip(voice.resolve_voice_id(speaker), "a")
	return blip.pitch_scale * float(ref_hz[blip.voice_id])


# ---- data ----

func test_voices_and_sfx_json_load_through_datadb() -> void:
	var db: Node = tree.root.get_node("DataDB")
	assert_true(db.has_json("audio/voices"), "audio/voices")
	assert_true(db.has_json("audio/sfx"), "audio/sfx")
	assert_false(db.has_errors(), "DataDB errors: %s" % [db.get_errors()])


func test_voices_json_validates_cleanly() -> void:
	var voice: GibberishVoice = GibberishVoice.new()
	assert_eq(voice.load_data(_read_json(VOICES_PATH)), [] as Array[String])


func test_validation_catches_a_bad_voice() -> void:
	var doc: Dictionary = _read_json(VOICES_PATH)
	doc["voices"]["otis"]["timbre"] = "nope"
	doc["voices"]["mox"]["every_nth_letter"] = 0
	doc["letters"]["a"]["syllable"] = "v_zzz"
	var problems: Array[String] = GibberishVoice.new().load_data(doc)
	assert_ge(problems.size(), 3, "problems: %s" % [problems])


func test_every_speaker_has_a_voice_except_red() -> void:
	var voice: GibberishVoice = _make_voice()
	for speaker: StringName in SPEAKERS:
		assert_true(voice.has_voice(speaker), "%s needs a voice" % speaker)
		assert_true(voice_ids_has(voice, speaker), "%s is defined in voices.json" % speaker)
	assert_false(voice.has_voice(RED), "Red is silent")
	assert_true(voice.is_silent(RED))
	assert_false(voice.voice_ids().has(String(RED)), "Red has no voice entry")


func voice_ids_has(voice: GibberishVoice, speaker: StringName) -> bool:
	return voice.voice_ids().has(String(speaker))


func test_unknown_speakers_use_the_generic_voice_and_aliases_work() -> void:
	var voice: GibberishVoice = _make_voice()
	assert_eq(voice.resolve_voice_id(&"some_guy"), &"townsfolk")
	assert_eq(voice.resolve_voice_id(&"zero"), &"zero_old")
	assert_eq(voice.resolve_voice_id(&""), &"")


func test_every_voice_file_exists() -> void:
	var voice: GibberishVoice = _make_voice()
	var paths: Array[String] = voice.all_stream_paths()
	assert_gt(paths.size(), 0.0)
	for path: String in paths:
		assert_true(ResourceLoader.exists(path), "missing voice file %s" % path)


func test_every_sfx_file_exists() -> void:
	var sfx: Dictionary = _read_json(SFX_PATH)["sfx"]
	for id: String in ["menu_tick", "menu_confirm", "menu_back", "bubble_open", "bubble_next", "item_get",
			"red_thumbs_up", "red_head_shake"]:
		assert_true(sfx.has(id), "sfx.json needs %s" % id)
		assert_true(ResourceLoader.exists(str(sfx[id]["file"])), "missing file for %s" % id)
		assert_true(bool(sfx[id].get("placeholder", false)), "%s is marked placeholder" % id)


func test_each_voice_sounds_different() -> void:
	var doc: Dictionary = _read_json(VOICES_PATH)
	var seen: Dictionary = {}
	for voice_id: String in doc["voices"]:
		var v: Dictionary = doc["voices"][voice_id]
		var signature: String = "%s/%s" % [v["timbre"], v["base_pitch_hz"]]
		assert_false(seen.has(signature), "%s duplicates another voice" % voice_id)
		seen[signature] = true


func test_voices_are_ordered_low_to_high() -> void:
	var voice: GibberishVoice = _make_voice()
	var doc: Dictionary = _read_json(VOICES_PATH)
	var refs: Dictionary = {}
	for voice_id: String in doc["voices"]:
		refs[StringName(voice_id)] = float(doc["timbres"][doc["voices"][voice_id]["timbre"]]["ref_hz"])
	var order: Array[StringName] = [&"otis", &"zero_old", &"kasp", &"townsfolk", &"vela", &"mox"]
	for i: int in range(order.size() - 1):
		assert_lt(_effective_hz(voice, order[i], refs), _effective_hz(voice, order[i + 1], refs),
				"%s should sound lower than %s" % [order[i], order[i + 1]])


# ---- letter -> syllable ----

func test_same_letter_same_blip_every_time() -> void:
	var first: GibberishVoice = _make_voice()
	var second: GibberishVoice = _make_voice()
	for speaker: StringName in SPEAKERS:
		var id: StringName = first.resolve_voice_id(speaker)
		for i: int in range(LETTERS.length()):
			var ch: String = LETTERS.substr(i, 1)
			var a: GibberishVoice.Blip = first.make_blip(id, ch)
			var b: GibberishVoice.Blip = second.make_blip(id, ch)
			var c: GibberishVoice.Blip = first.make_blip(id, ch)
			assert_eq(a.stream_path, b.stream_path)
			assert_eq(a.stream_path, c.stream_path)
			assert_almost_eq(a.pitch_scale, b.pitch_scale, 0.000001)
			assert_almost_eq(a.volume_db, c.volume_db, 0.000001)


func test_same_letter_is_the_same_syllable_for_every_speaker() -> void:
	var voice: GibberishVoice = _make_voice()
	for i: int in range(LETTERS.length()):
		var ch: String = LETTERS.substr(i, 1)
		var syllables: Dictionary = {}
		for speaker: StringName in SPEAKERS:
			syllables[voice.make_blip(speaker, ch).syllable] = true
		assert_eq(syllables.size(), 1, "'%s' should be one syllable for everybody" % ch)


func test_vowels_and_consonants_use_different_syllables() -> void:
	var voice: GibberishVoice = _make_voice()
	for ch: String in ["a", "e", "i", "o", "u"]:
		assert_true(str(voice.make_blip(&"otis", ch).syllable).begins_with("v_"), "%s is a vowel syllable" % ch)
	for ch: String in ["b", "m", "s", "l", "t"]:
		assert_true(str(voice.make_blip(&"otis", ch).syllable).begins_with("c_"), "%s is a consonant syllable" % ch)
	assert_ne(voice.make_blip(&"otis", "b").syllable, voice.make_blip(&"otis", "s").syllable)
	assert_ne(voice.make_blip(&"otis", "a").syllable, voice.make_blip(&"otis", "i").syllable)


func test_case_is_ignored_for_the_syllable_but_shouts_are_a_bit_louder() -> void:
	var voice: GibberishVoice = _make_voice()
	var low: GibberishVoice.Blip = voice.make_blip(&"mox", "d")
	var high: GibberishVoice.Blip = voice.make_blip(&"mox", "D")
	assert_eq(low.syllable, high.syllable)
	assert_gt(high.volume_db, low.volume_db)
	assert_gt(high.pitch_scale, low.pitch_scale)


func test_digits_and_accents_are_deterministic_letters() -> void:
	var voice: GibberishVoice = _make_voice()
	assert_eq(voice.classify("7"), GibberishVoice.CharKind.LETTER)
	assert_eq(voice.classify("é"), GibberishVoice.CharKind.LETTER)
	assert_eq(voice.make_blip(&"vela", "7").stream_path, voice.make_blip(&"vela", "7").stream_path)


func test_pitch_offset_moves_one_npc_without_changing_the_syllable() -> void:
	var voice: GibberishVoice = _make_voice()
	var plain: GibberishVoice.Blip = voice.make_blip(&"townsfolk", "a")
	var up: GibberishVoice.Blip = voice.make_blip(&"townsfolk", "a", 12.0)
	assert_almost_eq(up.pitch_scale, plain.pitch_scale * 2.0, 0.0001)
	assert_eq(up.syllable, plain.syllable)


# ---- skipping, throttle, punctuation ----

func test_spaces_and_symbols_are_skipped() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	for ch: String in [" ", "\n", "\t", "'", "\"", "(", ")", "*", "#", ""]:
		assert_null(voice.step(&"otis", ch), "'%s' makes no sound" % ch.c_escape())
	assert_eq(voice.classify(" "), GibberishVoice.CharKind.SKIP)
	assert_eq(voice.classify("'"), GibberishVoice.CharKind.SKIP)


func test_spaces_do_not_use_up_the_throttle() -> void:
	var voice: GibberishVoice = _make_voice()
	# otis plays every 3rd letter; the spaces must not shift which letters play.
	var with_spaces: Array[GibberishVoice.Blip] = _feed(voice, &"otis", "ab c de f")
	voice.reset()
	var without: Array[GibberishVoice.Blip] = _feed(voice, &"otis", "abcdef")
	assert_eq(_count_played(with_spaces), _count_played(without))
	assert_eq(_count_played(without), 2)


func test_every_nth_letter_throttle() -> void:
	var voice: GibberishVoice = _make_voice()
	assert_eq(voice.every_nth_letter(&"otis"), 3)
	var blips: Array[GibberishVoice.Blip] = _feed(voice, &"otis", "abcdefghi")
	for i: int in range(blips.size()):
		assert_eq(blips[i] != null, i % 3 == 0, "letter %d" % i)
	voice.reset()
	var mox: Array[GibberishVoice.Blip] = _feed(voice, &"mox", "abcdefgh")
	for i: int in range(mox.size()):
		assert_eq(mox[i] != null, i % voice.every_nth_letter(&"mox") == 0, "mox letter %d" % i)


func test_throttle_of_one_plays_every_letter() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	assert_eq(_count_played(_feed(voice, &"mox", "hello")), 5)


func test_changing_speaker_restarts_the_throttle() -> void:
	var voice: GibberishVoice = _make_voice()
	_feed(voice, &"otis", "ab")
	assert_not_null(voice.step(&"mox", "a"), "a new speaker's first letter plays")


func test_red_never_makes_a_sound() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	assert_eq(_count_played(_feed(voice, RED, "Hello there! Is this?")), 0)


func test_question_mark_rises_and_exclamation_punches() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	var rise: GibberishVoice.Blip = voice.step(&"kasp", "?")
	assert_not_null(rise)
	assert_eq(rise.syllable, &"i_rise")
	assert_eq(rise.kind, GibberishVoice.KIND_RISE)
	assert_not_null(voice.step(&"kasp", "o"))
	var punch: GibberishVoice.Blip = voice.step(&"kasp", "!")
	assert_not_null(punch)
	assert_eq(punch.syllable, &"i_punch")
	var plain: GibberishVoice.Blip = voice.make_blip(&"kasp", "o")
	assert_gt(punch.volume_db, plain.volume_db, "! is louder than a letter")


func test_punctuation_runs_count_once() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	assert_eq(_count_played(_feed(voice, &"mox", "?!?!")), 1)
	voice.reset()
	assert_eq(_count_played(_feed(voice, &"mox", "?! ok?")), 1 + 2 + 1, "the run, then o, k, and a new ?")


func test_comma_makes_a_tiny_pause() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	var blips: Array[GibberishVoice.Blip] = _feed(voice, &"ruo", "ab,cde")
	assert_not_null(blips[0])
	assert_not_null(blips[1])
	assert_null(blips[2], "the comma itself is silent")
	assert_null(blips[3], "one letter of breath after a comma")
	assert_not_null(blips[4])
	assert_not_null(blips[5])


func test_full_stop_pause_is_longer_than_comma() -> void:
	var voice: GibberishVoice = _make_voice(_every_letter_doc())
	var blips: Array[GibberishVoice.Blip] = _feed(voice, &"ruo", "a.bcd")
	assert_null(blips[2])
	assert_null(blips[3])
	assert_not_null(blips[4])


func test_letters_after_punctuation_play_normally_again() -> void:
	var voice: GibberishVoice = _make_voice()
	var count: int = _count_played(_feed(voice, &"otis", "Hello there, friend. Welcome in!"))
	assert_gt(float(count), 3.0)
	assert_lt(float(count), 14.0, "throttled: far fewer blips than characters")
