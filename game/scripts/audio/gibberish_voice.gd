class_name GibberishVoice
extends RefCounted
## The "voiced gibberish" brain: turns typed characters into babble blips. Plain logic with no
## nodes and no audio, so tests run it headless. AudioManager owns one and plays what it returns.
##
## Rules (all numbers live in data/audio/voices.json):
##  - A letter or digit picks a syllable from the letter map. The same character always maps to
##    the same syllable and the same pitch offset for the same speaker (no randomness anywhere).
##    Vowels and consonants use different syllable shapes, so lines feel like a made-up language.
##  - Only every Nth letter plays (the speaker's every_nth_letter), so fast typing never machine-guns.
##  - Spaces and unmapped symbols are skipped. , ; : - make a tiny pause (a few silent letters,
##    then the phrase restarts); . makes a longer one; ? plays a rising swoop; ! plays a loud punch.
##    A run of punctuation ("?!", "...") only counts once.
##  - Red has no voice: silent speakers never play anything.

enum CharKind { SKIP, LETTER, PAUSE, LONG_PAUSE, RISE, PUNCH }

const KIND_LETTER: StringName = &"letter"
const KIND_RISE: StringName = &"rise"
const KIND_PUNCH: StringName = &"punch"
const SYLLABLE_RISE: StringName = &"i_rise"
const SYLLABLE_PUNCH: StringName = &"i_punch"
const VOWEL_PREFIX: String = "v_"
## Every syllable file a timbre folder must contain (the generator writes exactly these).
const SYLLABLES: Array[StringName] = [
	&"v_a", &"v_e", &"v_i", &"v_o", &"v_u",
	&"c_plosive", &"c_nasal", &"c_fricative", &"c_liquid", &"i_rise", &"i_punch",
]
const SEMITONES_PER_OCTAVE: float = 12.0
const LONG_PAUSE_FACTOR: int = 2
const DIGIT_FIRST: int = 48
const DIGIT_LAST: int = 57
const FIRST_NON_ASCII: int = 128
const MIN_PITCH_SCALE: float = 0.05


## One syllable to play.
class Blip extends RefCounted:
	var voice_id: StringName = &""
	var kind: StringName = KIND_LETTER
	var syllable: StringName = &""
	var stream_path: String = ""
	var pitch_scale: float = 1.0
	var volume_db: float = 0.0


var _folder: String = ""
var _settings: Dictionary = {}
var _timbres: Dictionary = {}
var _letters: Dictionary = {}
var _letter_keys: Array[String] = []
var _voices: Dictionary = {}
var _silent: Array[String] = []
var _aliases: Dictionary = {}
var _pause_chars: String = ""
var _long_pause_chars: String = ""
var _rise_chars: String = ""
var _punch_chars: String = ""

# Typing state (one stream of text at a time).
var _last_voice: StringName = &""
var _letter_counter: int = 0
var _pause_left: int = 0
var _in_punct_run: bool = false


