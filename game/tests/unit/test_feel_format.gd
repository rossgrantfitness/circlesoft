extends TestCase
## FeelFormat: how a knob from data/combat/feel.json is stepped, snapped, shown and explained in the
## feel-knobs panel. Pure, no scene.

const DASH: Dictionary = {"id": "dash_distance_m", "group": "movement", "label": "Dash distance", "type": "float", "value": 4.0, "min": 2.0, "max": 8.0, "step": 0.25, "unit": "m"}
const BUFFER: Dictionary = {"id": "input_buffer_ms", "group": "combat", "label": "Input buffer", "type": "int", "value": 150, "min": 0, "max": 400, "step": 10, "unit": "ms"}
const SPEED: Dictionary = {"id": "run_speed_mps", "group": "movement", "label": "Run speed", "type": "float", "value": 6.0, "min": 3.0, "max": 10.0, "step": 0.25, "unit": "m/s"}
const TRAILS: Dictionary = {"id": "trails_on", "group": "fx", "label": "Sword trails", "type": "bool", "value": true}
const LAUNCH: Dictionary = {"id": "launcher_input", "group": "combat", "label": "Launcher button", "type": "choice", "value": "hold_heavy", "options": ["hold_heavy", "back_heavy", "string_end"]}


func test_kinds_and_defaults_for_missing_fields() -> void:
	assert_eq(FeelFormat.kind_of(DASH), "float")
	assert_eq(FeelFormat.kind_of(BUFFER), "int")
	assert_eq(FeelFormat.kind_of(TRAILS), "bool")
	assert_eq(FeelFormat.kind_of(LAUNCH), "choice")
	assert_eq(FeelFormat.kind_of({"id": "x"}), "float", "no type counts as a float")
	assert_true(FeelFormat.is_slider(DASH))
	assert_true(FeelFormat.is_slider(BUFFER))
	assert_false(FeelFormat.is_slider(TRAILS))
	assert_almost_eq(FeelFormat.step_of({"min": 0.0, "max": 10.0}), 0.1, 0.0001, "no step: a hundredth of the range")
	assert_almost_eq(FeelFormat.step_of({"type": "int", "min": 0, "max": 500}), 1.0, 0.0001, "no step on an int: whole numbers")


func test_decimals_follow_the_step() -> void:
	assert_eq(FeelFormat.decimals_for(1.0), 0)
	assert_eq(FeelFormat.decimals_for(10.0), 0)
	assert_eq(FeelFormat.decimals_for(0.5), 1)
	assert_eq(FeelFormat.decimals_for(0.1), 1)
	assert_eq(FeelFormat.decimals_for(0.25), 2)
	assert_eq(FeelFormat.decimals_for(0.05), 2)


func test_snap_clamps_and_lands_on_a_step() -> void:
	assert_almost_eq(FeelFormat.snap(DASH, 4.1), 4.0, 0.0001)
	assert_almost_eq(FeelFormat.snap(DASH, 4.2), 4.25, 0.0001)
	assert_almost_eq(FeelFormat.snap(DASH, 99.0), 8.0, 0.0001, "clamped to the top")
	assert_almost_eq(FeelFormat.snap(DASH, -3.0), 2.0, 0.0001, "clamped to the bottom")
	assert_almost_eq(FeelFormat.snap(BUFFER, 157.0), 160.0, 0.0001)
	var gravity: Dictionary = {"min": 0.5, "max": 2.0, "step": 0.05}
	assert_almost_eq(FeelFormat.snap(gravity, 1.0 + 0.05 * 3.0), 1.15, 0.00001, "no float drift after stepping")


func test_stepping_stops_at_the_ends_and_never_drifts() -> void:
	var value: float = 4.0
	for i: int in 3:
		value = FeelFormat.step_number(DASH, value, 1)
	assert_almost_eq(value, 4.75, 0.00001)
	assert_almost_eq(FeelFormat.step_number(DASH, 7.9, 5), 8.0, 0.00001, "stops at the top")
	assert_almost_eq(FeelFormat.step_number(DASH, 2.1, -5), 2.0, 0.00001, "stops at the bottom")
	assert_almost_eq(FeelFormat.step_number(BUFFER, 150.0, 4), 190.0, 0.00001, "several steps at once (hold to go faster)")


