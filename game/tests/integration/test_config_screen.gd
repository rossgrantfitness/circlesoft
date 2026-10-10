extends TestCase
## The shared Config screen: its rows and values, every row persisting through Config into
## user://config.json, volumes, the Controls (remap) page with real key and button events, and the
## tap-along test run against a fake clock.

const CONFIG_SCRIPT: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_config_screen_scratch.json"
const SIZE: Vector2 = Vector2(352, 200)

var _config: Node = null
var _fake_audio: FakeAudio = null
var _clock: Array[float] = [10000.0]


func before_each() -> void:
	_clock[0] = 10000.0


func after_each() -> void:
	InputRemap.reset()
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func _new_config() -> Node:
	var config: Node = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	config.set("save_path", SCRATCH)
	config.set("apply_bindings_live", false)
	return config


func _make(open_it: bool = true) -> ConfigScreen:
	_config = _new_config()
	_fake_audio = FakeAudio.new()
	var screen: ConfigScreen = ConfigScreen.new()
	screen.config = _config
	screen.manual_ticks = true
	screen.size = SIZE
	screen.clock_ms = func() -> float: return _clock[0]
	add_to_root(screen)
	var audio: UiAudio = UiAudio.new()
	audio.target = _fake_audio
	screen.audio = audio
	if open_it:
		screen.open(true)
	return screen


func _reload() -> Node:
	var other: Node = _new_config()
	other.call("load_file")
	return other


func _go_to_row(screen: ConfigScreen, row_id: String) -> void:
	var index: int = screen.get_row_ids().find(row_id)
	assert_ge(index, 0, "row %s exists" % row_id)
	screen.get_list().set_index(index, false)


func _press(screen: ConfigScreen, command: MenuInput.Cmd) -> bool:
	return screen.handle_command(command)


func _action(name: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


# ---- rows ----

func test_the_rows_are_the_ones_the_design_lists_in_order() -> void:
	var screen: ConfigScreen = _make()
	assert_eq(screen.get_row_ids(), [
		"auto_timing", "wide_windows", "timing_offset", "tap_along", "battle_camera",
		"text_speed", "auto_advance", "skip_seen",
		"master_volume", "music_volume", "sfx_volume", "voice_volume",
		"controls", "vibration"] as Array[String])
	assert_eq(screen.get_list().get_count(), 14)


func test_every_row_has_a_label_and_a_hint_in_data() -> void:
	var text: Dictionary = DataDB.get_dict("text/config")["rows"]
	var screen: ConfigScreen = _make()
	for id: String in screen.get_row_ids():
		assert_true(text.has(id), id)
		assert_gt(str(text[id]["label"]).length(), 0, id)
		assert_gt(str(text[id]["hint"]).length(), 0, id)
	var labels: Array[String] = []
	for item: Dictionary in screen.get_row_items():
		labels.append(str(item["label"]))
	assert_eq(labels[0], "Auto-Timing")
	assert_eq(labels[3], "Tap-Along Test")
	assert_eq(labels[4], "Battle Camera")


func test_values_show_the_current_settings() -> void:
	var screen: ConfigScreen = _make(false)
	_config.call("set_auto_timing", true)
	_config.call("set_timing_offset_ms", 30)
	_config.call("set_text_speed", "slow")
	_config.call("set_volume", "music", 0.5)
	screen.open(true)
	assert_eq(screen.get_row_value("auto_timing"), "On")
	assert_eq(screen.get_row_value("wide_windows"), "Off")
	assert_eq(screen.get_row_value("timing_offset"), "+30 ms")
	assert_eq(screen.get_row_value("text_speed"), "Slow")
	assert_eq(screen.get_row_value("music_volume"), "50%")
	assert_eq(screen.get_row_value("vibration"), "On")


func test_it_lays_out_inside_the_size_it_is_given() -> void:
	var small: ConfigScreen = _make()
	small.size = Vector2(268, 144)
	small.show_frame = false
	assert_ge(small.get_list().visible_rows, 2)
	assert_le(small.get_list().position.y + small.get_list().size.y, 144.0, "rows stay inside a field-menu sized panel")
	var big: ConfigScreen = _make()
	assert_gt(big.get_list().visible_rows, small.get_list().visible_rows)
	assert_le(big.get_list().position.y + big.get_list().size.y, SIZE.y)


# ---- every row persists ----

func test_toggles_flip_with_confirm_and_set_with_the_arrows_and_are_saved() -> void:
	var screen: ConfigScreen = _make()
	for pair: Array in [["auto_timing", "auto_timing"], ["wide_windows", "wide_windows"], ["auto_advance", "auto_advance"], ["skip_seen", "skip_seen_cutscenes"], ["vibration", "vibration"]]:
		_go_to_row(screen, pair[0])
		var before: bool = bool(_config.get(pair[1]))
		_press(screen, MenuInput.Cmd.CONFIRM)
		assert_eq(bool(_config.get(pair[1])), not before, "%s flips on confirm" % pair[0])
		_press(screen, MenuInput.Cmd.RIGHT)
		assert_true(bool(_config.get(pair[1])), "%s turns on with right" % pair[0])
		_press(screen, MenuInput.Cmd.LEFT)
		assert_false(bool(_config.get(pair[1])), "%s turns off with left" % pair[0])
		_press(screen, MenuInput.Cmd.RIGHT)
	var other: Node = _reload()
	assert_true(other.get("auto_timing"))
	assert_true(other.get("wide_windows"))
	assert_true(other.get("auto_advance"))
	assert_true(other.get("skip_seen_cutscenes"))
	assert_true(other.get("vibration"))


func test_text_speed_steps_stops_at_the_ends_and_wraps_on_confirm() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "text_speed")
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("text_speed"), "fast")
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("text_speed"), "fast", "arrows stop at the end")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("text_speed"), "slow", "confirm wraps round")
	assert_eq(_reload().get("text_speed"), "slow", "saved")


