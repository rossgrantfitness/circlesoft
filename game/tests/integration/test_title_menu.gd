extends TestCase
## The M3 title menu: New Game / Continue / Config / Battle Test / Quit, Continue greyed out until a
## save exists (and loading the newest one when it does), New Game asking for the hero's name,
## Config opening the shared Config screen, and the v0.3.0 tag.

const SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const CONFIG_SCRIPT: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_title_menu_scratch.json"
const MENU_OPEN_WAIT_S: float = 0.7
const FADE_WAIT_LIMIT_S: float = 3.0

var _saves: FakeTitleSaves = null
var _config: Node = null


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func _make_title(with_save: bool = false) -> TitleScreen:
	var title: TitleScreen = (load(SCENE_PATH) as PackedScene).instantiate() as TitleScreen
	_saves = FakeTitleSaves.new()
	_saves.saves_exist = with_save
	_saves.newest = 2
	own(_saves)
	title.save_manager = _saves
	_config = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	_config.set("save_path", SCRATCH)
	_config.set("apply_bindings_live", false)
	title.config = _config
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
	await tree.process_frame
	_press(&"confirm")
	await _wait(MENU_OPEN_WAIT_S)


func _go_to(title: TitleScreen, item_id: String) -> void:
	var target: int = title.get_item_ids().find(item_id)
	assert_ge(target, 0, "menu has %s" % item_id)
	title.set_cursor(target, false)


func _wait_for_leave(title: TitleScreen, seen: Array) -> void:
	var waited: float = 0.0
	while seen.is_empty() and waited < FADE_WAIT_LIMIT_S:
		await _wait(0.1)
		waited += 0.1


# ---- items and states ----

func test_the_menu_is_new_game_continue_config_battle_test_quit() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_eq(title.get_item_ids(), ["new_game", "continue", "config", "battle_test", "quit"] as Array[String])
	assert_eq(title.get_item_label_texts(), ["New Game", "Continue", "Config", "Battle Test", "Quit"] as Array[String])


func test_the_version_tag_says_v0_3_0() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_eq(title.get_version_text(), "v0.3.0")


func test_battle_test_is_a_dev_entry_that_data_can_hide() -> void:
	var text: Dictionary = DataDB.get_dict("text/title")
	var dev_flags: Array[bool] = []
	for entry: Dictionary in text["menu"]:
		dev_flags.append(bool(entry.get("dev", false)))
	assert_eq(dev_flags, [false, false, false, true, false] as Array[bool], "only Battle Test is marked dev")
	text["dev_items"] = false
	var title: TitleScreen = _make_title()
	await tree.process_frame
	text["dev_items"] = true
	assert_eq(title.get_item_ids(), ["new_game", "continue", "config", "quit"] as Array[String], "with dev items off it is gone")


func test_continue_is_greyed_out_when_there_is_no_save() -> void:
	var title: TitleScreen = _make_title(false)
	await tree.process_frame
	assert_false(title.is_item_enabled("continue"))
	assert_eq(title.get_item_enabled_flags(), [true, false, true, true, true] as Array[bool])
	assert_eq(title.get_continue_slot(), -1)


func test_continue_is_lit_when_a_save_exists() -> void:
	var title: TitleScreen = _make_title(true)
	await tree.process_frame
	assert_true(title.is_item_enabled("continue"))
	assert_eq(title.get_item_enabled_flags(), [true, true, true, true, true] as Array[bool])
	assert_eq(title.get_continue_slot(), 2, "the newest save's slot")


func test_continue_follows_the_save_manager_live() -> void:
	var title: TitleScreen = _make_title(false)
	await tree.process_frame
	assert_false(title.is_item_enabled("continue"))
	_saves.saves_exist = true
	assert_true(title.is_item_enabled("continue"), "a save that appears is noticed")


func test_with_no_save_manager_at_all_continue_stays_greyed() -> void:
	var title: TitleScreen = (load(SCENE_PATH) as PackedScene).instantiate() as TitleScreen
	title.save_manager = null
	add_to_root(title)
	await tree.process_frame
	# The real autoload may or may not have a save; asking a bare Node must not crash.
	var bare: Node = own(Node.new()) as Node
	title.save_manager = bare
	assert_false(title.is_item_enabled("continue"), "a manager that can't answer means no save")


func test_the_cursor_starts_on_new_game_without_a_save_and_on_continue_with_one() -> void:
	var fresh: TitleScreen = _make_title(false)
	await _open_menu(fresh)
	assert_eq(fresh.get_cursor_index(), 0)
	var returning: TitleScreen = _make_title(true)
	await _open_menu(returning)
	assert_eq(returning.get_cursor_index(), returning.get_item_ids().find("continue"), "one press loads the newest save")


func test_picking_a_greyed_continue_does_nothing_but_buzz() -> void:
	var title: TitleScreen = _make_title(false)
	await _open_menu(title)
	var heard: Array[int] = []
	title.continue_requested.connect(func() -> void: heard.append(1))
	_go_to(title, "continue")
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.MENU, "still on the menu")
	await _wait(0.5)
	assert_eq(heard.size(), 0)


func test_continue_with_a_save_fades_out_then_signals_the_newest_slot() -> void:
	var title: TitleScreen = _make_title(true)
	await _open_menu(title)
	var slots: Array[int] = []
	var plain: Array[int] = []
	var legacy: Array[int] = []
	title.continue_slot_requested.connect(func(slot: int) -> void: slots.append(slot))
	title.continue_requested.connect(func() -> void: plain.append(title.get_fade_step()))
	title.start_demo_requested.connect(func() -> void: legacy.append(1))
	_press(&"confirm")  # the cursor is already on Continue
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)
	assert_eq(plain.size(), 0, "not before the fade")
	await _wait_for_leave(title, plain)
	assert_eq(plain.size(), 1)
	assert_eq(plain[0], title.get_fade_step_count(), "the screen is black when it fires")
	assert_eq(slots, [2])
	assert_eq(legacy.size(), 0, "Continue is not New Game")
	await _wait(0.3)
	assert_eq(plain.size(), 1, "never twice")


