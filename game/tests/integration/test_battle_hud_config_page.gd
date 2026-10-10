extends TestCase
## The field menu's Config page (the shared Config screen, embedded): Wide Windows and Timing Offset
## sit next to Auto-Timing and save when the page is left.

const MENU_SCENE: String = "res://scenes/ui/field_menu.tscn"
const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"
const CONFIG_SCRIPT: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_battle_hud_config_page_scratch.json"

var _config: Node = null


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func _open_config() -> FieldMenu:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	_config = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	_config.set("save_path", SCRATCH)
	var menu: FieldMenu = (load(MENU_SCENE) as PackedScene).instantiate() as FieldMenu
	menu.manual_ticks = true
	menu.animations_enabled = false
	menu.game_state = state
	menu.config = _config
	menu.audio.target = FakeAudio.new()
	add_to_root(menu)
	menu.open()
	for i: int in 5:
		menu.handle_command(MenuInput.Cmd.DOWN)  # Config is the sixth row of the field menu
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page(), "config")
	return menu


func _screen(menu: FieldMenu) -> ConfigScreen:
	return (menu.get_page_object() as PageConfig).get_screen()


func _go_to_row(menu: FieldMenu, row_id: String) -> void:
	var screen: ConfigScreen = _screen(menu)
	screen.get_list().set_index(screen.get_row_ids().find(row_id), false)


func test_config_page_lists_the_battle_options_up_front() -> void:
	var menu: FieldMenu = _open_config()
	var ids: Array[String] = _screen(menu).get_row_ids()
	assert_eq(ids.slice(0, 4), ["auto_timing", "wide_windows", "timing_offset", "tap_along"] as Array[String])


func test_wide_windows_toggles_with_the_arrows_and_confirm() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, "wide_windows")
	assert_false(_config.get("wide_windows"))
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_true(_config.get("wide_windows"))
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(_config.get("wide_windows"))
	assert_eq(_screen(menu).get_row_value("wide_windows"), "Off")


func test_timing_offset_steps_in_ms_and_shows_its_sign() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, "timing_offset")
	var step: int = _config.call("get_timing_offset_step_ms")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), step)
	assert_true(_screen(menu).get_row_value("timing_offset").contains("+%d" % step))
	menu.handle_command(MenuInput.Cmd.LEFT)
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(_config.get("timing_offset_ms"), -step)
	assert_true(_screen(menu).get_row_value("timing_offset").contains("-%d" % step))


func test_timing_offset_stops_at_the_range_end_with_the_arrows_and_wraps_on_confirm() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, "timing_offset")
	var high: int = _config.call("get_timing_offset_max_ms")
	_config.call("set_timing_offset_ms", high)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), high, "arrows stop at the end")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("timing_offset_ms"), _config.call("get_timing_offset_min_ms"), "confirm wraps")


func test_leaving_the_page_saves_the_new_options() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, "wide_windows")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	_go_to_row(menu, "timing_offset")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH))
	assert_eq(saved["wide_windows"], true)
	assert_eq(int(saved["timing_offset_ms"]), int(_config.call("get_timing_offset_step_ms")))
