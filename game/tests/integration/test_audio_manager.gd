extends TestCase
## AudioManager: buses, volume API, sfx and voice calls. Everything must be safe with no audio device.

const ManagerScript: GDScript = preload("res://scripts/audio/audio_manager.gd")


func _manager() -> Node:
	return add_to_root(ManagerScript.new()) as Node


func after_each() -> void:
	for bus: StringName in [&"Master", &"Music", &"SFX", &"Voice"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, 0.0)
			AudioServer.set_bus_mute(index, false)


func test_autoload_exists_and_has_data() -> void:
	var audio: Node = tree.root.get_node("AudioManager")
	assert_true(audio.has_method("play_sfx"))
	assert_true(audio.has_method("play_voice"))
	assert_true(audio.has_sfx(&"menu_tick"))
	assert_true(audio.get_voice_logic().has_voice(&"otis"))
	assert_false(audio.is_playback_enabled(), "headless: no playback")


func test_all_four_buses_exist() -> void:
	_manager()
	for bus: StringName in [&"Master", &"Music", &"SFX", &"Voice"]:
		assert_ge(float(AudioServer.get_bus_index(bus)), 0.0, "bus %s" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Voice")), &"Master")


func test_ensure_buses_twice_adds_nothing() -> void:
	var audio: Node = _manager()
	var count: int = AudioServer.get_bus_count()
	audio.ensure_buses()
	assert_eq(AudioServer.get_bus_count(), count)


func test_bus_volume_api() -> void:
	var audio: Node = _manager()
	assert_true(audio.set_bus_volume(&"Music", 0.5))
	assert_almost_eq(audio.get_bus_volume(&"Music"), 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.5), 0.001)
	audio.set_bus_volume(&"Music", 2.0)
	assert_almost_eq(audio.get_bus_volume(&"Music"), 1.0, 0.0001, "clamped to 1")
	audio.set_bus_volume(&"Music", -1.0)
	assert_almost_eq(audio.get_bus_volume(&"Music"), 0.0, 0.0001, "clamped to 0")
	assert_lt(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), -60.0, "0 is effectively silent")
	assert_false(audio.set_bus_volume(&"NoSuchBus", 0.5))


func test_mute_and_voice_volume_hooks() -> void:
	var audio: Node = _manager()
	audio.set_voice_volume(0.25)
	assert_almost_eq(audio.get_bus_volume(&"Voice"), 0.25)
	assert_true(audio.set_bus_muted(&"SFX", true))
	assert_true(audio.is_bus_muted(&"SFX"))
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))
	audio.set_all_muted(true)
	assert_true(audio.is_bus_muted(&"Master"))
	audio.set_all_muted(false)
	assert_false(audio.is_bus_muted(&"Master"))
	assert_false(audio.set_bus_muted(&"NoSuchBus", true))


func test_settings_round_trip() -> void:
	var audio: Node = _manager()
	audio.set_bus_volume(&"SFX", 0.4)
	audio.set_voice_volume(0.6)
	audio.set_voices_enabled(false)
	var saved: Dictionary = audio.get_settings()
	var other: Node = _manager()
	other.apply_settings(saved)
	assert_almost_eq(other.get_bus_volume(&"SFX"), 0.4)
	assert_almost_eq(other.get_bus_volume(&"Voice"), 0.6)
	assert_false(other.are_voices_enabled())


func test_play_sfx_known_and_unknown_do_not_crash() -> void:
	var audio: Node = _manager()
	for id: String in ["menu_tick", "menu_confirm", "menu_back", "bubble_open", "bubble_next", "item_get",
			"red_thumbs_up", "red_head_shake"]:
		assert_true(audio.play_sfx(StringName(id)), id)
	assert_eq(audio.last_sfx_id, &"red_head_shake")
	assert_false(audio.play_sfx(&"definitely_not_a_sound"))
	assert_false(audio.play_sfx(&""))


func test_play_voice_headless_is_safe_and_counts() -> void:
	var audio: Node = _manager()
	var played: int = 0
	for ch: String in "Hello, there! Is it you?".split("", false):
		if audio.play_voice(&"otis", ch):
			played += 1
	assert_gt(float(played), 2.0)
	assert_eq(audio.voice_blips_played, played)
	assert_not_null(audio.last_voice_blip)
	assert_false(audio.play_voice(&"red", "H"), "Red has no voice")
	assert_false(audio.play_voice(&"otis", " "), "space")
	assert_false(audio.play_voice(&"otis", ""), "empty")


func test_voices_can_be_switched_off() -> void:
	var audio: Node = _manager()
	audio.set_voices_enabled(false)
	for ch: String in "Hello".split("", false):
		assert_false(audio.play_voice(&"mox", ch))
	assert_eq(audio.voice_blips_played, 0)


func test_reset_voice_makes_the_next_letter_play() -> void:
	var audio: Node = _manager()
	assert_true(audio.play_voice(&"otis", "a"))
	assert_false(audio.play_voice(&"otis", "b"), "throttled")
	audio.reset_voice()
	assert_true(audio.play_voice(&"otis", "b"), "new line starts on the first letter")


func test_playback_path_runs_on_the_dummy_driver() -> void:
	var audio: Node = _manager()
	audio.set_playback_enabled(true)
	assert_true(audio.is_playback_enabled())
	assert_true(audio.play_voice(&"mox", "w"))
	assert_true(audio.play_voice(&"kasp", "?"))
	assert_true(audio.play_sfx(&"item_get"))
	for i: int in range(20):
		audio.play_sfx(&"menu_tick")
	audio.set_playback_enabled(false)


func test_missing_file_is_silent_not_a_crash() -> void:
	var audio: Node = _manager()
	audio.load_sfx_data({"sfx": {"ghost": {"file": "res://audio/sfx/nope.wav", "bus": "SFX"}}})
	audio.set_playback_enabled(true)
	assert_true(audio.play_sfx(&"ghost"))
	audio.set_playback_enabled(false)
