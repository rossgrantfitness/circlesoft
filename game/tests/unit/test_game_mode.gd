extends TestCase
## VS-3: GameMode picks slice / sandbox / classic from the command line and feature tags, each mode
## has its own rooms data and save folder, and Main points the router, save manager and GameState at them.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SliceMode: GameMode.Mode = GameMode.Mode.SLICE
const SANDBOX: GameMode.Mode = GameMode.Mode.SANDBOX
const CLASSIC: GameMode.Mode = GameMode.Mode.CLASSIC


func _args(list: Array[String]) -> PackedStringArray:
	return PackedStringArray(list)


func test_no_word_and_no_tag_uses_the_fallback() -> void:
	assert_eq(GameMode.resolve(_args([]), _args([])), CLASSIC, "classic is the default, as in every old test")
	assert_eq(GameMode.resolve(_args([]), _args([]), SliceMode), SliceMode)
	assert_eq(GameMode.resolve(_args(["--only=foo"]), _args([]), SANDBOX), SANDBOX, "unrelated words change nothing")


func test_each_command_line_word_picks_its_mode() -> void:
	assert_eq(GameMode.resolve(_args(["--classic"]), _args([]), SliceMode), CLASSIC)
	assert_eq(GameMode.resolve(_args(["--sandbox"]), _args([])), SANDBOX)
	assert_eq(GameMode.resolve(_args(["--slice"]), _args([])), SliceMode)


func test_each_feature_tag_picks_its_mode() -> void:
	assert_eq(GameMode.resolve(_args([]), _args(["sandbox"])), SANDBOX)
	assert_eq(GameMode.resolve(_args([]), _args(["slice"])), SliceMode)


func test_a_command_line_word_beats_a_feature_tag() -> void:
	assert_eq(GameMode.resolve(_args(["--classic"]), _args(["slice"])), CLASSIC, "--classic on a slice build opens the shelved game")
	assert_eq(GameMode.resolve(_args(["--classic"]), _args(["sandbox"])), CLASSIC)
	assert_eq(GameMode.resolve(_args(["--sandbox"]), _args(["slice"])), SANDBOX)
	assert_eq(GameMode.resolve(_args(["--slice"]), _args(["sandbox"])), SliceMode)


func test_rooms_data_per_mode() -> void:
	assert_eq(GameMode.rooms_id(CLASSIC), "world/rooms")
	assert_eq(GameMode.rooms_id(SliceMode), "slice/rooms")
	assert_eq(GameMode.rooms_id(SANDBOX), "", "the sandbox has no rooms")
	assert_false(GameMode.uses_router(SANDBOX))
	assert_true(GameMode.uses_router(SliceMode))
	assert_true(GameMode.uses_router(CLASSIC))


func test_save_folders_never_mix() -> void:
	assert_eq(GameMode.save_dir(CLASSIC), "user://saves", "the shelved game keeps its folder")
	assert_eq(GameMode.save_dir(SliceMode), "user://slice_saves")
	assert_eq(GameMode.save_dir(SANDBOX), "user://feel", "the sandbox keeps its feel files where they are")
	var seen: Dictionary = {}
	for mode: GameMode.Mode in [CLASSIC, SliceMode, SANDBOX]:
		var dir: String = GameMode.save_dir(mode)
		assert_false(seen.has(dir), "two modes share %s" % dir)
		seen[dir] = true
	assert_false(GameMode.save_dir(SliceMode).begins_with(GameMode.SAVE_DIR_CLASSIC), "slice saves are not inside user://saves")


func test_names_round_trip() -> void:
	for mode: GameMode.Mode in [CLASSIC, SliceMode, SANDBOX]:
		assert_eq(GameMode.from_name(GameMode.mode_name(mode), CLASSIC), mode)
	assert_eq(GameMode.from_name("  Slice "), SliceMode)
	assert_eq(GameMode.from_name("nonsense", SANDBOX), SANDBOX, "unknown names use the fallback")
	assert_eq(GameMode.from_name("", SliceMode), SliceMode)


func test_the_real_slice_rooms_id_matches_the_data_files() -> void:
	# The slice rooms file is the Level Designer's; the id only has to be the one GameMode names.
	assert_eq(GameMode.ROOMS_ID_SLICE, "slice/rooms")
	assert_true(DataDB.has_json("slice/slice"), "data/slice/slice.json exists")
	assert_eq(GameMode.from_name(str(DataDB.get_value("slice/slice", "default_mode", ""))), CLASSIC, "the default stays classic until the slice has rooms")


func test_a_normal_run_is_classic() -> void:
	assert_eq(Main.current_mode(), CLASSIC)
	assert_false(Main.wants_sandbox())


func test_router_and_save_manager_take_their_data_from_the_mode() -> void:
	var router: Node = own(load("res://scripts/core/scene_router.gd").new()) as Node
	assert_eq(router.get("rooms_id"), "world/rooms", "a fresh router reads the old rooms file")
	assert_true(router.call("has_room", "test_room") or router.call("room_ids").size() > 0)
	router.set("rooms_id", "slice/rooms")
	assert_eq(router.call("data"), DataDB.get_dict("slice/rooms"), "after the mode is applied it reads the slice file")
	var manager: Node = own(load("res://scripts/core/save_manager.gd").new()) as Node
	assert_eq(manager.get("save_dir"), "user://saves", "a fresh save manager keeps the old folder")
	assert_eq(manager.get("rooms_data_id"), "world/rooms")


func test_main_applies_a_mode_to_the_autoloads_and_back() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.sandbox_boot_enabled = false
	add_to_root(main)
	var router: Node = tree.root.get_node("SceneRouter")
	var manager: Node = tree.root.get_node("SaveManager")
	var state: Node = tree.root.get_node("GameState")
	assert_eq(main.get_mode(), CLASSIC, "a Main with mode boot off is the classic game")
	main.apply_mode(SliceMode)
	assert_eq(main.get_mode(), SliceMode)
	assert_eq(router.get("rooms_id"), "slice/rooms")
	assert_eq(manager.get("save_dir"), "user://slice_saves")
	assert_eq(manager.get("rooms_data_id"), "slice/rooms")
	assert_eq(state.get("rooms_data_id"), "slice/rooms")
	main.apply_mode(CLASSIC)
	assert_eq(router.get("rooms_id"), "world/rooms", "classic puts everything back")
	assert_eq(manager.get("save_dir"), "user://saves")
	assert_eq(manager.get("rooms_data_id"), "world/rooms")
	assert_eq(state.get("rooms_data_id"), "world/rooms")


func test_a_slice_new_game_starts_where_slice_json_says_until_the_rooms_file_names_one() -> void:
	var state: Node = own(load("res://scripts/core/game_state.gd").new()) as Node
	state.call("start_new_game")
	var classic_room: String = str((state.call("get_location") as Dictionary).get("room", ""))
	assert_ne(classic_room, "", "classic has a start room")
	state.set("rooms_data_id", "slice/rooms")
	state.call("start_new_game")
	var slice_room: String = str((state.call("get_location") as Dictionary).get("room", ""))
	var expect: String = str(DataDB.get_value("slice/rooms", "start_room", DataDB.get_value("slice/slice", "new_game.room", "")))
	assert_eq(slice_room, expect)
	assert_ne(slice_room, classic_room, "a slice New Game never starts in the old game's room")
