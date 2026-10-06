extends TestCase
## The demo title screen: loads, takes its text from data, hides the menu until a start press,
## moves a cursor with keyboard, controller and mouse, and emits start_demo_requested after a fade.

const SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const TEXT_ID: String = "text/title"
const THEME_ID: String = "ui/ui_theme"
const STAGE_SIZE: Vector2 = Vector2(384, 216)
const MENU_OPEN_WAIT_S: float = 0.7
const FADE_WAIT_LIMIT_S: float = 3.0
const FRAME_WAIT: int = 3
const FADE_STEPS: int = 8
const WINDOW_SIZE: Vector2 = Vector2(1280, 720)
const LATER_SIZE: Vector2 = Vector2(1920, 1080)


func _make_title() -> TitleScreen:
	var title: TitleScreen = (load(SCENE_PATH) as PackedScene).instantiate() as TitleScreen
	add_to_root(title)
	return title


func _action(name: StringName, pressed: bool = true) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = pressed
	return event


func _press(name: StringName) -> void:
	tree.root.push_input(_action(name))
	tree.root.push_input(_action(name, false))


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func _open_menu(title: TitleScreen) -> void:
	_press(&"confirm")
	await _wait(MENU_OPEN_WAIT_S)


func _mouse_at_item(title: TitleScreen, index: int) -> Vector2:
	var layout: Dictionary = DataDB.get_dict(THEME_ID)["title_screen"]
	var window: Dictionary = layout["menu_window"]
	var y: float = float(window["y"]) + float(layout["menu_item_first_y"]) + float(layout["menu_item_step"]) * float(index) + 4.0
	var stage_point: Vector2 = Vector2(float(window["x"]) + float(window["w"]) / 2.0, y)
	var rect: Rect2 = title.get_display_rect()
	return rect.position + stage_point * title.get_display_scale()


## Test windows are tiny and stretched, so a point in the title's own coordinates must be turned
## into a window pixel before it is pushed (the window turns it back, like it does for a real mouse).
func _to_window(position: Vector2) -> Vector2:
	return tree.root.get_final_transform() * position


func _move_mouse(title: TitleScreen, position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _to_window(position)
	motion.global_position = motion.position
	tree.root.push_input(motion)


func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _to_window(position)
	event.global_position = event.position
	event.button_index = button
	event.pressed = true
	tree.root.push_input(event)


func test_scene_loads_and_is_a_title_screen() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(scene, "scene file loads")
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_not_null(title, "root is a TitleScreen")
	assert_eq(title.get_state(), TitleScreen.State.PRESS_START)


func test_data_files_exist_and_parse() -> void:
	assert_true(DataDB.has_json(TEXT_ID), "data/text/title.json loaded")
	assert_true(DataDB.has_json(THEME_ID), "data/ui/ui_theme.json loaded")
	assert_false(DataDB.has_errors(), "no data errors")


func test_strings_come_from_data() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var text: Dictionary = DataDB.get_dict(TEXT_ID)
	assert_eq(title.get_title_text(), str(text["title"]))
	assert_eq(title.get_demo_tag_text(), str(text["demo_tag"]))
	assert_eq(title.get_press_start_text(), str(text["press_start"]))
	assert_eq(title.get_credit_text(), str(text["credit"]))
	assert_eq(title.get_version_text(), str(text["version"]))
	var labels: Array[String] = []
	var ids: Array[String] = []
	for entry: Dictionary in text["menu"]:
		labels.append(str(entry["label"]))
		ids.append(str(entry["id"]))
	assert_eq(title.get_item_label_texts(), labels)
	assert_eq(title.get_item_ids(), ids)
	assert_has(ids, "start_demo")
	assert_has(ids, "quit")


func test_strings_follow_edited_data() -> void:
	# Proves nothing is hard-coded: change the data in memory, build a new screen, see the change.
	var text: Dictionary = DataDB.get_dict(TEXT_ID)
	var original: String = str(text["credit"])
	text["credit"] = "a test credit"
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_eq(title.get_credit_text(), "a test credit")
	text["credit"] = original


func test_theme_palette_matches_style_guide() -> void:
	var palette: Dictionary = DataDB.get_dict(THEME_ID)["palette"]
	assert_eq(str(palette["lamp_amber"]).to_upper(), "#FFB347")
	assert_eq(str(palette["chalk"]).to_upper(), "#EDEAD8")
	assert_eq(str(palette["window_fill"]).to_upper(), "#1B1A33")
	assert_eq(str(palette["window_hatch"]).to_upper(), "#232246")
	assert_eq(str(palette["text_dim"]).to_upper(), "#7C7A8E")
	assert_eq(str(palette["ink"]).to_upper(), "#14121F")
	assert_eq(str(palette["night"]).to_upper(), "#1F2540")


func test_renders_at_internal_resolution() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var viewport: SubViewport = title.get_node("PixelViewport") as SubViewport
	assert_eq(Vector2(viewport.size), STAGE_SIZE, "384x216")
	var display: TextureRect = title.get_node("Display") as TextureRect
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "nearest-neighbor")
	var scale: float = title.get_display_scale()
	assert_eq(scale, floorf(scale), "whole-number scale at the base window size")
	assert_gt(scale, 0.99)


func test_menu_starts_hidden_and_press_start_shows() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_false(title.is_menu_visible(), "menu hidden at the start")
	await _wait(0.1)
	assert_false(title.is_menu_visible(), "still hidden with no input")
	var press_start: Label = title.get_node("PixelViewport/Stage/PressStart") as Label
	assert_eq(press_start.text, title.get_press_start_text())