func test_the_timing_offset_steps_in_ten_and_is_saved() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "timing_offset")
	_press(screen, MenuInput.Cmd.RIGHT)
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), 20)
	assert_eq(screen.get_row_value("timing_offset"), "+20 ms")
	for i: int in 5:
		_press(screen, MenuInput.Cmd.LEFT)
	assert_eq(_config.get("timing_offset_ms"), -30)
	assert_eq(screen.get_row_value("timing_offset"), "-30 ms")
	assert_eq(_reload().get("timing_offset_ms"), -30)


func test_the_timing_offset_stops_at_the_range_end_and_wraps_on_confirm() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "timing_offset")
	_config.call("set_timing_offset_ms", 200)
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), 200)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("timing_offset_ms"), -200)


func test_each_volume_moves_in_tenths_and_is_saved() -> void:
	var screen: ConfigScreen = _make()
	for pair: Array in [["master_volume", "master_volume"], ["music_volume", "music_volume"], ["sfx_volume", "sfx_volume"], ["voice_volume", "voice_volume"]]:
		_go_to_row(screen, pair[0])
		var before: float = float(_config.get(pair[1]))
		_press(screen, MenuInput.Cmd.LEFT)
		_press(screen, MenuInput.Cmd.LEFT)
		assert_almost_eq(float(_config.get(pair[1])), snappedf(before - 0.2, 0.1), 0.001, "%s drops two notches" % pair[0])
	var other: Node = _reload()
	assert_almost_eq(float(other.get("master_volume")), 0.8, 0.001)
	assert_almost_eq(float(other.get("music_volume")), 0.6, 0.001)
	assert_almost_eq(float(other.get("sfx_volume")), 0.8, 0.001)
	assert_almost_eq(float(other.get("voice_volume")), 0.6, 0.001)


func test_a_volume_stops_at_zero_and_full_with_arrows_and_wraps_on_confirm() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "sfx_volume")
	_config.call("set_volume", "sfx", 1.0)
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_almost_eq(float(_config.get("sfx_volume")), 1.0, 0.001)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_almost_eq(float(_config.get("sfx_volume")), 0.0, 0.001, "wraps to silent")
	_press(screen, MenuInput.Cmd.LEFT)
	assert_almost_eq(float(_config.get("sfx_volume")), 0.0, 0.001)


