extends TestCase
## The field menu shell: opens and closes, freezes Red, moves a cursor that wraps, lists the bag with
## counts, shows the party, changes Config settings, greys Save away from a lamp, and opens the lamp's
## save screen at one. The pages have their own test files (test_field_menu_*.gd).

const MENU_SCENE: String = "res://scenes/ui/field_menu.tscn"
const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const SCRATCH: String = "user://test_menu_config_scratch.json"

var _audio: FakeAudio = null
var _state: Node = null
var _config: Node = null


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func _make(animated: bool = false) -> FieldMenu:
	_audio = FakeAudio.new()
	_state = MenuKit.make_state(self)
	_config = MenuKit.make_config(self, SCRATCH)
	var menu: FieldMenu = MenuKit.make_menu(self, _state, _audio, _config)
	menu.animations_enabled = animated
	return menu


func _go(menu: FieldMenu, commands: Array) -> void:
	for command: MenuInput.Cmd in commands:
		menu.handle_command(command)


func _open_page(menu: FieldMenu, index: int) -> void:
	assert_true(menu.open())
	for i: int in index:
		menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)


func test_starts_closed_and_hidden() -> void:
	var menu: FieldMenu = _make()
	assert_false(menu.is_open())
	assert_false(menu.visible)


func test_open_and_close() -> void:
	var menu: FieldMenu = _make()
	var events: Array[String] = []
	menu.opened.connect(func() -> void: events.append("opened"))
	menu.closed.connect(func() -> void: events.append("closed"))
	assert_true(menu.open())
	assert_true(menu.is_open())
	assert_true(menu.visible)
	assert_eq(menu.get_page(), "main")
	assert_eq(menu.get_main_ids(), ["items", "skills", "equip", "status", "party", "config", "save"])
	menu.close()
	assert_false(menu.is_open())
	assert_false(menu.visible)
	assert_eq(events, ["opened", "closed"])


func test_cancel_on_the_main_page_closes() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(menu.is_open())


func test_menu_button_closes_from_any_page() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 0)
	assert_eq(menu.get_page(), "items")
	menu.handle_command(MenuInput.Cmd.MENU)
	assert_false(menu.is_open())


func test_every_page_opens_and_goes_back() -> void:
	var menu: FieldMenu = _make()
	var pages: Array[String] = ["items", "skills", "equip", "status", "party", "config"]
	menu.open()
	for i: int in pages.size():
		assert_eq(menu.get_main_index(), i)
		menu.handle_command(MenuInput.Cmd.CONFIRM)
		assert_eq(menu.get_page(), pages[i])
		assert_not_null(menu.get_page_object(), pages[i])
		assert_not_null(menu.get_page_list(), pages[i])
		# every page answers the d-pad without breaking
		for command: MenuInput.Cmd in [MenuInput.Cmd.DOWN, MenuInput.Cmd.UP, MenuInput.Cmd.LEFT, MenuInput.Cmd.RIGHT]:
			menu.handle_command(command)
			assert_eq(menu.get_page(), pages[i])
		menu.handle_command(MenuInput.Cmd.CANCEL)
		assert_eq(menu.get_page(), "main")
		assert_eq(menu.get_main_index(), i, "the main list kept its row")
		menu.handle_command(MenuInput.Cmd.DOWN)
	assert_true(menu.is_open())


func test_window_grows_open_in_steps_when_animated() -> void:
	var menu: FieldMenu = _make(true)
	menu.open()
	assert_eq(menu.get_state(), FieldMenu.State.OPENING)
	assert_false(menu.get_main_list().visible, "text waits for the window")
	for i: int in 3:
		menu.tick(0.09)
	assert_eq(menu.get_state(), FieldMenu.State.OPENING)
	menu.tick(0.09)
	assert_eq(menu.get_state(), FieldMenu.State.OPEN)
	assert_true(menu.get_main_list().visible)
	menu.close()
	assert_eq(menu.get_state(), FieldMenu.State.CLOSING)
	menu.finish_animations()
	assert_eq(menu.get_state(), FieldMenu.State.CLOSED)


func test_input_is_ignored_while_the_window_opens() -> void:
	var menu: FieldMenu = _make(true)
	menu.open()
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_main_index(), 0)


func test_cursor_moves_and_wraps_with_a_tick_each_time() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	assert_eq(menu.get_main_index(), 0)
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_main_index(), 1)
	menu.handle_command(MenuInput.Cmd.UP)
	menu.handle_command(MenuInput.Cmd.UP)
	assert_eq(menu.get_main_index(), 6, "up from the top wraps to the bottom")
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_main_index(), 0, "down from the bottom wraps to the top")
	var ticks: int = _audio.sfx_ids.count("menu_tick")
	assert_eq(ticks, 4, "one tick per move")


func test_the_info_window_follows_the_cursor() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	var first: String = menu.get_info_text()
	assert_false(first.is_empty())
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_ne(menu.get_info_text(), first)