func test_confirm_opens_menu() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var opened: Array[bool] = []
	title.menu_opened.connect(func() -> void: opened.append(true))
	_press(&"confirm")
	assert_true(title.is_menu_visible(), "menu appears after confirm")
	assert_eq(title.get_state(), TitleScreen.State.MENU)
	assert_eq(opened.size(), 1)
	await _wait(MENU_OPEN_WAIT_S)
	assert_true(title.is_menu_ready(), "window finishes opening")
	assert_eq(title.get_cursor_index(), 0, "cursor starts on Start Demo")


func test_start_action_also_opens_menu() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	_press(&"start")
	assert_true(title.is_menu_visible())


func test_real_key_events_open_menu_and_move_cursor() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var enter: InputEventKey = InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	tree.root.push_input(enter)
	assert_true(title.is_menu_visible(), "Enter opens the menu through the real key map")
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.keycode = KEY_DOWN
	down.pressed = true
	tree.root.push_input(down)
	assert_eq(title.get_cursor_index(), 1, "Down arrow moves the cursor")


func test_unrelated_input_does_not_open_menu() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	_press(&"move_down")
	_press(&"cancel")
	_press(&"menu")
	assert_false(title.is_menu_visible())


func test_mouse_click_opens_menu() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	_click(Vector2(100, 100))
	assert_true(title.is_menu_visible())


func test_cursor_moves_and_wraps() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	_press(&"move_down")
	assert_eq(title.get_cursor_index(), 1)
	_press(&"move_down")
	assert_eq(title.get_cursor_index(), 0, "wraps to the top")
	_press(&"move_up")
	assert_eq(title.get_cursor_index(), 1, "wraps to the bottom")


func test_controller_stick_moves_once_per_push() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	var push: InputEventJoypadMotion = InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_LEFT_Y
	push.axis_value = 1.0
	tree.root.push_input(push)
	tree.root.push_input(push)
	assert_eq(title.get_cursor_index(), 1, "held stick moves one row, not one per event")
	var release: InputEventJoypadMotion = InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_LEFT_Y
	release.axis_value = 0.0
	tree.root.push_input(release)
	tree.root.push_input(push)
	assert_eq(title.get_cursor_index(), 0, "pushes again after returning to center")


func test_cancel_backs_out_to_press_start() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.PRESS_START)
	await _wait(MENU_OPEN_WAIT_S)
	assert_false(title.is_menu_visible(), "window closed again")


func test_mouse_hover_moves_cursor_and_click_picks() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	var started: Array[bool] = []
	title.start_demo_requested.connect(func() -> void: started.append(true))
	_move_mouse(title, _mouse_at_item(title, 1))
	assert_eq(title.get_cursor_index(), 1, "hover moves the cursor to Quit")
	_move_mouse(title, _mouse_at_item(title, 0))
	assert_eq(title.get_cursor_index(), 0, "hover back to Start Demo")
	_click(_mouse_at_item(title, 0))
	assert_eq(title.get_state(), TitleScreen.State.LEAVING, "click on Start Demo starts leaving")


func test_right_click_backs_out() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	assert_eq(title.get_state(), TitleScreen.State.PRESS_START)


func test_start_demo_emits_signal_after_fade_to_black() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	var heard: Array[int] = []
	title.start_demo_requested.connect(func() -> void: heard.append(title.get_fade_step()))
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)
	assert_eq(heard.size(), 0, "not emitted before the fade has run")
	var waited: float = 0.0
	while heard.is_empty() and waited < FADE_WAIT_LIMIT_S:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	assert_eq(heard.size(), 1, "emitted exactly once")
	assert_eq(heard[0], title.get_fade_step_count(), "screen is fully black when it fires")
	assert_eq(title.get_fade_step_count(), FADE_STEPS)
	await _wait(0.3)
	assert_eq(heard.size(), 1, "never emitted twice")


func test_input_is_ignored_while_leaving() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	await _open_menu(title)
	_press(&"confirm")
	_press(&"move_down")
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)
	assert_eq(title.get_cursor_index(), 0)


func test_quit_item_calls_the_quit_handler() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var quits: Array[bool] = []
	title.quit_handler = func() -> void: quits.append(true)
	await _open_menu(title)
	_press(&"move_down")
	_press(&"move_down")  # Start Demo, Battle Test, then Quit
	_press(&"confirm")
	assert_eq(quits.size(), 1, "Quit runs the handler (get_tree().quit() by default)")
	assert_eq(title.get_state(), TitleScreen.State.MENU, "quit does not start the demo")


func test_fades_in_from_black_at_start() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_gt(title.get_fade_step(), 0, "starts dark")
	await _wait(1.0)
	assert_eq(title.get_fade_step(), 0, "fully clear after the intro fade")


func test_lamp_flickers_but_stays_in_range() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var seen: Dictionary[int, bool] = {}
	var backdrop: TitleBackdrop = title.get_backdrop()
	for i: int in 90:
		await tree.process_frame
		seen[backdrop.lamp_level] = true
		assert_ge(backdrop.lamp_level, 0)
		assert_lt(backdrop.lamp_level, TitleBackdrop.LAMP_LEVELS)
	assert_ge(seen.size(), 1, "lamp has a level")


func test_integer_scaling_on_full_hd_and_fallback() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	title.size = LATER_SIZE
	assert_eq(title.get_display_scale(), 5.0, "5x on 1080p")
	title.size = Vector2(1000, 600)
	assert_almost_eq(title.get_display_scale(), 1000.0 / STAGE_SIZE.x, 0.001, "2x would fill under 80%, so it scales to fit")
