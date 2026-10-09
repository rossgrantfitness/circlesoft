extends TestCase
## VS-16, saving in the slice: the version 2 to 3 migration (sword, hacks, Red's health), auto-save only in the rooms that ask
## for it, and no saving at all in a robot room. The save terminal and the sword/hacks round trip are also covered in
## test_town_systems.gd.

const SCRIPT_PATH: String = "res://scripts/core/game_state.gd"
const FIXTURES: String = "res://tests/fixtures/saves/"
const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _old_dir: String = ""
var _old_auto: bool = false
var _dir: String = ""
var _vault_robots_before: Variant = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_old_dir = str(_manager.get("save_dir"))
	_old_auto = bool(_manager.get("auto_save_enabled"))
	_dir = "user://test_slice_saves_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _vault_robots_before != null:
		(DataDB.get_dict(ROOMS_ID)["rooms"]["gb_vault"] as Dictionary)["robots"] = _vault_robots_before
		_vault_robots_before = null
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_dir)
	_manager.set("auto_save_enabled", _old_auto)
	_manager.set("saving_allowed", true)
	_manager.set("rooms_data_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


func _start() -> ActionRoom:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_router.set("rooms_id", ROOMS_ID)
	_router.set("main", _main)
	_router.set("instant", true)
	_manager.set("rooms_data_id", ROOMS_ID)
	_state.set("rooms_data_id", ROOMS_ID)
	Placements.extra_ids = [PLACEMENTS_ID] as Array[String]
	_manager.set("save_dir", _dir)
	_main.start_new_game()
	return await _until_room("gb_hub")


func _until_room(room_id: String, limit: int = 120) -> ActionRoom:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func _fresh_state() -> Node:
	var state: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


# ---- migration 2 -> 3 ----

func test_a_version_2_save_loads_into_version_3_with_no_sword_and_no_hacks() -> void:
	var state: Node = _fresh_state()
	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "v2_golden.json"))
	assert_eq(int((golden as Dictionary)["save_version"]), 2, "the fixture really is version 2")
	state.call("from_dict", golden)
	assert_eq(state.call("unlocked_hacks"), [] as Array[String])
	assert_eq(state.get("slice_run"), {}, "no sword and no health recorded: Red keeps her default and walks in at full health")
	var again: Dictionary = state.call("to_dict")
	assert_eq(int(again["save_version"]), 3)
	assert_eq(again["sword"], "")
	assert_eq(again["hacks"], [])
	assert_eq(int(again["hero_hp"]), 0)


func test_the_migration_adds_the_new_fields_and_leaves_the_rest() -> void:
	var state: Node = _fresh_state()
	var old: Dictionary = {"save_version": 2, "bag": {"ration_bar": 3}, "credits": 12}
	var upgraded: Dictionary = state.call("migrate", old)
	assert_eq(int(upgraded["save_version"]), 3)
	assert_eq(upgraded["sword"], "")
	assert_eq(upgraded["hacks"], [])
	assert_eq(int(upgraded["hero_hp"]), 0)
	assert_eq(upgraded["credits"], 12)
	assert_eq(old["save_version"], 2, "the argument is not changed")


func test_version_1_saves_walk_the_whole_chain() -> void:
	var state: Node = _fresh_state()
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "legacy_v1_unversioned.json"))
	var upgraded: Dictionary = state.call("migrate", legacy)
	assert_eq(int(upgraded["save_version"]), 3)
	assert_true(upgraded.has("hacks"))
	assert_true(upgraded.has("location"))


func test_hacks_sword_and_health_round_trip_through_a_state() -> void:
	var state: Node = _fresh_state()
	state.call("unlock_hack", "emp")
	state.call("unlock_hack", "zap_drone")
	assert_false(state.call("unlock_hack", "emp"), "twice is not new")
	state.set("slice_run", {"session": {"hp": 55, "sword": "machete", "battery": 12.0}})
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.call("to_dict"))) as Dictionary
	assert_false(saved.has("battery"), "the battery is not saved")
	var other: Node = _fresh_state()
	other.call("from_dict", saved)
	assert_eq(other.call("unlocked_hacks"), ["emp", "zap_drone"] as Array[String])
	var session: Dictionary = (other.get("slice_run") as Dictionary)["session"]
	assert_eq(int(session["hp"]), 55)
	assert_eq(str(session["sword"]), "machete")
	assert_false(session.has("battery"), "she starts a loaded game with the director's battery")


