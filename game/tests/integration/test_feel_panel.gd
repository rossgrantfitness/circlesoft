extends TestCase
## The feel-knobs panel (CS-16): it lists every knob in data/combat/feel.json, grouped, steps
## sliders by their step and stops at the ends, flips toggles, cycles choices, moves around with
## pad / keys / mouse, saves a readable file and shows its path, resets to the studio numbers and
## reverts to the last save, and pauses the game while it is open.

const PANEL_SCENE: String = "res://scenes/ui/sandbox/feel_panel.tscn"
const SCRATCH_DIR: String = "user://test_feel_panel"

var _audio: FakeAudio = null
var _knobs: FeelKnobs = null
var _panel: FeelPanel = null
var _opened_folders: Array[String] = []


func _setup(pause: bool = false) -> void:
	_audio = FakeAudio.new()
	_knobs = FeelKnobs.load_defaults()
	_panel = (load(PANEL_SCENE) as PackedScene).instantiate() as FeelPanel
	_panel.manual_ticks = true
	_panel.save_dir = SCRATCH_DIR
	_panel.pause_game = pause
	_panel.animations_enabled = false
	_panel.clipboard_enabled = false
	_panel.audio.target = _audio
	_panel.opener = func(path: String) -> int:
		_opened_folders.append(path)
		return OK
	add_root(_panel)
	_panel.bind(_knobs)
	_panel.open_panel()


func add_root(node: Node) -> void:
	add_to_root(node)


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	var dir: DirAccess = DirAccess.open(SCRATCH_DIR)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _data_knobs() -> Array:
	return DataDB.get_value("combat/feel", "knobs", [])


func _press(commands: Array) -> void:
	for command: MenuInput.Cmd in commands:
		_panel.handle_command(command)


func _knob(id: String) -> Dictionary:
	for knob: Dictionary in _panel.get_knob_list():
		if str(knob["id"]) == id:
			return knob
	return {}


func _stage_point(local: Vector2) -> Vector2:
	return local


func _row_point(visible_index: int, x: float) -> Vector2:
	var layout: Dictionary = SandboxUiData.ui("feel_panel", {})
	return _stage_point(Vector2(x, float(layout["row_y"]) + float(visible_index) * float(layout["row_step"]) + 7.0))


func _click(point: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	_panel.handle_mouse(event)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	_panel.handle_mouse(up)


# ---- built from the data ----

func test_it_lists_every_knob_in_the_data_file_grouped() -> void:
	_setup()
	var data: Array = _data_knobs()
	assert_gt(data.size(), 0)
	var listed: Array[String] = []
	for tab: int in _panel.get_knob_groups().size():
		_panel._tab = tab
		for knob: Dictionary in _panel.get_rows():
			listed.append(str(knob["id"]))
			assert_eq(str(knob["group"]), _panel.get_knob_groups()[tab], "%s sits on its own group's tab" % knob["id"])
	var expected: Array[String] = []
	for knob: Variant in data:
		expected.append(str((knob as Dictionary)["id"]))
	listed.sort()
	expected.sort()
	assert_eq(listed, expected, "every knob is on a tab, none twice")
	var groups_in_file: Array[String] = FeelFormat.groups_of(data)
	assert_eq(_panel.get_knob_groups(), groups_in_file, "tabs follow the file's group order")


func test_the_panel_names_no_knob_in_its_code() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/sandbox/feel_panel.gd")
	for knob: Variant in _data_knobs():
		assert_false(source.contains('"%s"' % (knob as Dictionary)["id"]), "feel_panel.gd does not hard-code %s" % (knob as Dictionary)["id"])


func test_every_row_shows_its_label_unit_and_a_hint() -> void:
	_setup()
	for tab: int in _panel.get_knob_groups().size():
		_panel._tab = tab
		_panel._zone = FeelPanel.Zone.ROWS
		for index: int in _panel.get_rows().size():
			_panel._row = index
			var knob: Dictionary = _panel.get_cursor_knob()
			var lines: Array[String] = _panel.get_info_lines()
			assert_ne(lines[0], "", "%s has a hint line" % knob["id"])
			assert_true(lines[1].contains("Studio default"), "%s says its studio default" % knob["id"])
			if FeelFormat.is_slider(knob):
				assert_true(lines[1].contains("Range"), "%s says its range" % knob["id"])
				if not str(knob.get("unit", "")).is_empty():
					assert_true(FeelFormat.value_text(knob, float(knob["value"])).contains(FeelFormat.unit_text(knob)), "%s shows its unit" % knob["id"])


func test_the_panel_draws_every_tab_without_errors() -> void:
	_setup()
	for tab: int in _panel.get_knob_groups().size():
		_panel._tab = tab
		_panel._row = 0
		_panel._overlay.queue_redraw()
		await tree.process_frame
	assert_true(_panel.is_open())


# ---- opening, closing, pausing ----

func test_open_and_close() -> void:
	_setup()
	assert_true(_panel.is_open())
	assert_true(_panel.visible)
	_press([MenuInput.Cmd.CANCEL])
	assert_false(_panel.is_open())
	assert_false(_panel.visible)
	_panel.toggle_panel()
	assert_true(_panel.is_open())
	_panel.toggle_panel()
	assert_false(_panel.is_open())


func test_opening_pauses_the_game_and_closing_gives_it_back() -> void:
	var mode_before: Input.MouseMode = Input.mouse_mode
	_setup(true)
	assert_true(tree.paused, "the arena is paused while the panel is open")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "the mouse is free")
	assert_eq(_panel.process_mode, Node.PROCESS_MODE_ALWAYS, "the panel keeps running while paused")
	_panel.close_panel()
	assert_false(tree.paused, "closing un-pauses")
	assert_eq(Input.mouse_mode, mode_before)


