extends TestCase
## Config: the battle timing options (Auto-Timing, Wide Windows, timing offset in ms) persist, stay
## inside their range, and old settings files without them still load.

const SCRIPT_PATH: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_battle_hud_config_scratch.json"


func _make() -> Node:
	var config: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	config.set("save_path", SCRATCH)
	return config


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_defaults_are_off_and_zero() -> void:
	var config: Node = _make()
	assert_false(config.get("auto_timing"))
	assert_false(config.get("wide_windows"))
	assert_eq(config.get("timing_offset_ms"), 0)


func test_new_options_round_trip_through_the_file() -> void:
	var config: Node = _make()
	config.call("set_auto_timing", true)
	config.call("set_wide_windows", true)
	config.call("set_timing_offset_ms", -40)
	assert_true(config.call("save_file"))
	var other: Node = _make()
	assert_true(other.call("load_file"))
	assert_true(other.get("auto_timing"))
	assert_true(other.get("wide_windows"))
	assert_eq(other.get("timing_offset_ms"), -40)


func test_an_old_settings_file_still_loads_and_keeps_defaults() -> void:
	var file: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string('{"text_speed": "slow", "voice_volume": 0.5, "auto_timing": true}')
	file.close()
	var config: Node = _make()
	assert_true(config.call("load_file"))
	assert_eq(config.get("text_speed"), "slow")
	assert_true(config.get("auto_timing"))
	assert_false(config.get("wide_windows"))
	assert_eq(config.get("timing_offset_ms"), 0)


func test_saved_file_lists_every_key() -> void:
	var config: Node = _make()
	config.call("save_file")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH))
	for key: String in ["text_speed", "voice_volume", "auto_timing", "wide_windows", "timing_offset_ms"]:
		assert_true(saved.has(key), key)


func test_timing_offset_is_clamped_to_the_data_range() -> void:
	var config: Node = _make()
	var low: int = config.call("get_timing_offset_min_ms")
	var high: int = config.call("get_timing_offset_max_ms")
	assert_lt(low, 0)
	assert_gt(high, 0)
	config.call("set_timing_offset_ms", high + 500)
	assert_eq(config.get("timing_offset_ms"), high)
	config.call("set_timing_offset_ms", low - 500)
	assert_eq(config.get("timing_offset_ms"), low)


func test_a_wild_value_in_the_file_is_clamped_on_load() -> void:
	var file: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string('{"timing_offset_ms": 99999}')
	file.close()
	var config: Node = _make()
	config.call("load_file")
	assert_eq(config.get("timing_offset_ms"), config.call("get_timing_offset_max_ms"))


func test_stepping_the_offset_moves_by_the_data_step_and_stops_at_the_ends() -> void:
	var config: Node = _make()
	var step: int = config.call("get_timing_offset_step_ms")
	assert_gt(step, 0)
	assert_true(config.call("step_timing_offset", 1))
	assert_eq(config.get("timing_offset_ms"), step)
	config.call("set_timing_offset_ms", config.call("get_timing_offset_max_ms"))
	assert_false(config.call("step_timing_offset", 1), "no wrap past the top")
	config.call("set_timing_offset_ms", config.call("get_timing_offset_min_ms"))
	assert_false(config.call("step_timing_offset", -1), "no wrap past the bottom")


func test_changes_fire_setting_changed_once() -> void:
	var config: Node = _make()
	var seen: Array[String] = []
	config.connect("setting_changed", func(key: String) -> void: seen.append(key))
	config.call("set_wide_windows", true)
	config.call("set_wide_windows", true)
	config.call("set_timing_offset_ms", 20)
	config.call("set_timing_offset_ms", 20)
	assert_eq(seen, ["wide_windows", "timing_offset_ms"])


func test_battle_timing_dictionary_matches_the_battle_setup_fields() -> void:
	var config: Node = _make()
	config.call("set_auto_timing", true)
	config.call("set_timing_offset_ms", 30)
	var timing: Dictionary = config.call("get_battle_timing")
	assert_eq(timing, {"auto_timing": true, "wide_windows": false, "timing_offset_ms": 30})
