extends TestCase
## The slice's front door: the same title screen with the slice's words and four rows (New Game, Continue, Config, Quit), New Game
## straight into the first room (no name window), Continue from the newest slice save, and the HUD's Quit going back to the title.
## The classic game's title is unchanged. Tested against the throwaway graybox rooms until the market is the start.

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"
const MENU_OPEN_WAIT_S: float = 0.7
const FADE_WAIT_LIMIT_S: float = 4.0

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _old_dir: String = ""
var _dir: String = ""


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_old_dir = str(_manager.get("save_dir"))
	_dir = "user://test_front_door_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_dir)
	_manager.set("rooms_data_id", "world/rooms")
	_manager.set("saving_allowed", true)
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	InputSorting.revert()
	SandboxPauseGate.clear(tree)
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


func _boot(slice: bool) -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	if slice:
		_main.apply_mode(GameMode.Mode.SLICE)
		_router.set("rooms_id", ROOMS_ID)
		_manager.set("rooms_data_id", ROOMS_ID)
		_state.set("rooms_data_id", ROOMS_ID)
		Placements.extra_ids = [PLACEMENTS_ID] as Array[String]
	_manager.set("save_dir", _dir)          # after apply_mode, which points it at the real slice folder
	_router.set("main", _main)
	_router.set("instant", true)
	_state.call("reset")
	_main.go_to_title()
	await tree.process_frame


func _title() -> TitleScreen:
	return _main.get_title() as TitleScreen


func _open_menu() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"confirm"
	press.pressed = true
	tree.root.push_input(press)
	await tree.create_timer(MENU_OPEN_WAIT_S).timeout


func _until_room(room_id: String) -> ActionRoom:
	var waited: float = 0.0
	while waited < FADE_WAIT_LIMIT_S:
		await tree.physics_frame
		waited += 1.0 / 60.0
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


# ---- the title ----

func test_the_slice_title_has_the_slice_words_and_four_rows() -> void:
	await _boot(true)
	var title: TitleScreen = _title()
	assert_not_null(title)
	assert_eq(title.text_id, "text/title_slice")
	assert_false(title.ask_hero_name)
	assert_eq(title.get_item_ids(), ["new_game", "continue", "config", "quit"] as Array[String], "no Battle Test row")
	assert_eq(title.get_demo_tag_text(), "GRAYBOX")


func test_the_classic_title_is_unchanged() -> void:
	await _boot(false)
	var title: TitleScreen = _title()
	assert_eq(title.text_id, "text/title")
	assert_true(title.ask_hero_name, "the old game still asks for the hero's name")
	assert_true(title.get_item_ids().has("config"))
	assert_true(title.get_item_ids().has("quit"))


func test_continue_is_greyed_until_a_slice_save_exists() -> void:
	await _boot(true)
	var title: TitleScreen = _title()
	assert_false(title.is_item_enabled("continue"), "an empty slice save folder")
	assert_eq(title.get_continue_slot(), -1)


func test_the_old_games_saves_do_not_show_up_in_the_slice_title() -> void:
	await _boot(true)
	_manager.set("save_dir", GameMode.save_dir(GameMode.Mode.SLICE))
	assert_ne(str(_manager.get("save_dir")), GameMode.save_dir(GameMode.Mode.CLASSIC), "the slice reads its own folder")
	_manager.set("save_dir", _dir)
	assert_false(_title().is_item_enabled("continue"))


# ---- New Game ----

func test_new_game_goes_straight_to_the_first_room_with_no_name_window() -> void:
	await _boot(true)
	var title: TitleScreen = _title()
	await _open_menu()
	var index: int = title.get_item_ids().find("new_game")
	title.set_cursor(index, false)
	title.choose(index)
	assert_eq(title.get_state(), TitleScreen.State.LEAVING, "no name entry: it fades out at once")
	var room: ActionRoom = await _until_room("gb_hub")
	assert_not_null(room, "the start room of the rooms file")
	assert_eq(_main.get_state(), Main.State.ROOM)
	assert_null(_main.get_title())
	assert_eq(str(_state.call("get_hero_name")), "Red")
	assert_true(room.hero.is_inside_tree())
	assert_not_null(room.get_hud(), "the HUD comes up with the first room")


# ---- Continue ----