func test_freeing_an_open_panel_does_not_leave_the_game_paused() -> void:
	_setup(true)
	assert_true(tree.paused)
	_panel.get_parent().remove_child(_panel)
	_panel.free()
	assert_false(tree.paused)


func test_the_panel_button_opens_and_closes_it() -> void:
	_setup()
	_panel.close_panel()
	_panel.listen_input = true
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F12
	event.keycode = KEY_F12
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame
	assert_true(_panel.is_open(), "F12 opens it")
	var again: InputEventKey = event.duplicate() as InputEventKey
	Input.parse_input_event(again)
	await tree.process_frame
	await tree.process_frame
	assert_false(_panel.is_open(), "F12 closes it")


# ---- changing values ----

func test_right_and_left_step_a_slider_by_its_step_and_stop_at_the_ends() -> void:
	_setup()
	assert_true(_panel.focus_knob("dash_distance_m"))
	var step: float = float(_knob("dash_distance_m")["step"])
	var start: float = _knobs.get_f("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT])
	assert_almost_eq(_knobs.get_f("dash_distance_m"), start + step, 0.0001)
	_press([MenuInput.Cmd.LEFT, MenuInput.Cmd.LEFT])
	assert_almost_eq(_knobs.get_f("dash_distance_m"), start - step, 0.0001)
	for i: int in 200:
		_press([MenuInput.Cmd.LEFT])
	assert_almost_eq(_knobs.get_f("dash_distance_m"), float(_knob("dash_distance_m")["min"]), 0.0001, "stops at the bottom")
	for i: int in 400:
		_press([MenuInput.Cmd.RIGHT])
	assert_almost_eq(_knobs.get_f("dash_distance_m"), float(_knob("dash_distance_m")["max"]), 0.0001, "stops at the top")


func test_an_int_knob_stays_a_whole_number() -> void:
	_setup()
	_panel.focus_knob("input_buffer_ms")
	_press([MenuInput.Cmd.RIGHT])
	var value: Variant = _knobs.knob("input_buffer_ms")["value"]
	assert_eq(typeof(value), TYPE_INT, "ints are written as ints")
	assert_eq(value, 160)


func test_confirm_flips_a_toggle_and_the_sides_set_it() -> void:
	_setup()
	_panel.focus_knob("trails_on")
	assert_true(_knobs.get_b("trails_on"))
	_press([MenuInput.Cmd.CONFIRM])
	assert_false(_knobs.get_b("trails_on"))
	_press([MenuInput.Cmd.RIGHT])
	assert_true(_knobs.get_b("trails_on"), "right means On")
	_press([MenuInput.Cmd.LEFT])
	assert_false(_knobs.get_b("trails_on"), "left means Off")


func test_a_choice_cycles_with_the_sides_and_wraps() -> void:
	_setup()
	_panel.focus_knob("launcher_input")
	assert_eq(_knobs.get_s("launcher_input"), "hold_heavy")
	_press([MenuInput.Cmd.RIGHT])
	assert_eq(_knobs.get_s("launcher_input"), "back_heavy")
	_press([MenuInput.Cmd.RIGHT, MenuInput.Cmd.RIGHT])
	assert_eq(_knobs.get_s("launcher_input"), "hold_heavy", "wraps around")
	_press([MenuInput.Cmd.LEFT])
	assert_eq(_knobs.get_s("launcher_input"), "string_end")
	_press([MenuInput.Cmd.CONFIRM])
	assert_eq(_knobs.get_s("launcher_input"), "hold_heavy", "confirm picks the next one")


func test_a_change_reaches_the_knobs_at_once_and_is_announced() -> void:
	_setup()
	var seen: Array[String] = []
	_panel.knob_changed.connect(func(id: String, _value: Variant) -> void: seen.append(id))
	_panel.focus_knob("shake_scale")
	_press([MenuInput.Cmd.RIGHT])
	assert_eq(seen, ["shake_scale"] as Array[String])
	assert_has(_audio.sfx_ids, "menu_tick")


func test_holding_a_direction_repeats_and_speeds_up() -> void:
	_setup()
	_panel.focus_knob("cam_sensitivity")
	_panel.hold_probe = func(_command: MenuInput.Cmd) -> bool: return true
	var layout: Dictionary = SandboxUiData.ui("feel_panel", {})
	var start: float = _knobs.get_f("cam_sensitivity")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	assert_true(_panel.handle_event(key), "the first press steps once")
	var one_step: float = _knobs.get_f("cam_sensitivity") - start
	assert_gt(one_step, 0.0)
	_panel.tick(float(layout["repeat_delay_s"]) - 0.05)
	assert_almost_eq(_knobs.get_f("cam_sensitivity"), start + one_step, 0.0001, "nothing repeats before the delay")
	_panel.tick(0.2)
	assert_gt(_knobs.get_f("cam_sensitivity"), start + one_step, "held: it repeats")
	var before_long: float = _knobs.get_f("cam_sensitivity")
	_panel.tick(0.3)
	assert_gt(_knobs.get_f("cam_sensitivity") - before_long, 0.0)
	_panel.hold_probe = func(_command: MenuInput.Cmd) -> bool: return false
	var settled: float = _knobs.get_f("cam_sensitivity")
	_panel.tick(1.0)
	assert_almost_eq(_knobs.get_f("cam_sensitivity"), settled, 0.0001, "let go: it stops")


# ---- moving around ----

func test_up_from_the_first_row_reaches_the_tabs_and_the_sides_change_tab() -> void:
	_setup()
	assert_eq(_panel.get_zone(), FeelPanel.Zone.ROWS)
	_press([MenuInput.Cmd.UP])
	assert_eq(_panel.get_zone(), FeelPanel.Zone.TABS)
	var first_tab: int = _panel.get_tab()
	_press([MenuInput.Cmd.RIGHT])
	assert_eq(_panel.get_tab(), first_tab + 1)
	_press([MenuInput.Cmd.LEFT, MenuInput.Cmd.LEFT])
	assert_eq(_panel.get_tab(), _panel.get_knob_groups().size() - 1, "tabs wrap")
	_press([MenuInput.Cmd.DOWN])
	assert_eq(_panel.get_zone(), FeelPanel.Zone.ROWS)
	assert_eq(_panel.get_row(), 0)


func test_down_past_the_last_row_reaches_the_buttons() -> void:
	_setup()
	var rows: int = _panel.get_rows().size()
	for i: int in rows:
		_press([MenuInput.Cmd.DOWN])
	assert_eq(_panel.get_zone(), FeelPanel.Zone.BUTTONS)
	_press([MenuInput.Cmd.RIGHT])
	assert_eq(_panel.get_button(), 1)
	_press([MenuInput.Cmd.UP])
	assert_eq(_panel.get_zone(), FeelPanel.Zone.ROWS)
	assert_eq(_panel.get_row(), rows - 1)


func test_shoulder_buttons_and_page_keys_switch_tab_from_anywhere() -> void:
	_setup()
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	pad.pressed = true
	assert_true(_panel.handle_event(pad))
	assert_eq(_panel.get_tab(), 1)
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	assert_true(_panel.handle_event(pad))
	assert_eq(_panel.get_tab(), 0)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_PAGEDOWN
	key.pressed = true
	assert_true(_panel.handle_event(key))
	assert_eq(_panel.get_tab(), 1)


func test_a_long_tab_scrolls_to_keep_the_cursor_visible() -> void:
	_setup()
	var visible_rows: int = int(SandboxUiData.ui("feel_panel.rows_visible", 7))
	var biggest: int = 0
	for tab: int in _panel.get_knob_groups().size():
		_panel._tab = tab
		biggest = maxi(biggest, _panel.get_rows().size())
	assert_gt(biggest, 0)
	for tab: int in _panel.get_knob_groups().size():
		_panel._tab = tab
		_panel._row = 0
		_panel._top = 0
		for i: int in _panel.get_rows().size():
			_panel._row = i
			_panel._scroll_to_row()
			assert_true(i >= _panel._top and i < _panel._top + visible_rows, "row %d on tab %d is on screen" % [i, tab])


# ---- the buttons ----

func test_save_writes_a_readable_file_and_shows_where() -> void:
	_setup()
	_panel.focus_knob("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT, MenuInput.Cmd.RIGHT])
	assert_true(_panel.is_dirty(), "unsaved changes are flagged")
	var saved_paths: Array[String] = []
	_panel.saved.connect(func(path: String) -> void: saved_paths.append(path))
	_panel.press_button("save")
	assert_eq(saved_paths.size(), 1)
	assert_true(FileAccess.file_exists(saved_paths[0]), "the file is there")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_paths[0]))
	assert_true(parsed is Dictionary, "the file is readable JSON")
	assert_almost_eq(float((parsed as Dictionary)["values"]["dash_distance_m"]), 4.5, 0.0001)
	assert_true(_panel.get_message().contains("feel_current.json"), "the message shows the file")
	assert_eq(_panel.get_saved_path(), saved_paths[0])
	assert_false(_panel.is_dirty(), "after a save nothing is unsaved")