## Loads the parsed voices.json. Returns a list of problems (empty = fine).
func load_data(doc: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_folder = str(doc.get("folder", ""))
	_settings = doc.get("settings", {})
	_timbres = doc.get("timbres", {})
	_letters = doc.get("letters", {})
	_voices = doc.get("voices", {})
	_aliases = doc.get("aliases", {})
	_silent.clear()
	for item: Variant in doc.get("silent_speakers", []):
		_silent.append(str(item))
	var punct: Dictionary = doc.get("punctuation", {})
	_pause_chars = str(punct.get("pause", ""))
	_long_pause_chars = str(punct.get("long_pause", ""))
	_rise_chars = str(punct.get("rise", ""))
	_punch_chars = str(punct.get("punch", ""))
	_letter_keys.clear()
	for key: Variant in _letters.keys():
		_letter_keys.append(str(key))
	_letter_keys.sort()
	reset()
	problems.append_array(_validate())
	return problems


func _validate() -> Array[String]:
	var problems: Array[String] = []
	if _folder.is_empty():
		problems.append("folder is missing")
	if _letters.is_empty():
		problems.append("letters map is empty")
	for key: String in _letter_keys:
		var entry: Dictionary = _letters[key]
		if not SYLLABLES.has(StringName(str(entry.get("syllable", "")))):
			problems.append("letter '%s' uses unknown syllable '%s'" % [key, entry.get("syllable", "")])
		var pitch: float = float(entry.get("pitch", 0.0))
		if pitch < -1.0 or pitch > 1.0:
			problems.append("letter '%s' pitch %s is outside -1..1" % [key, pitch])
	for timbre_id: String in _timbres:
		var info: Dictionary = _timbres[timbre_id]
		if float(info.get("ref_hz", 0.0)) <= 0.0 or str(info.get("dir", "")).is_empty():
			problems.append("timbre '%s' needs dir and ref_hz > 0" % timbre_id)
	if not _voices.has(str(_settings.get("fallback_voice", ""))):
		problems.append("fallback_voice is not a defined voice")
	for voice_id: String in _voices:
		var v: Dictionary = _voices[voice_id]
		if not _timbres.has(str(v.get("timbre", ""))):
			problems.append("voice '%s' uses unknown timbre '%s'" % [voice_id, v.get("timbre", "")])
		if float(v.get("base_pitch_hz", 0.0)) <= 0.0:
			problems.append("voice '%s' needs base_pitch_hz > 0" % voice_id)
		if int(v.get("every_nth_letter", 0)) < 1:
			problems.append("voice '%s' needs every_nth_letter >= 1" % voice_id)
		var volume: float = float(v.get("volume", -1.0))
		if volume < 0.0 or volume > 1.0:
			problems.append("voice '%s' volume must be 0..1" % voice_id)
		if _silent.has(voice_id):
			problems.append("'%s' is a silent speaker but also has a voice" % voice_id)
	return problems


# ---- who speaks ----

func is_silent(speaker_id: StringName) -> bool:
	return _silent.has(str(speaker_id))


## The voice id this speaker uses: a direct match, then an alias, then the fallback voice.
## Empty for silent speakers (Red) and for an empty speaker id.
func resolve_voice_id(speaker_id: StringName) -> StringName:
	var key: String = str(speaker_id)
	if key.is_empty() or _silent.has(key):
		return &""
	if _voices.has(key):
		return StringName(key)
	var alias: String = str(_aliases.get(key, ""))
	if _voices.has(alias):
		return StringName(alias)
	var fallback: String = str(_settings.get("fallback_voice", ""))
	if _voices.has(fallback):
		return StringName(fallback)
	return &""


func has_voice(speaker_id: StringName) -> bool:
	return resolve_voice_id(speaker_id) != &""


func voice_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in _voices.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func every_nth_letter(voice_id: StringName) -> int:
	return maxi(1, int(_voice_dict(voice_id).get("every_nth_letter", 1)))


## The file a syllable plays from for this voice's timbre.
func stream_path(voice_id: StringName, syllable: StringName) -> String:
	var timbre: Dictionary = _timbre_dict(voice_id)
	return _folder.path_join(str(timbre.get("dir", ""))).path_join("%s.wav" % syllable)


## Every stream path any voice could play (for preloading and for tests).
func all_stream_paths() -> Array[String]:
	var paths: Array[String] = []
	for timbre_id: String in _timbres:
		var dir: String = str((_timbres[timbre_id] as Dictionary).get("dir", ""))
		for syllable: StringName in SYLLABLES:
			var path: String = _folder.path_join(dir).path_join("%s.wav" % syllable)
			if not paths.has(path):
				paths.append(path)
	return paths


# ---- typing ----

## Forget the throttle and pause state. Call at the start of each line.
func reset() -> void:
	_last_voice = &""
	_letter_counter = 0
	_pause_left = 0
	_in_punct_run = false


## What kind of character this is (for the voice, not for display).
func classify(character: String) -> CharKind:
	if character.is_empty():
		return CharKind.SKIP
	var ch: String = character.substr(0, 1)
	if _rise_chars.contains(ch):
		return CharKind.RISE
	if _punch_chars.contains(ch):
		return CharKind.PUNCH
	if _long_pause_chars.contains(ch):
		return CharKind.LONG_PAUSE
	if _pause_chars.contains(ch):
		return CharKind.PAUSE
	if _letters.has(ch.to_lower()):
		return CharKind.LETTER
	var code: int = ch.unicode_at(0)
	if code >= DIGIT_FIRST and code <= DIGIT_LAST:
		return CharKind.LETTER
	if code >= FIRST_NON_ASCII and ch.to_lower() != ch.to_upper():
		return CharKind.LETTER
	return CharKind.SKIP


## Feed one typed character. Returns the blip to play, or null for silence (space, symbol,
## throttled letter, pause, silent speaker). pitch_offset_semitones tunes a single NPC's voice.
func step(speaker_id: StringName, character: String, pitch_offset_semitones: float = 0.0) -> Blip:
	var voice_id: StringName = resolve_voice_id(speaker_id)
	if voice_id == &"":
		return null
	if voice_id != _last_voice:
		reset()
		_last_voice = voice_id
	match classify(character):
		CharKind.LETTER:
			_in_punct_run = false
			if _pause_left > 0:
				_pause_left -= 1
				return null
			var play_now: bool = _letter_counter % every_nth_letter(voice_id) == 0
			_letter_counter += 1
			if not play_now:
				return null
			return make_blip(voice_id, character, pitch_offset_semitones)
		CharKind.PAUSE:
			_start_pause(1)
		CharKind.LONG_PAUSE:
			_start_pause(LONG_PAUSE_FACTOR)
		CharKind.RISE:
			if not _in_punct_run:
				_in_punct_run = true
				_pause_left = 0
				return _make_inflection(voice_id, KIND_RISE, pitch_offset_semitones)
		CharKind.PUNCH:
			if not _in_punct_run:
				_in_punct_run = true
				_pause_left = 0
				return _make_inflection(voice_id, KIND_PUNCH, pitch_offset_semitones)
	return null


func _start_pause(factor: int) -> void:
	if _in_punct_run:
		return
	_in_punct_run = true
	_pause_left = int(_settings.get("pause_letters", 1)) * factor
	_letter_counter = 0


## The blip a letter makes, ignoring the throttle. Same inputs always give the same blip.
func make_blip(voice_id: StringName, character: String, pitch_offset_semitones: float = 0.0) -> Blip:
	var voice: Dictionary = _voice_dict(voice_id)
	if voice.is_empty() or character.is_empty():
		return null
	var ch: String = character.substr(0, 1)
	var lower: String = ch.to_lower()
	var entry: Dictionary = _letter_entry(lower, ch)
	var syllable: StringName = StringName(str(entry.get("syllable", "")))
	var is_vowel: bool = str(syllable).begins_with(VOWEL_PREFIX)
	var half_range: float = float(voice.get("pitch_range_semitones", 0.0)) * 0.5
	var semitones: float = float(entry.get("pitch", 0.0)) * half_range
	var gain: float = float(voice.get("volume", 1.0))
	if is_vowel:
		semitones = semitones * float(voice.get("vowel_spread", 1.0)) + float(voice.get("vowel_shift_semitones", 0.0))
	else:
		gain *= float(_settings.get("consonant_gain", 1.0))
	var extra_db: float = 0.0
	if ch != lower:
		semitones += float(_settings.get("uppercase_boost_semitones", 0.0))
		extra_db += float(_settings.get("uppercase_boost_db", 0.0))
	return _build_blip(voice_id, KIND_LETTER, syllable, semitones + pitch_offset_semitones, gain, extra_db)


func _make_inflection(voice_id: StringName, kind: StringName, pitch_offset_semitones: float) -> Blip:
	var voice: Dictionary = _voice_dict(voice_id)
	var gain: float = float(voice.get("volume", 1.0))
	if kind == KIND_RISE:
		return _build_blip(voice_id, kind, SYLLABLE_RISE,
				float(voice.get("rise_semitones", 0.0)) + pitch_offset_semitones, gain, 0.0)
	var lift: float = float(voice.get("pitch_range_semitones", 0.0)) * 0.25
	return _build_blip(voice_id, kind, SYLLABLE_PUNCH, lift + pitch_offset_semitones, gain,
			float(voice.get("punch_boost_db", 0.0)))


func _build_blip(voice_id: StringName, kind: StringName, syllable: StringName, semitones: float,
		gain: float, extra_db: float) -> Blip:
	var voice: Dictionary = _voice_dict(voice_id)
	var ref_hz: float = float(_timbre_dict(voice_id).get("ref_hz", 1.0))
	var blip: Blip = Blip.new()
	blip.voice_id = voice_id
	blip.kind = kind
	blip.syllable = syllable
	blip.stream_path = stream_path(voice_id, syllable)
	blip.pitch_scale = maxf(MIN_PITCH_SCALE,
			float(voice.get("base_pitch_hz", ref_hz)) / ref_hz * pow(2.0, semitones / SEMITONES_PER_OCTAVE))
	blip.volume_db = linear_to_db(maxf(gain, 0.0001)) + extra_db
	return blip


## Mapped letters use the table; digits and accented letters pick a table entry from their
## character code (still fixed per character, so still a "language").
func _letter_entry(lower: String, original: String) -> Dictionary:
	if _letters.has(lower):
		return _letters[lower]
	if _letter_keys.is_empty():
		return {}
	var index: int = original.unicode_at(0) % _letter_keys.size()
	return _letters[_letter_keys[index]]


func _voice_dict(voice_id: StringName) -> Dictionary:
	return _voices.get(str(voice_id), {})


func _timbre_dict(voice_id: StringName) -> Dictionary:
	return _timbres.get(str(_voice_dict(voice_id).get("timbre", "")), {})
