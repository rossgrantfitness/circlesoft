extends TestCase
## Config: text speed, voice volume and Auto-Timing, and the settings file round trip.

const SCRIPT_PATH: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_config_scratch.json"


func _make() -> Node:
	var config: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	config.set("save_path", SCRATCH)
	return config


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_defaults() -> void:
	var config: Node = _make()
	assert_eq(config.get("text_speed"), "normal")
	assert_false(config.get("auto_timing"))
	assert_almost_eq(config.get("voice_volume"), 0.8)


func test_text_speed_ids_come_from_data_in_order() -> void:
	var config: Node = _make()
	assert_eq(config.call("get_text_speed_ids"), ["slow", "normal", "fast"])


func test_text_speed_changes_chars_per_second() -> void:
	var config: Node = _make()
	var normal: float = config.call("get_text_cps")
	config.call("set_text_speed", "fast")
	assert_gt(config.call("get_text_cps"), normal)
	config.call("set_text_speed", "slow")
	assert_lt(config.call("get_text_cps"), normal)


func test_unknown_text_speed_is_ignored() -> void:
	var config: Node = _make()
	config.call("set_text_speed", "warp_nine")
	assert_eq(config.get("text_speed"), "normal")


func test_step_text_speed_clamps() -> void:
	var config: Node = _make()
	assert_true(config.call("step_text_speed", 1))
	assert_eq(config.get("text_speed"), "fast")
	assert_false(config.call("step_text_speed", 1), "no wrap past fast")
	config.call("step_text_speed", -1)
	config.call("step_text_speed", -1)
	assert_eq(config.get("text_speed"), "slow")


func test_voice_volume_is_clamped_and_signals() -> void:
	var config: Node = _make()
	var seen: Array[String] = []
	config.connect("setting_changed", func(key: String) -> void: seen.append(key))
	config.call("set_voice_volume", 1.7)
	assert_almost_eq(config.get("voice_volume"), 1.0)
	config.call("set_voice_volume", -3.0)
	assert_almost_eq(config.get("voice_volume"), 0.0)
	assert_eq(seen, ["voice_volume", "voice_volume"])


func test_save_and_load_round_trip() -> void:
	var config: Node = _make()
	config.call("set_text_speed", "slow")
	config.call("set_voice_volume", 0.3)
	config.call("set_auto_timing", true)
	assert_true(config.call("save_file"))
	var other: Node = _make()
	assert_true(other.call("load_file"))
	assert_eq(other.get("text_speed"), "slow")
	assert_almost_eq(other.get("voice_volume"), 0.3)
	assert_true(other.get("auto_timing"))


func test_loading_with_no_file_changes_nothing() -> void:
	var config: Node = _make()
	assert_false(config.call("load_file"))
	assert_eq(config.get("text_speed"), "normal")


# ---- the M3 settings (Config screen) ----

func test_new_settings_have_sensible_defaults() -> void:
	var config: Node = _make()
	assert_almost_eq(config.get("master_volume"), 1.0)
	assert_almost_eq(config.get("music_volume"), 0.8)
	assert_almost_eq(config.get("sfx_volume"), 1.0)
	assert_false(config.get("auto_advance"))
	assert_false(config.get("skip_seen_cutscenes"))
	assert_true(config.get("vibration"))
	assert_eq(config.get("bindings"), {})


func test_volumes_are_clamped_snapped_and_signal() -> void:
	var config: Node = _make()
	var seen: Array[String] = []
	config.connect("setting_changed", func(key: String) -> void: seen.append(key))
	config.call("set_volume", "music", 0.456)
	assert_almost_eq(config.call("get_volume", "music"), 0.46)
	config.call("set_volume", "sfx", 9.0)
	assert_almost_eq(config.get("sfx_volume"), 1.0)
	config.call("set_volume", "master", -1.0)
	assert_almost_eq(config.get("master_volume"), 0.0)
	config.call("set_volume", "voice", 0.5)
	assert_almost_eq(config.get("voice_volume"), 0.5, 0.0001, "voice goes through the older setter")
	config.call("set_volume", "nonsense", 0.5)
	assert_eq(seen, ["music_volume", "master_volume", "voice_volume"], "a value that clamps to what it already was changes nothing")