func test_changing_a_setting_emits_the_key_and_plays_a_tick() -> void:
	var screen: ConfigScreen = _make()
	var keys: Array[String] = []
	screen.setting_changed.connect(func(key: String) -> void: keys.append(key))
	_go_to_row(screen, "wide_windows")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(keys, ["wide_windows"])
	assert_has(_fake_audio.sfx_ids, "menu_tick")


func test_the_voice_row_plays_a_voice_blip_so_you_can_hear_it() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "voice_volume")
	_press(screen, MenuInput.Cmd.LEFT)
	assert_eq(_fake_audio.voices.size(), 1)
	assert_eq(_fake_audio.voice_speakers[0], str(DataDB.get_dict("text/config")["preview"]["speaker"]))


func test_the_text_speed_row_types_a_preview_at_the_chosen_speed() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "text_speed")
	screen.tick(0.0)
	screen.tick(0.5)
	var normal_count: int = screen.get_preview_text().length()
	assert_gt(normal_count, 0)
	_press(screen, MenuInput.Cmd.LEFT)
	screen.tick(0.5)
	var slow_count: int = screen.get_preview_text().length()
	assert_lt(slow_count, normal_count, "slow types fewer letters in the same time")
	_go_to_row(screen, "auto_timing")
	assert_eq(screen.get_preview_text(), "", "only on the Text Speed row")


func test_leaving_saves_and_emits_closed() -> void:
	var screen: ConfigScreen = _make()
	var closed: Array[bool] = []
	screen.closed.connect(func() -> void: closed.append(true))
	_config.set("auto_advance", true)  # changed behind the screen's back
	_press(screen, MenuInput.Cmd.CANCEL)
	assert_eq(closed.size(), 1)
	assert_false(screen.is_open())
	assert_false(screen.visible)
	assert_true(_reload().get("auto_advance"), "close wrote the file")


func test_opening_takes_four_steps_and_input_waits_until_it_is_open() -> void:
	var screen: ConfigScreen = _make(false)
	var opened: Array[bool] = []
	screen.opened.connect(func() -> void: opened.append(true))
	screen.open()
	assert_eq(screen.get_state(), ConfigScreen.State.OPENING)
	assert_false(_press(screen, MenuInput.Cmd.CONFIRM), "ignores input while opening")
	for i: int in 3:
		screen.tick(0.0834)
	assert_eq(opened.size(), 0)
	screen.tick(0.0834)
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	assert_eq(opened.size(), 1)


func test_events_go_through_the_same_path_as_commands() -> void:
	var screen: ConfigScreen = _make()
	assert_true(screen.handle_event(_action(&"move_down")))
	assert_eq(screen.get_list().get_cursor_index(), 1)
	assert_true(screen.handle_event(_action(&"move_right")))
	assert_true(_config.get("wide_windows"))
	assert_false(screen.handle_event(_action(&"jump")), "other buttons are not used")


func test_mouse_hover_click_and_right_click_work() -> void:
	var screen: ConfigScreen = _make()
	var list: MenuList = screen.get_list()
	var closed: Array[bool] = []
	screen.closed.connect(func() -> void: closed.append(true))
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = list.get_global_transform() * list.get_row_rect(1).get_center()
	assert_true(screen.handle_event(move))
	assert_eq(list.get_cursor_index(), 1)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = move.position
	screen.handle_event(click)
	assert_true(_config.get("wide_windows"), "a click picks the row")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	screen.handle_event(right)
	assert_eq(closed.size(), 1, "right-click backs out")


func test_is_busy_only_inside_sub_pages() -> void:
	var screen: ConfigScreen = _make()
	assert_false(screen.is_busy())
	_go_to_row(screen, "controls")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_true(screen.is_busy())
	_press(screen, MenuInput.Cmd.CANCEL)
	assert_false(screen.is_busy())
	assert_true(screen.is_open(), "cancel inside a sub-page does not close the screen")


# ---- controls (remap) ----

func _open_controls(screen: ConfigScreen) -> void:
	_go_to_row(screen, "controls")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)


func _go_to_control(screen: ConfigScreen, group: String) -> void:
	screen.get_controls_list().set_index(screen.get_control_ids().find(group), false)


