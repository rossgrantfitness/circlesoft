extends TestCase
## The field menu's Config page: Wide Windows and Timing Offset sit next to Auto-Timing.

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
	_go_to_row(menu, 5)  # Config is the sixth row of the field menu
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page(), "config")
	return menu


func _go_to_row(menu: FieldMenu, row: int) -> void:
	for i: int in row:
		menu.handle_command(MenuInput.Cmd.DOWN)


func test_config_page_lists_the_battle_options_after_auto_timing() -> void:
	var menu: FieldMenu = _open_config()
	var ids: Array[String] = []
	for row: Dictionary in menu.get_page_list().get_items():
		ids.append(str(row["id"]))
	assert_eq(ids, ["text_speed", "voice_volume", "auto_timing", "wide_windows", "timing_offset"])


func test_wide_windows_toggles_with_the_arrows_and_confirm() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, 3)
	assert_false(_config.get("wide_windows"))
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_true(_config.get("wide_windows"))
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(_config.get("wide_windows"))
	assert_true(str(menu.get_page_list().get_items()[3]["value"]).contains("Off"))


func test_timing_offset_steps_in_ms_and_shows_its_sign() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, 4)
	var step: int = _config.call("get_timing_offset_step_ms")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), step)
	assert_true(str(menu.get_page_list().get_items()[4]["value"]).contains("+%d ms" % step))
	menu.handle_command(MenuInput.Cmd.LEFT)
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(_config.get("timing_offset_ms"), -step)
	assert_true(str(menu.get_page_list().get_items()[4]["value"]).contains("-%d ms" % step))


func test_timing_offset_stops_at_the_range_end_with_the_arrows_and_wraps_on_confirm() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, 4)
	var high: int = _config.call("get_timing_offset_max_ms")
	_config.call("set_timing_offset_ms", high)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(_config.get("timing_offset_ms"), high, "arrows stop at the end")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_config.get("timing_offset_ms"), _config.call("get_timing_offset_min_ms"), "confirm wraps")


func test_leaving_the_page_saves_the_new_options() -> void:
	var menu: FieldMenu = _open_config()
	_go_to_row(menu, 3)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH))
	assert_eq(saved["wide_windows"], true)
	assert_eq(int(saved["timing_offset_ms"]), int(_config.call("get_timing_offset_step_ms")))


func test_the_five_config_rows_fit_inside_the_side_window() -> void:
	var menu: FieldMenu = _open_config()
	var list: MenuList = menu.get_page_list()
	var last: Rect2 = list.get_row_rect(4)
	assert_gt(last.size.y, 0.0, "the fifth row is on screen")
	assert_le(last.end.y, list.size.y)