func test_slider_fraction_and_back() -> void:
	assert_almost_eq(FeelFormat.fraction(DASH, 2.0), 0.0, 0.0001)
	assert_almost_eq(FeelFormat.fraction(DASH, 8.0), 1.0, 0.0001)
	assert_almost_eq(FeelFormat.fraction(DASH, 4.0), 1.0 / 3.0, 0.0001)
	assert_almost_eq(FeelFormat.value_at(DASH, 0.5), 5.0, 0.0001)
	assert_almost_eq(FeelFormat.value_at(DASH, 1.7), 8.0, 0.0001, "a drag past the end stays on the end")
	assert_almost_eq(FeelFormat.value_at(DASH, -0.4), 2.0, 0.0001)


func test_choices_cycle_and_wrap() -> void:
	assert_eq(FeelFormat.cycle_choice(LAUNCH, "hold_heavy", 1), "back_heavy")
	assert_eq(FeelFormat.cycle_choice(LAUNCH, "string_end", 1), "hold_heavy", "wraps forward")
	assert_eq(FeelFormat.cycle_choice(LAUNCH, "hold_heavy", -1), "string_end", "wraps back")
	assert_eq(FeelFormat.cycle_choice(LAUNCH, "nonsense", 1), "hold_heavy", "an unknown value starts at the first option")


func test_value_text_shows_the_unit_and_plain_names() -> void:
	assert_eq(FeelFormat.value_text(DASH, 4.0), "4.00 m")
	assert_eq(FeelFormat.value_text(BUFFER, 150), "150 ms")
	assert_eq(FeelFormat.value_text(SPEED, 6.0), "6.00 m/s", "units written in the file are shown as they are")
	assert_eq(FeelFormat.value_text(TRAILS, true), "On")
	assert_eq(FeelFormat.value_text(TRAILS, false), "Off")
	assert_eq(FeelFormat.value_text(LAUNCH, "hold_heavy"), "Hold Heavy", "an option has a plain name")
	assert_eq(FeelFormat.value_text(LAUNCH, "string_end"), "End of a Light string")


func test_an_option_with_no_written_name_is_still_readable() -> void:
	assert_eq(FeelFormat.option_label("brand_new_knob", "some_option"), "Some Option")


func test_hints_come_from_the_knob_first_then_the_text_file() -> void:
	var own: Dictionary = DASH.duplicate()
	own["hint"] = "From the knob file."
	assert_eq(FeelFormat.hint_of(own), "From the knob file.")
	assert_ne(FeelFormat.hint_of(DASH), "", "the fallback table covers the starting knobs")
	assert_eq(FeelFormat.hint_of({"id": "no_such_knob_anywhere"}), "")


func test_every_knob_in_the_data_file_has_a_hint_and_a_label_and_a_group_title() -> void:
	var knobs: Array = DataDB.get_value("combat/feel", "knobs", [])
	assert_gt(knobs.size(), 0, "the data file has knobs")
	for knob: Variant in knobs:
		var entry: Dictionary = knob as Dictionary
		assert_ne(FeelFormat.hint_of(entry), "", "%s has a one-line hint" % entry["id"])
		assert_false(FeelFormat.hint_of(entry).contains("\n"), "%s hint is one line" % entry["id"])
		assert_ne(FeelFormat.label_of(entry), "", "%s has a label" % entry["id"])
		assert_ne(FeelFormat.group_title(str(entry["group"])), "", "%s has a group title" % entry["id"])
		if FeelFormat.kind_of(entry) == "choice":
			for option: Variant in entry["options"]:
				assert_ne(FeelFormat.choice_hint_of(entry, str(option)), "", "%s / %s says what it means" % [entry["id"], option])


func test_groups_keep_file_order() -> void:
	var list: Array = [DASH, BUFFER, SPEED, TRAILS]
	assert_eq(FeelFormat.groups_of(list), ["movement", "combat", "fx"] as Array[String])
	assert_eq(FeelFormat.knobs_in_group(list, "movement").size(), 2)


func test_long_paths_are_shortened_from_the_left() -> void:
	assert_eq(FeelFormat.shorten_path("short.json", 50), "short.json")
	var long_path: String = "/home/someone/.local/share/godot/app_userdata/LightsOnSandbox/feel/feel_current.json"
	var short: String = FeelFormat.shorten_path(long_path, 40)
	assert_eq(short.length(), 40)
	assert_true(short.begins_with("..."))
	assert_true(short.ends_with("feel_current.json"))