func test_every_setting_survives_a_save_and_load() -> void:
	var config: Node = _make()
	config.set("apply_bindings_live", false)
	config.call("set_text_speed", "fast")
	config.call("set_auto_timing", true)
	config.call("set_wide_windows", true)
	config.call("set_timing_offset_ms", -40)
	config.call("set_volume", "master", 0.6)
	config.call("set_volume", "music", 0.3)
	config.call("set_volume", "sfx", 0.7)
	config.call("set_volume", "voice", 0.2)
	config.call("set_auto_advance", true)
	config.call("set_skip_seen_cutscenes", true)
	config.call("set_vibration", false)
	assert_true(config.call("save_file"))
	var other: Node = _make()
	other.set("apply_bindings_live", false)
	assert_true(other.call("load_file"))
	assert_eq(other.get("text_speed"), "fast")
	assert_true(other.get("auto_timing"))
	assert_true(other.get("wide_windows"))
	assert_eq(other.get("timing_offset_ms"), -40)
	assert_almost_eq(other.get("master_volume"), 0.6)
	assert_almost_eq(other.get("music_volume"), 0.3)
	assert_almost_eq(other.get("sfx_volume"), 0.7)
	assert_almost_eq(other.get("voice_volume"), 0.2)
	assert_true(other.get("auto_advance"))
	assert_true(other.get("skip_seen_cutscenes"))
	assert_false(other.get("vibration"))


func test_button_remaps_survive_a_save_and_load() -> void:
	var config: Node = _make()
	config.set("apply_bindings_live", false)
	assert_eq(config.call("set_binding", "jump", "key", KEY_Q), "", "no swap for a free key")
	assert_eq(config.call("set_binding", "jump", "pad", JOY_BUTTON_Y), "menu", "Y is Menu's button, so they swap")
	assert_true(config.call("save_file"))
	var other: Node = _make()
	other.set("apply_bindings_live", false)
	assert_true(other.call("load_file"))
	var effective: Dictionary = other.call("get_effective_bindings")
	assert_eq(effective["jump"]["key"], KEY_Q)
	assert_eq(effective["jump"]["pad"], JOY_BUTTON_Y)
	assert_eq(effective["menu"]["pad"], JOY_BUTTON_A, "Menu took Jump's old button")
	assert_eq(other.get("bindings"), config.get("bindings"))
	assert_eq(effective["cancel"]["key"], KEY_X, "untouched buttons stay on their defaults")


func test_reserved_keys_are_refused_and_clear_bindings_resets() -> void:
	var config: Node = _make()
	config.set("apply_bindings_live", false)
	config.call("set_binding", "jump", "key", KEY_W)
	assert_eq(config.get("bindings"), {}, "movement keys can't be bound")
	config.call("set_binding", "jump", "key", KEY_Q)
	assert_ne(config.get("bindings"), {})
	config.call("clear_bindings")
	assert_eq(config.get("bindings"), {})


func test_a_file_with_garbage_bindings_loads_without_them() -> void:
	var file: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"text_speed": "slow", "bindings": {"jump": "oops", "run": {"key": 81.0, "junk": 3}}}))
	file.close()
	var config: Node = _make()
	config.set("apply_bindings_live", false)
	assert_true(config.call("load_file"))
	assert_eq(config.get("text_speed"), "slow")
	assert_eq(config.get("bindings"), {"run": {"key": 81}})


func test_an_old_file_without_the_new_keys_still_loads() -> void:
	var file: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"text_speed": "slow", "voice_volume": 0.4, "auto_timing": true}))
	file.close()
	var config: Node = _make()
	assert_true(config.call("load_file"))
	assert_eq(config.get("text_speed"), "slow")
	assert_true(config.get("auto_timing"))
	assert_almost_eq(config.get("music_volume"), 0.8, 0.0001, "missing keys keep their defaults")
	assert_true(config.get("vibration"))