func test_the_controls_page_lists_every_remappable_button_and_a_reset_row() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	var ids: Array[String] = []
	for item: Dictionary in screen.get_controls_list().get_items():
		ids.append(str(item["id"]))
	assert_eq(ids, ["confirm", "cancel", "interact", "jump", "run", "menu", "clutch", "light", "heavy", "dash", "parry", "lock_on", "camera_toggle", "feel_panel", "reset"] as Array[String])


func test_remapping_a_key_with_a_real_key_event_saves_and_reloads() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	_go_to_control(screen, "jump")
	assert_eq(screen.get_control_column(), 0, "starts on the keyboard column")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.CAPTURE)
	assert_eq(screen.get_capture_group(), "jump")
	assert_eq(screen.get_capture_kind(), "key")
	assert_true(screen.handle_event(_key(KEY_Q)))
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)
	assert_eq(_config.call("get_effective_bindings")["jump"]["key"], KEY_Q)
	var other: Node = _reload()
	assert_eq(other.call("get_effective_bindings")["jump"]["key"], KEY_Q, "it was saved to the file")
	assert_eq(other.call("get_effective_bindings")["confirm"]["key"], KEY_Z, "others untouched")


func test_remapping_a_controller_button_with_a_real_button_event() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	_go_to_control(screen, "run")
	_press(screen, MenuInput.Cmd.RIGHT)
	assert_eq(screen.get_control_column(), 1)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_capture_kind(), "pad")
	assert_true(screen.handle_event(_key(KEY_Q)), "a key press is ignored while waiting for a button")
	assert_eq(screen.get_state(), ConfigScreen.State.CAPTURE)
	screen.handle_event(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)
	assert_eq(_reload().call("get_effective_bindings")["run"]["pad"], JOY_BUTTON_RIGHT_SHOULDER)


func test_taking_a_partners_button_swaps_and_says_so() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	_go_to_control(screen, "jump")
	_press(screen, MenuInput.Cmd.CONFIRM)
	screen.handle_event(_key(KEY_SHIFT))
	var bindings: Dictionary = _config.call("get_effective_bindings")
	assert_eq(bindings["jump"]["key"], KEY_SHIFT)
	assert_eq(bindings["run"]["key"], KEY_SPACE, "Run took Jump's old key")
	assert_true(screen.get_message().contains("Run"), screen.get_message())


func test_reserved_keys_are_refused_and_the_capture_stays_open() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	_go_to_control(screen, "jump")
	_press(screen, MenuInput.Cmd.CONFIRM)
	screen.handle_event(_key(KEY_W))
	assert_eq(screen.get_state(), ConfigScreen.State.CAPTURE, "W moves Red, so try again")
	assert_eq(screen.get_message(), str(DataDB.get_dict("text/config")["controls"]["reserved"]))
	screen.handle_event(_key(KEY_F5))
	assert_eq(screen.get_state(), ConfigScreen.State.CAPTURE)
	assert_eq(_config.get("bindings"), {})
	screen.handle_event(_key(KEY_Q))
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)


func test_escape_and_right_click_cancel_a_capture_and_so_does_waiting() -> void:
	var screen: ConfigScreen = _make()
	_open_controls(screen)
	_go_to_control(screen, "jump")
	_press(screen, MenuInput.Cmd.CONFIRM)
	screen.handle_event(_key(KEY_ESCAPE))
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)
	assert_eq(_config.get("bindings"), {})
	_press(screen, MenuInput.Cmd.CONFIRM)
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	screen.handle_event(right)
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS)
	_press(screen, MenuInput.Cmd.CONFIRM)
	screen.tick(float(DataDB.get_dict("ui/config_screen")["controls"]["capture_timeout_s"]) + 0.5)
	assert_eq(screen.get_state(), ConfigScreen.State.CONTROLS, "gave up after the timeout")


func test_reset_to_defaults_puts_every_button_back() -> void:
	var screen: ConfigScreen = _make()
	_config.call("set_binding", "jump", "key", KEY_Q)
	_config.call("set_binding", "run", "pad", JOY_BUTTON_LEFT_SHOULDER)
	_open_controls(screen)
	screen.get_controls_list().set_index(screen.get_controls_list().get_count() - 1, false)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("bindings"), {})
	assert_eq(_reload().get("bindings"), {})


