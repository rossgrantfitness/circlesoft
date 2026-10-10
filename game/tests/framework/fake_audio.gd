class_name FakeAudio
extends RefCounted
## Stands in for AudioManager in UI tests: records every call the UI makes.

var sfx_ids: Array[String] = []
var voices: Array[String] = []
var voice_speakers: Array[String] = []
var reset_count: int = 0


func play_sfx(id: StringName) -> bool:
	sfx_ids.append(str(id))
	return true


func play_voice(speaker_id: StringName, character: String, _pitch: float = 0.0) -> bool:
	voice_speakers.append(str(speaker_id))
	voices.append(character)
	return true


func reset_voice() -> void:
	reset_count += 1