func test_red_is_frozen_while_open_and_released_two_frames_after_close() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	var menu: FieldMenu = _make()
	menu.player = player
	menu.open()
	assert_true(player.frozen)
	assert_true(UiStage.is_busy(tree))
	menu.close()
	assert_true(player.frozen, "same frame: still frozen")
	menu.tick(0.016)
	menu.tick(0.016)
	menu.tick(0.016)
	assert_false(player.frozen)
	assert_false(UiStage.is_busy(tree))


func test_does_not_open_while_disabled_or_while_a_bubble_is_up() -> void:
	var menu: FieldMenu = _make()
	menu.enabled = false
	assert_false(menu.open())
	menu.enabled = true
	var busy: Node = Node.new()
	add_to_root(busy)
	busy.add_to_group(UiStage.MODAL_GROUP)
	assert_false(menu.open(), "another bubble or menu is up")
	busy.remove_from_group(UiStage.MODAL_GROUP)
	assert_true(menu.open())


func test_menu_action_opens_it_from_input() -> void:
	var menu: FieldMenu = _make()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"menu"
	event.pressed = true
	tree.root.push_input(event)
	assert_true(menu.is_open())


# ---- items ----

func test_items_page_lists_the_bag_with_counts() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 0)
	assert_eq(menu.get_page(), "items")
	var list: MenuList = menu.get_page_list()
	var starting: Dictionary = DataDB.get_dict("party/party")["starting_items"]
	assert_eq(list.get_count(), starting.size())
	var first: Dictionary = list.get_items()[0]
	assert_eq(first["label"], "Ration Bar")
	assert_eq(first["value"], "x%d" % int(starting["ration_bar"]))
	_state.call("add_item", "canned_coffee", 3)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page_list().get_count(), starting.size() + 1, "a new item shows up after re-entering")


func test_item_description_shows_in_the_info_window() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 0)
	assert_eq(menu.get_info_text(), "Small heal. Tastes like the wrapper.")


func test_item_list_cursor_moves_and_is_remembered() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")
	assert_eq(menu.get_main_index(), 0, "main list kept its row")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page_list().get_cursor_index(), 1, "the item list kept its row")


func test_an_empty_bag_is_handled() -> void:
	var menu: FieldMenu = _make()
	for id: String in _state.call("get_item_ids"):
		_state.call("remove_item", id, int(_state.call("item_count", id)))
	_open_page(menu, 0)
	assert_eq(menu.get_page_list().get_count(), 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_page(), "items")


# ---- status, save ----

func test_status_page_opens_and_goes_back() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 3)
	assert_eq(menu.get_page(), "status")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")
	assert_true(menu.is_open())


func test_save_is_greyed_with_a_reason_away_from_a_lamp() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	var rows: Array[Dictionary] = menu.get_main_list().get_items()
	assert_eq(rows[6]["id"], "save")
	assert_false(bool(rows[6].get("enabled", true)), "greyed")
	menu.get_main_list().set_index(6)
	assert_eq(menu.get_info_text(), "Find a save lamp to save.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page(), "main", "a greyed row does nothing")
	assert_true(menu.is_open())
	assert_false(menu.is_save_pending())


func test_save_at_a_lamp_closes_the_menu_and_opens_the_lamps_save_screen() -> void:
	var menu: FieldMenu = _make()
	var manager: FakeSaveManager = FakeSaveManager.new()
	own(manager)
	menu.save_manager = manager
	menu.save_spot_override = true
	menu.open()
	assert_true(bool(menu.get_main_list().get_items()[6].get("enabled", true)), "lit up at a lamp")
	menu.get_main_list().set_index(6)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(menu.is_open())
	assert_true(menu.is_save_pending())
	assert_eq(manager.opened, 0, "waits until the menu has let go of Red")
	menu.tick(0.016)
	menu.tick(0.016)
	menu.tick(0.016)
	assert_eq(manager.opened, 1)
	assert_false(menu.is_save_pending())
	assert_false(manager.rest_asked)


func test_the_save_spot_is_found_from_a_lamp_group_near_red() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	player.global_position = Vector3(1.0, 0.0, 1.0)
	var lamp: Node3D = Node3D.new()
	lamp.add_to_group(&"save_lamp")
	add_to_root(lamp)
	lamp.global_position = Vector3(2.0, 0.0, 1.0)
	var menu: FieldMenu = _make()
	menu.player = player
	assert_true(menu.at_save_spot(), "a lamp a metre away")
	lamp.global_position = Vector3(9.0, 0.0, 1.0)
	assert_false(menu.at_save_spot(), "too far")
	assert_eq(menu.item_context(), "field")
	lamp.global_position = Vector3(1.5, 0.0, 1.0)
	assert_eq(menu.item_context(), "lamp")


# ---- config (the shared ConfigScreen, embedded) ----

func _screen(menu: FieldMenu) -> ConfigScreen:
	return (menu.get_page_object() as PageConfig).get_screen()


func _go_to_config_row(menu: FieldMenu, row_id: String) -> void:
	var screen: ConfigScreen = _screen(menu)
	var index: int = screen.get_row_ids().find(row_id)
	assert_ge(index, 0, "the Config screen has a %s row" % row_id)
	screen.get_list().set_index(index, false)


func test_config_page_embeds_the_shared_config_screen() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	assert_eq(menu.get_page(), "config")
	var screen: ConfigScreen = _screen(menu)
	assert_not_null(screen)
	assert_true(screen.is_open())
	assert_eq(menu.get_page_list(), screen.get_list())
	var ids: Array[String] = screen.get_row_ids()
	for id: String in ["auto_timing", "wide_windows", "timing_offset", "tap_along", "text_speed", "auto_advance", "skip_seen", "voice_volume", "controls"]:
		assert_has(ids, id)


func test_config_page_changes_the_settings_in_config() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	_go_to_config_row(menu, "text_speed")
	assert_eq(_config.get("text_speed"), "normal")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("text_speed"), "fast")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("text_speed"), "fast", "no wrap with the arrows")
	menu.handle_command(MenuInput.Cmd.LEFT)
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(_config.get("text_speed"), "slow")
	_go_to_config_row(menu, "auto_timing")
	assert_false(_config.get("auto_timing"))
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_true(_config.get("auto_timing"), "confirm toggles")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(_config.get("auto_timing"))
	_go_to_config_row(menu, "voice_volume")
	var before: float = _config.call("get_volume", "voice")
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_almost_eq(_config.call("get_volume", "voice"), before - 0.1, 0.001)