func test_remapping_through_the_screen_changes_the_real_input_map() -> void:
	var screen: ConfigScreen = _make()
	_config.set("apply_bindings_live", true)
	_open_controls(screen)
	_go_to_control(screen, "jump")
	_press(screen, MenuInput.Cmd.CONFIRM)
	screen.handle_event(_key(KEY_Q))
	var found: bool = false
	for event: InputEvent in InputMap.action_get_events("jump"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q:
			found = true
	assert_true(found, "Jump now answers to Q")
	InputRemap.reset()
	found = false
	for event: InputEvent in InputMap.action_get_events("jump"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q:
			found = true
	assert_false(found)


# ---- tap-along ----

## Plays a whole tap-along run on the fake clock. The pretend player taps `lag_ms` after (negative:
## before) every scheduled beat, except the beats listed in `missed`, with optional wobble. Taps are
## stamped at their exact times. Returns once the result page is up.
func _play_tap_run(screen: ConfigScreen, lag_ms: float, missed: Array[int] = [], wobble: Array[float] = []) -> void:
	var params: Dictionary = DataDB.get_dict("ui/config_screen")["tap_along"]
	var start: float = _clock[0]
	var taps: Array[float] = []
	for i: int in int(params["beats"]):
		if missed.has(i):
			continue
		var extra: float = wobble[i % wobble.size()] if not wobble.is_empty() else 0.0
		taps.append(start + (float(params["lead_in_s"]) + float(i) * float(params["interval_s"])) * 1000.0 + lag_ms + extra)
	var next_tap: int = 0
	for step: int in 4000:
		_clock[0] += 5.0
		screen.tick(0.005)
		while next_tap < taps.size() and _clock[0] >= taps[next_tap]:
			var now: float = _clock[0]
			_clock[0] = taps[next_tap]
			screen.register_tap()
			_clock[0] = now
			next_tap += 1
		if screen.get_state() == ConfigScreen.State.TAP_RESULT:
			return


func test_the_tap_test_starts_from_its_row_and_waits_for_confirm() -> void:
	var screen: ConfigScreen = _make()
	_go_to_row(screen, "tap_along")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.TAP_INTRO)
	_clock[0] += 5000.0
	screen.tick(1.0)
	assert_eq(screen.get_tap_beats().size(), 0, "nothing flashes until the player says go")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.TAP_RUN)


func test_cancel_leaves_the_tap_test_without_changing_the_offset() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CANCEL)
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_true(screen.handle_event(_action(&"cancel")))
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	assert_eq(_config.get("timing_offset_ms"), 0)


func test_the_metronome_flashes_and_dings_on_each_beat_on_schedule() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	var params: Dictionary = DataDB.get_dict("ui/config_screen")["tap_along"]
	var start: float = _clock[0]
	_clock[0] = start + float(params["lead_in_s"]) * 1000.0 - 20.0
	screen.tick(0.01)
	assert_eq(screen.get_tap_beats().size(), 0, "still in the lead-in")
	_clock[0] += 30.0
	screen.tick(0.01)
	assert_eq(screen.get_tap_beats().size(), 1, "the first beat")
	assert_eq(_fake_audio.sfx_ids.count(str(params["sfx"])), 1, "with its ding on the same moment")
	_clock[0] += float(params["interval_s"]) * 1000.0
	screen.tick(0.01)
	assert_eq(screen.get_tap_beats().size(), 2)
	assert_eq(_fake_audio.sfx_ids.count(str(params["sfx"])), 2)
	assert_almost_eq(screen.get_tap_beats()[1] - screen.get_tap_beats()[0], float(params["interval_s"]) * 1000.0, 1.0)