func test_continue_loads_the_newest_slice_save() -> void:
	await _boot(true)
	_main.start_new_game()
	var hub: ActionRoom = await _until_room("gb_hub")
	hub.hero.hp = 61
	_router.call("go_to", "gb_yard", "from_hub")
	var yard: ActionRoom = await _until_room("gb_yard")
	_state.call("add_credits", 33)
	assert_true(_manager.call("save_slot", 1))
	_main.go_to_title()
	await tree.process_frame
	var title: TitleScreen = _title()
	assert_true(title.is_item_enabled("continue"), "a slice save exists")
	assert_eq(title.get_continue_slot(), 1)
	_state.call("reset")
	await _open_menu()
	var index: int = title.get_item_ids().find("continue")
	title.set_cursor(index, false)
	title.choose(index)
	var room: ActionRoom = await _until_room("gb_yard")
	assert_eq(int(_state.call("get_credits")), 33, "the saved game")
	assert_eq(room.hero.hp, 61, "with the health she had")


func test_config_opens_from_the_slice_title() -> void:
	await _boot(true)
	var title: TitleScreen = _title()
	await _open_menu()
	var index: int = title.get_item_ids().find("config")
	title.set_cursor(index, false)
	title.choose(index)
	assert_eq(title.get_state(), TitleScreen.State.CONFIG)


# ---- Quit goes back to the title ----

func test_the_huds_quit_goes_back_to_the_title() -> void:
	await _boot(true)
	_main.start_new_game()
	var room: ActionRoom = await _until_room("gb_hub")
	var hud: Node = room.get_hud()
	assert_not_null(hud)
	assert_false(bool(hud.get("auto_quit")), "Quit must not close the program")
	hud.emit_signal("quit_requested")
	for i: int in 10:
		await tree.process_frame
	assert_not_null(_main.get_title(), "the title is back")
	assert_eq(_main.get_state(), Main.State.TITLE)
	assert_null(_main.get_room())
	assert_eq(tree.get_nodes_in_group(ActionRoom.GROUP_HUD).size(), 0, "the HUD went with the room")
	assert_false(tree.paused)
	assert_eq((_title() as TitleScreen).text_id, "text/title_slice", "and it is the slice's title again")


func test_quit_from_the_continue_screen_also_goes_back_with_the_pause_released() -> void:
	await _boot(true)
	_main.start_new_game()
	await _until_room("gb_hub")
	_router.call("go_to", "gb_yard", "from_hub")
	var yard: ActionRoom = await _until_room("gb_yard")
	yard.hero.apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})
	var screen: ContinueScreen = yard.get_hud().call("get_continue_screen") as ContinueScreen
	assert_true(screen.is_open())
	screen.quit_chosen.emit()
	for i: int in 10:
		await tree.process_frame
	assert_eq(_main.get_state(), Main.State.TITLE)
	assert_false(tree.paused, "the pause the Continue screen held is let go")


func test_a_new_game_after_quitting_starts_clean() -> void:
	await _boot(true)
	_main.start_new_game()
	var first: ActionRoom = await _until_room("gb_hub")
	_state.call("add_credits", 500)
	first.quit_to_title_requested.emit()
	for i: int in 10:
		await tree.process_frame
	_main.start_new_game()
	var again: ActionRoom = await _until_room("gb_hub")
	assert_eq(int(_state.call("get_credits")), 0)
	assert_eq(again.hero.hp, again.hero.hp_max)


# ---- the real slice data ----

func test_the_real_slice_goes_from_the_title_to_the_hideout() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)           # slice/rooms.json and slice/placements.json, the Level Designer's
	_manager.set("save_dir", _dir)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.call("reset")
	_main.go_to_title()
	await tree.process_frame
	var title: TitleScreen = _title()
	await _open_menu()
	var index: int = title.get_item_ids().find("new_game")
	title.set_cursor(index, false)
	title.choose(index)
	var start: String = str(DataDB.get_value("slice/rooms", "start_room", ""))
	assert_ne(start, "", "slice/rooms.json names a start room")
	var room: ActionRoom = await _until_room(start)
	assert_not_null(room, "New Game lands in %s" % start)
	if room != null:
		assert_eq(room.room_kind(), "town")
		assert_true(room.hero.town_mode, "the hideout is a safe room")
		assert_not_null(room.get_hud())
