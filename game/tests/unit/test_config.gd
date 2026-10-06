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