func test_a_full_run_suggests_the_players_lag_and_use_applies_it() -> void:
	var screen: ConfigScreen = _make()
	var finished: Array[Dictionary] = []
	screen.tap_test_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	_play_tap_run(screen, 60.0)
	assert_eq(screen.get_state(), ConfigScreen.State.TAP_RESULT)
	assert_eq(screen.get_tap_beats().size(), int(DataDB.get_dict("ui/config_screen")["tap_along"]["beats"]))
	var result: Dictionary = screen.get_tap_result()
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], 60)
	assert_eq(finished.size(), 1)
	var ids: Array[String] = []
	for item: Dictionary in screen.get_result_list().get_items():
		ids.append(str(item["id"]))
	assert_eq(ids, ["use", "retry", "back"] as Array[String])
	assert_eq(_config.get("timing_offset_ms"), 0, "nothing changes until the player accepts")
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("timing_offset_ms"), 60)
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	assert_eq(screen.get_row_value("timing_offset"), "+60 ms")
	assert_eq(_reload().get("timing_offset_ms"), 60, "saved")


func test_early_tappers_get_a_negative_suggestion() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	_play_tap_run(screen, -40.0)
	assert_eq(screen.get_tap_result()["offset_ms"], -40)


func test_a_little_wobble_and_a_missed_beat_still_give_a_good_answer() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	var wobble: Array[float] = [6.0, -8.0, 4.0, -5.0, 9.0, -3.0, 2.0]
	_play_tap_run(screen, 80.0, [3] as Array[int], wobble)
	var result: Dictionary = screen.get_tap_result()
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], 80)


func test_tapping_nothing_gives_no_suggestion_and_only_retry_and_back() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	var all_beats: Array[int] = []
	for i: int in 8:
		all_beats.append(i)
	_play_tap_run(screen, 0.0, all_beats)
	assert_eq(screen.get_state(), ConfigScreen.State.TAP_RESULT)
	assert_false(screen.get_tap_result()["ok"])
	var ids: Array[String] = []
	for item: Dictionary in screen.get_result_list().get_items():
		ids.append(str(item["id"]))
	assert_eq(ids, ["retry", "back"] as Array[String])


func test_try_again_returns_to_the_intro_and_back_to_the_list() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	_play_tap_run(screen, 30.0)
	screen.get_result_list().set_index(1, false)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.TAP_INTRO)
	_press(screen, MenuInput.Cmd.CONFIRM)
	_play_tap_run(screen, 30.0)
	screen.get_result_list().set_index(2, false)
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	assert_eq(_config.get("timing_offset_ms"), 0)


func test_the_clutch_button_and_confirm_both_count_as_taps() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	assert_true(screen.handle_event(_action(&"clutch")))
	assert_true(screen.handle_event(_action(&"confirm")))
	assert_eq(screen.get_tap_taps().size(), 2)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.handle_event(click)
	assert_eq(screen.get_tap_taps().size(), 3, "a mouse click taps too")


func test_the_suggestion_respects_the_offset_range_in_data() -> void:
	var screen: ConfigScreen = _make()
	screen.start_tap_along()
	_press(screen, MenuInput.Cmd.CONFIRM)
	_play_tap_run(screen, 330.0)
	var result: Dictionary = screen.get_tap_result()
	if bool(result["ok"]):
		assert_le(int(result["offset_ms"]), int(_config.call("get_timing_offset_max_ms")))
	else:
		assert_eq(result["reason"], TapAlong.REASON_TOO_FEW, "taps that late fall outside the matching window")


# ---- data ----

func test_every_string_the_screen_needs_exists() -> void:
	var text: Dictionary = DataDB.get_dict("text/config")
	for key: String in ["title", "on", "off", "ms_format", "percent_format", "speed_names", "rows", "controls", "tap_along", "preview"]:
		assert_true(text.has(key), key)
	for id: String in InputRemap.group_ids():
		assert_true(text["controls"]["rows"].has(id), "controls label for %s" % id)
	for word: String in ["intro_1", "intro_2", "intro_go", "get_ready", "tap_now", "late", "early", "on_time", "suggest", "unsteady", "too_few", "messy", "use", "retry", "back", "applied"]:
		assert_true(text["tap_along"].has(word), word)


func test_the_tap_sound_is_a_real_sound() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	assert_not_null(audio)
	assert_true(audio.call("has_sfx", StringName(str(DataDB.get_dict("ui/config_screen")["tap_along"]["sfx"]))))