func test_loading_a_save_clears_the_old_runs_checkpoint() -> void:
	var state: Node = _fresh_state()
	state.set("slice_run", {"checkpoint": {"room": "x"}, "session": {"hp": 9}})
	state.call("from_dict", state.call("migrate", {"save_version": 2}))
	assert_eq(state.get("slice_run"), {})


# ---- auto-save rooms ----

func test_auto_save_writes_only_in_rooms_marked_autosave() -> void:
	_manager.set("auto_save_enabled", true)
	var hub: ActionRoom = await _start()          # gb_hub: autosave true
	assert_not_null(hub)
	assert_true(FileAccess.file_exists(_dir + "/auto.json"), "the hub saves on entry")
	var first: Dictionary = _manager.call("read_file", 0)
	assert_eq(first["game"]["location"]["room"], "gb_hub")
	_router.call("go_to", "gb_yard", "from_hub")
	await _until_room("gb_yard")                   # gb_yard: autosave false
	var after_yard: Dictionary = _manager.call("read_file", 0)
	assert_eq(after_yard["game"]["location"]["room"], "gb_hub", "the yard did not overwrite the auto-save")
	_router.call("go_to", "gb_vault", "from_yard")
	await _until_room("gb_vault")                  # gb_vault: autosave true
	var after_vault: Dictionary = _manager.call("read_file", 0)
	assert_eq(after_vault["game"]["location"]["room"], "gb_vault")


func test_the_auto_save_carries_red_s_live_health() -> void:
	_manager.set("auto_save_enabled", true)
	await _start()
	_router.call("go_to", "gb_yard", "from_hub")
	var yard: ActionRoom = await _until_room("gb_yard")
	yard.hero.hp = 44
	_router.call("go_to", "gb_vault", "from_yard")
	await _until_room("gb_vault")
	var saved: Dictionary = _manager.call("read_file", 0)
	assert_eq(int(saved["game"]["hero_hp"]), 44, "she walked into the vault with 44 and the auto-save says so")


# ---- no saving in a robot room ----

func test_a_room_with_robots_turns_saving_off_and_leaving_turns_it_back_on() -> void:
	_vault_robots_before = (DataDB.get_dict(ROOMS_ID)["rooms"]["gb_vault"] as Dictionary).get("robots", "")
	(DataDB.get_dict(ROOMS_ID)["rooms"]["gb_vault"] as Dictionary)["robots"] = "junk_j4"
	await _start()
	assert_true(_manager.call("can_save"), "the hub is a normal room")
	assert_true(_manager.call("save_slot", 1))
	_router.call("go_to", "gb_yard", "from_hub")
	await _until_room("gb_yard")
	_router.call("go_to", "gb_vault", "from_yard")
	var vault: ActionRoom = await _until_room("gb_vault")
	assert_true(vault.saving_blocked())
	assert_false(_manager.call("can_save"))
	assert_false(_manager.call("save_slot", 2), "no manual save")
	assert_false(_manager.call("auto_save"), "no auto-save")
	assert_false(FileAccess.file_exists(_dir + "/slot_2.json"))
	var lamp: SaveLamp = SaveLamp.new()
	lamp.build_placeholder = false
	lamp.save_manager = _manager
	add_to_root(lamp)
	assert_false(lamp.start_check(), "a terminal does not start its check in a robot room")
	_router.call("go_to", "gb_yard", "from_vault")
	await _until_room("gb_yard")
	assert_true(_manager.call("can_save"), "back on foot, saving is back")


func test_a_robot_form_blocks_saving_too() -> void:
	var hub: ActionRoom = await _start()
	assert_false(hub.saving_blocked())
	hub._form = &"small"
	assert_true(hub.saving_blocked(), "walking into a room in the loader")