func test_the_continue_slot_comes_from_newest_slot_not_a_guess() -> void:
	var title: TitleScreen = _make_title(true)
	_saves.newest = 3
	await _open_menu(title)
	var slots: Array[int] = []
	title.continue_slot_requested.connect(func(slot: int) -> void: slots.append(slot))
	_press(&"confirm")
	await _wait_for_leave(title, slots)
	assert_eq(slots, [3])


# ---- new game and the name ----

func test_new_game_asks_for_a_name_that_starts_as_red() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.NAME_ENTRY)
	assert_true(title.get_name_entry().is_open())
	assert_eq(title.get_name_entry().get_name_text(), "Red")
	await _wait(0.5)
	assert_false(title.is_menu_visible(), "the menu window is out of the way")


func test_confirming_the_default_name_starts_the_game_as_red_after_the_fade() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	var names: Array[String] = []
	var legacy: Array[int] = []
	title.new_game_requested.connect(func(hero_name: String) -> void: names.append(hero_name))
	title.start_demo_requested.connect(func() -> void: legacy.append(title.get_fade_step()))
	_press(&"confirm")
	var entry: NameEntry = title.get_name_entry()
	entry.set_cursor(entry.get_action_ids().find("ok"), entry.get_grid_rows().size())
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)
	assert_eq(names.size(), 0, "after the fade, not before")
	await _wait_for_leave(title, names)
	assert_eq(names, ["Red"])
	assert_eq(legacy, [title.get_fade_step_count()], "the old signal still fires, once, for a Main that has not changed")


func test_a_typed_name_is_what_new_game_reports() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_press(&"confirm")
	var names: Array[String] = []
	title.new_game_requested.connect(func(hero_name: String) -> void: names.append(hero_name))
	var entry: NameEntry = title.get_name_entry()
	entry.set_name_text("")
	for letter: String in ["R", "u", "b", "y"]:
		entry.type_char(letter)
	entry.submit()
	await _wait_for_leave(title, names)
	assert_eq(names, ["Ruby"])


func test_cancelling_the_name_goes_back_to_the_menu() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_press(&"confirm")
	for i: int in 3:
		_press(&"cancel")  # deletes R, e, d
	assert_eq(title.get_state(), TitleScreen.State.NAME_ENTRY)
	assert_eq(title.get_name_entry().get_name_text(), "")
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.MENU)
	assert_false(title.get_name_entry().is_open())
	await _wait(0.5)
	assert_true(title.is_menu_ready(), "the menu is back")
	assert_eq(title.get_cursor_index(), 0)


func test_the_name_entry_takes_the_whole_keyboard_while_it_is_open() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_press(&"confirm")
	var entry: NameEntry = title.get_name_entry()
	entry.set_name_text("")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_Q
	key.unicode = 113
	key.pressed = true
	tree.root.push_input(key)
	assert_eq(entry.get_name_text(), "q")
	assert_eq(title.get_state(), TitleScreen.State.NAME_ENTRY, "typing did not move the title menu")


# ---- config ----

func test_config_opens_the_shared_config_screen() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_go_to(title, "config")
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.CONFIG)
	await _wait(0.5)
	var screen: ConfigScreen = title.get_config_screen()
	assert_true(screen.is_open())
	assert_eq(screen.get_state(), ConfigScreen.State.LIST)
	assert_false(title.is_menu_visible())


func test_config_changes_made_from_the_title_are_saved_and_cancel_returns_to_the_menu() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_go_to(title, "config")
	_press(&"confirm")
	await _wait(0.5)
	var screen: ConfigScreen = title.get_config_screen()
	screen.get_list().set_index(screen.get_row_ids().find("auto_advance"), false)
	_press(&"confirm")
	assert_true(_config.get("auto_advance"), "the click went to the Config screen, not the title menu")
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.MENU)
	assert_false(screen.is_open())
	assert_true(FileAccess.file_exists(SCRATCH), "saved through Config")
	await _wait(0.5)
	assert_true(title.is_menu_ready())
	assert_eq(title.get_item_ids()[title.get_cursor_index()], "config", "the cursor is where it was")


func test_the_config_screen_fits_the_stage_and_the_menu_fits_above_the_credit_line() -> void:
	var layout: Dictionary = DataDB.get_dict("ui/ui_theme")["title_screen"]
	var config: Dictionary = layout["config_window"]
	assert_true(Rect2(0, 0, 384, 216).encloses(Rect2(float(config["x"]), float(config["y"]), float(config["w"]), float(config["h"]))))
	var window: Dictionary = layout["menu_window"]
	assert_le(float(window["y"]) + float(window["h"]), 197.0)
	var rows: int = (DataDB.get_dict("text/title")["menu"] as Array).size()
	assert_le(float(layout["menu_item_first_y"]) + float(rows) * float(layout["menu_item_step"]), float(window["h"]))


func test_battle_test_still_opens_its_picker() -> void:
	var title: TitleScreen = _make_title()
	await _open_menu(title)
	_go_to(title, "battle_test")
	_press(&"confirm")
	assert_eq(title.get_state(), TitleScreen.State.PICKER)
	assert_true(title.get_picker().is_open())


func test_mouse_click_on_a_greyed_continue_does_not_leave() -> void:
	var title: TitleScreen = _make_title(false)
	await _open_menu(title)
	_go_to(title, "continue")
	title.choose(title.get_cursor_index())
	assert_eq(title.get_state(), TitleScreen.State.MENU)