func test_config_rows_show_the_current_values() -> void:
	var menu: FieldMenu = _make()
	_config.call("set_text_speed", "slow")
	_open_page(menu, 5)
	var screen: ConfigScreen = _screen(menu)
	assert_eq(screen.get_row_value("text_speed"), "Slow")
	assert_eq(screen.get_row_value("auto_timing"), "Off")
	assert_eq(screen.get_row_value("timing_offset"), "0 ms")


func test_backing_out_of_the_config_screen_saves_and_returns_to_the_main_list() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	_go_to_config_row(menu, "text_speed")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")
	assert_true(FileAccess.file_exists(SCRATCH))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH))
	assert_eq(saved["text_speed"], "fast")
	assert_true(menu.is_open())


func test_the_menu_button_closes_everything_from_the_config_page_and_saves() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	_go_to_config_row(menu, "text_speed")
	menu.handle_command(MenuInput.Cmd.LEFT)
	menu.handle_command(MenuInput.Cmd.MENU)
	assert_false(menu.is_open())
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH))
	assert_eq(saved["text_speed"], "slow")


func test_the_side_and_info_windows_come_back_after_config() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	assert_false(menu.get_node("Frame/SideWindow").visible, "the Config screen draws its own window")
	assert_false(menu.get_node("Frame/InfoWindow").visible)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_true(menu.get_node("Frame/SideWindow").visible)
	assert_true(menu.get_node("Frame/InfoWindow").visible)
	assert_null(menu.get_node_or_null("Frame/ConfigScreen"), "the screen is gone")


func test_a_config_sub_page_gets_raw_input_and_cancel_goes_back_one_level() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	var screen: ConfigScreen = _screen(menu)
	_go_to_config_row(menu, "controls")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_true(screen.is_busy(), "the Controls page is up")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(screen.is_busy())
	assert_eq(menu.get_page(), "config", "cancel only left the sub-page")


func test_text_speed_preview_types_out_at_the_chosen_speed() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 5)
	_go_to_config_row(menu, "text_speed")
	menu.handle_command(MenuInput.Cmd.RIGHT)  # restarts the preview at fast
	menu.tick(0.2)
	var fast: int = menu.get_preview_text().length()
	assert_gt(fast, 0)
	menu.handle_command(MenuInput.Cmd.LEFT)
	menu.handle_command(MenuInput.Cmd.LEFT)  # slow
	menu.tick(0.2)
	assert_lt(menu.get_preview_text().length(), fast, "slow types fewer letters in the same time")


# ---- mouse ----

func _motion(position: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	return event


func _row_point(menu: FieldMenu, index: int) -> Vector2:
	var list: MenuList = menu.get_main_list()
	var rect: Rect2 = list.get_row_rect(index)
	return list.get_global_transform() * (rect.position + rect.size / 2.0)


func test_mouse_hover_moves_the_cursor_and_click_picks() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	menu._input(_motion(_row_point(menu, 2)))
	assert_eq(menu.get_main_index(), 2)
	menu._input(_click(_row_point(menu, 3)))
	assert_eq(menu.get_page(), "status", "click picked the row")


func test_right_click_backs_out() -> void:
	var menu: FieldMenu = _make()
	_open_page(menu, 3)
	menu._input(_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT))
	assert_eq(menu.get_page(), "main")
	menu._input(_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT))
	assert_false(menu.is_open())
