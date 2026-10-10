extends TestCase
## FeelKnobs: load, overlay, clamp, unknown ids, save round trip.

const TEST_DIR: String = "user://feel_test"


func _small() -> FeelKnobs:
	return FeelKnobs.from_data({"knobs": [
		{"id": "a_float", "group": "g", "label": "A", "type": "float", "value": 1.0, "min": 0.0, "max": 2.0, "step": 0.1},
		{"id": "an_int", "group": "g", "label": "I", "type": "int", "value": 5, "min": 0, "max": 10, "step": 1},
		{"id": "a_bool", "group": "g", "label": "B", "type": "bool", "value": true},
		{"id": "a_choice", "group": "g", "label": "C", "type": "choice", "value": "x", "options": ["x", "y", "z"]},
	]})


func after_each() -> void:
	DirAccess.remove_absolute(TEST_DIR.path_join("feel_current.json"))


func test_the_real_file_loads_with_unique_ids_and_defaults_inside_limits() -> void:
	var knobs: FeelKnobs = FeelKnobs.load_defaults()
	var seen: Dictionary = {}
	for knob: Dictionary in knobs.knobs():
		var id: String = knob["id"]
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true
		if knob["type"] == "float" or knob["type"] == "int":
			assert_ge(float(knob["value"]), float(knob["min"]), id)
			assert_le(float(knob["value"]), float(knob["max"]), id)
		if knob["type"] == "choice":
			assert_has(knob["options"], knob["value"], id)
	for id: String in ["hit_stop_scale", "juggle_float", "launch_height_scale", "input_buffer_ms", "parry_window_scale",
			"flare_duration_s", "flare_enemy_speed", "perfect_dodge_window_ms", "flare_glare_radius_m",
			"launcher_input", "lights_on_trigger", "flare_on_parry", "enemies_attack", "show_hitboxes",
			"run_speed_mps", "dash_distance_m", "shake_scale"]:
		assert_true(knobs.has(id), id)
	assert_eq(knobs.get_s("launcher_input"), "hold_heavy")
	assert_almost_eq(knobs.get_f("flare_enemy_speed"), 0.25)
	assert_true(knobs.get_b("enemies_attack"))


func test_values_read_back_in_their_own_type() -> void:
	var knobs: FeelKnobs = _small()
	assert_almost_eq(knobs.get_f("a_float"), 1.0)
	assert_almost_eq(knobs.get_f("an_int"), 5.0)
	assert_true(knobs.get_b("a_bool"))
	assert_eq(knobs.get_s("a_choice"), "x")


func test_numbers_are_clamped_and_ints_rounded() -> void:
	var knobs: FeelKnobs = _small()
	knobs.set_value("a_float", 99.0)
	assert_almost_eq(knobs.get_f("a_float"), 2.0)
	knobs.set_value("a_float", -3)
	assert_almost_eq(knobs.get_f("a_float"), 0.0)
	knobs.set_value("an_int", 7.6)
	assert_almost_eq(knobs.get_f("an_int"), 8.0)
	knobs.set_value("an_int", 400)
	assert_almost_eq(knobs.get_f("an_int"), 10.0)


func test_a_bad_choice_or_wrong_type_is_ignored() -> void:
	var knobs: FeelKnobs = _small()
	knobs.set_value("a_choice", "nope")
	assert_eq(knobs.get_s("a_choice"), "x")
	knobs.set_value("a_choice", "z")
	assert_eq(knobs.get_s("a_choice"), "z")
	knobs.set_value("a_float", "text")
	assert_almost_eq(knobs.get_f("a_float"), 1.0)
	knobs.set_value("a_bool", false)
	assert_false(knobs.get_b("a_bool"))


func test_unknown_ids_are_ignored_and_read_as_zero() -> void:
	var knobs: FeelKnobs = _small()
	knobs.overlay({"nope": 3, "a_float": 0.5})
	assert_almost_eq(knobs.get_f("a_float"), 0.5)
	assert_almost_eq(knobs.get_f("nope"), 0.0)
	assert_false(knobs.get_b("nope"))
	assert_eq(knobs.get_s("nope"), "")
	assert_false(knobs.has("nope"))


func test_changed_signal_fires_only_on_a_real_change() -> void:
	var knobs: FeelKnobs = _small()
	var log: Array[String] = []
	knobs.changed.connect(func(id: String, value: Variant) -> void: log.append("%s=%s" % [id, str(value)]))
	knobs.set_value("a_float", 1.0)
	knobs.set_value("a_float", 1.5)
	knobs.set_value("a_float", 1.5)
	assert_eq(log, ["a_float=1.5"] as Array[String])


func test_reset_and_defaults() -> void:
	var knobs: FeelKnobs = _small()
	knobs.set_value("an_int", 9)
	assert_false(knobs.is_default("an_int"))
	assert_eq(knobs.default_of("an_int"), 5)
	knobs.reset_to_defaults()
	assert_true(knobs.is_default("an_int"))
	assert_almost_eq(knobs.get_f("an_int"), 5.0)


func test_knobs_list_is_a_copy_with_defaults() -> void:
	var knobs: FeelKnobs = _small()
	knobs.set_value("a_float", 1.7)
	var list: Array[Dictionary] = knobs.knobs()
	assert_eq(list.size(), 4)
	assert_almost_eq(float(list[0]["value"]), 1.7)
	assert_almost_eq(float(list[0]["default"]), 1.0)
	list[0]["value"] = 0.0
	assert_almost_eq(knobs.get_f("a_float"), 1.7, 0.0001, "editing the copy changes nothing")


func test_save_round_trip() -> void:
	var knobs: FeelKnobs = _small()
	knobs.set_value("a_float", 1.3)
	knobs.set_value("a_choice", "y")
	knobs.set_value("a_bool", false)
	var path: String = knobs.save_user(TEST_DIR)
	assert_false(path.is_empty())
	assert_true(FileAccess.file_exists(path))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_has(saved, "version")
	assert_has(saved, "saved_at")
	assert_has(saved, "build")
	assert_almost_eq(float(saved["values"]["a_float"]), 1.3)
	var fresh: FeelKnobs = _small()
	assert_true(fresh.load_user(TEST_DIR))
	assert_almost_eq(fresh.get_f("a_float"), 1.3)
	assert_eq(fresh.get_s("a_choice"), "y")
	assert_false(fresh.get_b("a_bool"))
	var dated: int = 0
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		if file_name.begins_with("feel_20") or file_name.begins_with("feel_2"):
			dated += 1
			DirAccess.remove_absolute(TEST_DIR.path_join(file_name))
	assert_ge(dated, 1, "a dated copy was written too")


func test_load_user_without_a_file_changes_nothing() -> void:
	var knobs: FeelKnobs = _small()
	assert_false(knobs.load_user("user://feel_test_missing"))
	assert_almost_eq(knobs.get_f("a_float"), 1.0)


func test_a_saved_value_out_of_range_is_clamped_on_load() -> void:
	var knobs: FeelKnobs = _small()
	knobs.overlay({"a_float": 50.0, "a_choice": "bogus"})
	assert_almost_eq(knobs.get_f("a_float"), 2.0)
	assert_eq(knobs.get_s("a_choice"), "x")