func test_save_failing_says_so_and_changes_nothing() -> void:
	_setup()
	_panel.save_dir = "/proc/no_such_folder/feel"
	_panel.focus_knob("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT])
	_panel.press_button("save")
	assert_true(_panel.get_message().begins_with("Could not save"))
	assert_true(_panel.is_dirty())


func test_reset_puts_every_knob_back_to_the_studio_number() -> void:
	_setup()
	_panel.focus_knob("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT, MenuInput.Cmd.RIGHT])
	_panel.focus_knob("trails_on")
	_press([MenuInput.Cmd.CONFIRM])
	_panel.focus_knob("launcher_input")
	_press([MenuInput.Cmd.RIGHT])
	_panel.press_button("reset")
	for knob: Variant in _data_knobs():
		var entry: Dictionary = knob as Dictionary
		match str(entry["type"]):
			"bool":
				assert_eq(_knobs.get_b(str(entry["id"])), entry["value"], "%s is back" % entry["id"])
			"choice":
				assert_eq(_knobs.get_s(str(entry["id"])), entry["value"], "%s is back" % entry["id"])
			_:
				assert_almost_eq(_knobs.get_f(str(entry["id"])), float(entry["value"]), 0.0001, "%s is back" % entry["id"])


func test_revert_goes_back_to_the_last_save_not_to_the_defaults() -> void:
	_setup()
	_panel.focus_knob("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT])
	_panel.press_button("save")
	var saved_value: float = _knobs.get_f("dash_distance_m")
	_press([MenuInput.Cmd.RIGHT, MenuInput.Cmd.RIGHT, MenuInput.Cmd.RIGHT])
	_panel.focus_knob("trails_on")
	_press([MenuInput.Cmd.CONFIRM])
	assert_ne(_knobs.get_f("dash_distance_m"), saved_value)
	_panel.press_button("revert")
	assert_almost_eq(_knobs.get_f("dash_distance_m"), saved_value, 0.0001)
	assert_true(_knobs.get_b("trails_on"), "the toggle is back too")
	assert_true(saved_value != float(_panel.get_default("dash_distance_m")), "the save was not the default")


func test_revert_with_nothing_to_undo_says_so() -> void:
	_setup()
	_panel.press_button("revert")
	assert_eq(_panel.get_message(), SandboxUiData.text("feel.messages.revert_nothing"))


func test_open_folder_asks_for_the_saved_files_folder() -> void:
	_setup()
	_panel.press_button("save")
	_panel.press_button("open_folder")
	assert_eq(_opened_folders.size(), 1)
	assert_eq(_opened_folders[0], _panel.get_saved_path().get_base_dir())


func test_open_folder_before_any_save_uses_the_feel_folder() -> void:
	_setup()
	_panel.press_button("open_folder")
	assert_true(_opened_folders[0].ends_with("feel"), "the user feel folder")


func _saved_files() -> int:
	var dir: DirAccess = DirAccess.open(SCRATCH_DIR)
	return dir.get_files().size() if dir != null else 0


func test_a_button_works_from_the_pad() -> void:
	_setup()
	for i: int in _panel.get_rows().size():
		_press([MenuInput.Cmd.DOWN])
	assert_eq(_panel.get_zone(), FeelPanel.Zone.BUTTONS)
	_press([MenuInput.Cmd.CONFIRM])
	assert_gt(_saved_files(), 0, "the first button is Save")


# ---- mouse ----

func test_clicking_a_slider_sets_that_spot_and_dragging_follows() -> void:
	_setup()
	_panel.focus_knob("dash_distance_m")
	var layout: Dictionary = SandboxUiData.ui("feel_panel", {})
	var knob: Dictionary = _knob("dash_distance_m")
	var row_index: int = _panel.get_row()
	var at_half: float = float(layout["slider_x"]) + float(layout["slider_w"]) * 0.5
	_click(_row_point(row_index, at_half))
	var middle: float = (float(knob["min"]) + float(knob["max"])) / 2.0
	assert_almost_eq(_knobs.get_f("dash_distance_m"), middle, float(knob["step"]), "the click lands at the middle")
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = _row_point(row_index, float(layout["slider_x"]) + 5.0)
	_panel.handle_mouse(down)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.position = _row_point(row_index, float(layout["slider_x"]) + float(layout["slider_w"]) + 30.0)
	_panel.handle_mouse(drag)
	assert_almost_eq(_knobs.get_f("dash_distance_m"), float(knob["max"]), 0.0001, "dragging past the end holds the top")


func test_clicking_a_toggle_flips_it_and_a_tab_selects_it() -> void:
	_setup()
	var fx_tab: int = _panel.get_knob_groups().find("fx")
	var rects: Array[Rect2] = _panel._tab_rects()
	_click(_stage_point(rects[fx_tab].get_center()))
	assert_eq(_panel.get_tab(), fx_tab)
	var before: bool = _knobs.get_b("trails_on")
	var index: int = _panel.get_rows().find(_knob("trails_on"))
	_click(_row_point(index, 40.0))
	assert_eq(_knobs.get_b("trails_on"), not before)


func test_clicking_a_button_presses_it() -> void:
	_setup()
	var rects: Array[Rect2] = _panel._button_rects()
	_click(_stage_point(rects[0].get_center()))
	assert_gt(_saved_files(), 0)


func test_the_wheel_changes_the_value_under_the_pointer() -> void:
	_setup()
	_panel.focus_knob("gravity_scale")
	var start: float = _knobs.get_f("gravity_scale")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = _row_point(_panel.get_row(), 100.0)
	_panel.handle_mouse(wheel)
	assert_gt(_knobs.get_f("gravity_scale"), start)


func test_right_click_closes() -> void:
	_setup()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = _stage_point(Vector2(50, 50))
	_panel.handle_mouse(event)
	assert_false(_panel.is_open())
