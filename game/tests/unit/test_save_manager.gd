extends TestCase
## SaveManager (M3-9): slots, atomic writes, summaries, Continue (newest), and the auto-save,
## which fires on area entry and nowhere else. Every test uses its own folder under user://.

const MANAGER_PATH: String = "res://scripts/core/save_manager.gd"
const STATE_PATH: String = "res://scripts/core/game_state.gd"
const FIXTURES: String = "res://tests/fixtures/saves/"

var _dir: String = ""
var _now: float = 1000.0


func before_each() -> void:
	_dir = "user://test_saves_%d" % Time.get_ticks_usec()
	_now = 1000.0


func after_each() -> void:
	_remove_dir(_dir)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _make_state() -> Node:
	var state: Node = own((load(STATE_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


func _make_manager(state: Node) -> Node:
	var manager: Node = own((load(MANAGER_PATH) as GDScript).new() as Node) as Node
	manager.set("save_dir", _dir)
	manager.set("game_state", state)
	manager.set("clock", func() -> float: return _now)
	return manager


func _files() -> Array[String]:
	var names: Array[String] = []
	if not DirAccess.dir_exists_absolute(_dir):
		return names
	names.assign(Array(DirAccess.get_files_at(_dir)))
	names.sort()
	return names


func _text_of(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ---- saving and loading ----

func test_save_then_load_gives_the_same_game() -> void:
	var state: Node = _make_state()
	state.call("add_item", "canned_coffee", 4)
	state.call("set_flag", "otis_met")
	state.call("tick_play_time", 61.0)
	state.call("set_location", "tower_floor_1", "lamp")
	state.call("mark_opened", "crate_1")
	state.call("set_equipment", "red", "weapon", "scrap_sword")
	var manager: Node = _make_manager(state)
	var before: String = JSON.stringify(state.call("to_dict"))
	assert_true(manager.call("save_slot", 2))
	state.call("reset")
	assert_ne(JSON.stringify(state.call("to_dict")), before, "the state really was wiped")
	assert_true(manager.call("load_slot", 2))
	assert_eq(JSON.stringify(state.call("to_dict")), before, "byte-for-byte the same after the round trip")


func test_slots_are_files_in_the_saves_folder() -> void:
	var manager: Node = _make_manager(_make_state())
	assert_true(manager.call("save_slot", 1))
	assert_true(manager.call("save_slot", 3))
	assert_eq(_files(), ["slot_1.json", "slot_3.json"] as Array[String])
	assert_true(manager.call("auto_save"))
	assert_eq(_files(), ["auto.json", "slot_1.json", "slot_3.json"] as Array[String])
	assert_eq(manager.call("slot_path", 0), _dir + "/auto.json")


func test_the_saves_folder_is_the_custom_user_dir() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/config/use_custom_user_dir")), "true")
	assert_eq(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")), "LightsLeftOn")
	assert_eq(str(load(MANAGER_PATH).get_script_constant_map()["SAVE_DIR"]), "user://saves")


func test_there_are_three_manual_slots_and_the_auto_one_is_not_savable_by_hand() -> void:
	var manager: Node = _make_manager(_make_state())
	assert_eq(manager.call("slot_count"), 3)
	assert_false(manager.call("save_slot", 0), "you can't save over the auto-save by hand")
	assert_false(manager.call("save_slot", 4))
	assert_false(manager.call("save_slot", -1))
	assert_eq(_files(), [] as Array[String])


func test_the_file_is_versioned_json() -> void:
	var manager: Node = _make_manager(_make_state())
	manager.call("save_slot", 1)
	var parsed: Variant = JSON.parse_string(_text_of(_dir + "/slot_1.json"))
	assert_true(parsed is Dictionary)
	var file: Dictionary = parsed
	assert_eq(int(file["file_format"]), 1)
	assert_eq(int(file["slot"]), 1)
	assert_eq(float(file["saved_at"]), 1000.0)
	assert_gt(int(file["game"]["save_version"]), 1)
	assert_true(file.has("summary"))


func test_saved_signal_carries_the_slot() -> void:
	var manager: Node = _make_manager(_make_state())
	var seen: Array[int] = []
	manager.connect("saved", func(slot: int) -> void: seen.append(slot))
	manager.call("save_slot", 2)
	manager.call("auto_save")
	manager.call("save_slot", 9)
	assert_eq(seen, [2, 0] as Array[int])


func test_loading_an_empty_or_unknown_slot_changes_nothing() -> void:
	var state: Node = _make_state()
	state.call("add_credits", 5)
	var manager: Node = _make_manager(state)
	assert_false(manager.call("load_slot", 1))
	assert_false(manager.call("load_slot", 7))
	assert_eq(state.call("get_credits"), 5)


# ---- atomic writes ----

func test_a_leftover_broken_temp_file_never_corrupts_the_slot() -> void:
	var state: Node = _make_state()
	state.call("add_credits", 77)
	var manager: Node = _make_manager(state)
	assert_true(manager.call("save_slot", 1))
	var good: String = _text_of(_dir + "/slot_1.json")
	# A crash in the middle of a write leaves a half-written temp file next to the slot.
	_write(_dir + "/slot_1.json.tmp", '{"file_format": 1, "game": {"bag": {"ration_')
	assert_eq(_text_of(_dir + "/slot_1.json"), good, "the slot itself is untouched")
	state.call("reset")
	assert_true(manager.call("load_slot", 1), "and it still loads")
	assert_eq(state.call("get_credits"), 77)
	assert_eq(manager.call("newest_slot"), 1)
	# The next save simply writes over the leftover.
	state.call("add_credits", 1)
	assert_true(manager.call("save_slot", 1))
	assert_false(FileAccess.file_exists(_dir + "/slot_1.json.tmp"), "the temp file is gone after a good save")
	assert_true(manager.call("load_slot", 1))
	assert_eq(state.call("get_credits"), 78)


func test_a_failed_write_leaves_the_old_slot_exactly_as_it_was() -> void:
	var state: Node = _make_state()
	state.call("add_credits", 10)
	var manager: Node = _make_manager(state)
	assert_true(manager.call("save_slot", 1))
	var good: String = _text_of(_dir + "/slot_1.json")
	# A folder where the temp file should go makes the write fail.
	DirAccess.make_dir_recursive_absolute(_dir + "/slot_1.json.tmp")
	state.call("add_credits", 5)
	assert_false(manager.call("save_slot", 1), "the failure is reported")
	assert_eq(_text_of(_dir + "/slot_1.json"), good, "the slot still holds the old save")
	state.call("reset")
	assert_true(manager.call("load_slot", 1))
	assert_eq(state.call("get_credits"), 10)


func test_write_atomic_replaces_the_target_and_leaves_no_temp() -> void:
	var manager: Node = _make_manager(_make_state())
	var path: String = _dir + "/thing.json"
	assert_true(manager.call("write_atomic", path, "one"))
	assert_true(manager.call("write_atomic", path, "two"))
	assert_eq(_text_of(path), "two")
	assert_eq(_files(), ["thing.json"] as Array[String])


func test_a_corrupt_slot_is_reported_and_skipped() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	manager.call("save_slot", 1)
	_now = 2000.0
	_write(_dir + "/slot_2.json", "{this is not json")
	_now = 3000.0
	assert_eq(manager.call("slot_summary", 2), {"corrupt": true, "slot": 2})
	assert_false(manager.call("load_slot", 2))
	assert_eq(manager.call("newest_slot"), 1, "a broken file is never 'newest'")
	assert_true(manager.call("continue_game"))


func test_a_save_from_a_newer_game_is_refused() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	var future: Dictionary = {"file_format": 1, "slot": 1, "saved_at": 5.0, "game": {"save_version": 999, "bag": {}}}
	_write(_dir + "/slot_1.json", JSON.stringify(future))
	assert_false(manager.call("load_slot", 1))
	assert_eq(manager.call("slot_summary", 1)["corrupt"], true)


# ---- Continue and summaries ----

func test_continue_loads_the_newest_save_manual_or_auto() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	assert_false(manager.call("has_any_save"))
	assert_eq(manager.call("newest_slot"), -1)
	assert_false(manager.call("continue_game"))
	state.call("add_credits", 100)
	manager.call("save_slot", 1)
	_now = 1500.0
	state.call("add_credits", 100)
	manager.call("auto_save")
	assert_true(manager.call("has_any_save"))
	assert_eq(manager.call("newest_slot"), 0, "the auto-save is newer")
	state.call("reset")
	assert_true(manager.call("continue_game"))
	assert_eq(state.call("get_credits"), 200)
	_now = 1600.0
	state.call("add_credits", 50)
	manager.call("save_slot", 3)
	assert_eq(manager.call("newest_slot"), 3, "a newer manual save wins")
	state.call("reset")
	manager.call("continue_game")
	assert_eq(state.call("get_credits"), 250)


func test_slot_summary_has_place_time_party_credits_and_date() -> void:
	var state: Node = _make_state()
	state.call("set_location", "test_room", "lamp")
	state.call("tick_play_time", 3725.0)
	state.call("add_credits", 340)
	state.call("update_member", "red", {"level": 6})
	var manager: Node = _make_manager(state)
	manager.call("save_slot", 2)
	var summary: Dictionary = manager.call("slot_summary", 2)
	assert_eq(summary["place"], "Test Room")
	assert_almost_eq(float(summary["play_time_s"]), 3725.0)
	assert_eq(summary["credits"], 340)
	assert_eq(float(summary["saved_at"]), 1000.0)
	assert_eq(summary["slot"], 2)
	var party: Array = summary["party"]
	assert_eq(party.size(), 3)
	assert_eq(party[0], {"id": "red", "level": 6})
	assert_eq(party[1]["id"], "otis")


func test_empty_slots_have_no_summary() -> void:
	var manager: Node = _make_manager(_make_state())
	assert_eq(manager.call("slot_summary", 1), {})
	assert_eq(manager.call("slot_summary", 0), {})
	assert_eq(manager.call("slot_summary", 8), {})


func test_unknown_rooms_get_a_tidy_place_name() -> void:
	var manager: Node = _make_manager(_make_state())
	assert_eq(manager.call("place_name", "tower_floor_2"), "Tower Floor 2")
	assert_eq(manager.call("place_name", ""), "Somewhere")


func test_an_old_save_file_shows_a_summary_and_loads() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	DirAccess.make_dir_recursive_absolute(_dir)
	_write(_dir + "/slot_2.json", _text_of(FIXTURES + "slot_file_v1_envelope.json"))
	var summary: Dictionary = manager.call("slot_summary", 2)
	assert_eq(summary["credits"], 120)
	assert_eq(summary["party"][0], {"id": "red", "level": 4})
	assert_true(manager.call("load_slot", 2))
	assert_eq(state.call("get_credits"), 120)
	assert_true(state.call("get_flag", "otis_met"))


func test_a_bare_game_state_file_also_loads() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	_write(_dir + "/slot_1.json", _text_of(FIXTURES + "legacy_v1_unversioned.json"))
	assert_true(manager.call("load_slot", 1))
	assert_eq(state.call("get_credits"), 120)


# ---- the auto-save ----

func test_auto_save_fires_on_area_entry_and_nowhere_else() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	var writes: Array[int] = []
	manager.connect("saved", func(slot: int) -> void: writes.append(slot))
	# Everything that happens in a room: items, flags, credits, a fight's results, time passing, hand saves of nothing.
	state.call("add_item", "juice_box", 2)
	state.call("set_flag", "x")
	state.call("add_credits", 10)
	state.call("update_member", "red", {"hp": 5})
	state.call("tick_play_time", 600.0)
	state.call("mark_opened", "crate")
	assert_eq(writes, [] as Array[int], "nothing writes by itself")
	assert_false(FileAccess.file_exists(_dir + "/auto.json"))
	manager.call("notify_room_entered", "tower_floor_1", "stairs")
	assert_eq(writes, [0] as Array[int], "area entry writes the auto-save")
	assert_true(FileAccess.file_exists(_dir + "/auto.json"))
	assert_eq(state.call("get_location"), {"room": "tower_floor_1", "spawn": "stairs"})
	state.call("add_credits", 10)
	assert_eq(writes, [0] as Array[int], "still only the one write")
	manager.call("notify_room_entered", "tower_floor_2", "stairs")
	assert_eq(writes, [0, 0] as Array[int], "the next area writes again")
	state.call("reset")
	manager.call("load_slot", 0)
	assert_eq(state.call("get_location")["room"], "tower_floor_2")
	assert_eq(state.call("get_credits"), 20)


func test_auto_save_waits_out_a_battle() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	manager.set("battle_active", true)
	manager.call("notify_room_entered", "somewhere", "")
	assert_false(FileAccess.file_exists(_dir + "/auto.json"), "never mid-battle")
	assert_false(manager.call("auto_save"))
	manager.set("battle_active", false)
	manager.call("notify_room_entered", "somewhere_else", "")
	assert_true(FileAccess.file_exists(_dir + "/auto.json"))


func test_auto_save_can_be_switched_off() -> void:
	var manager: Node = _make_manager(_make_state())
	manager.set("auto_save_enabled", false)
	manager.call("notify_room_entered", "somewhere", "")
	assert_false(FileAccess.file_exists(_dir + "/auto.json"))


func test_arriving_from_a_load_does_not_write_an_auto_save() -> void:
	var state: Node = _make_state()
	state.call("set_location", "tower_floor_1", "lamp")
	var manager: Node = _make_manager(state)
	manager.call("save_slot", 1)
	manager.call("load_slot", 1)
	manager.call("notify_room_entered", "tower_floor_1", "lamp")
	assert_false(FileAccess.file_exists(_dir + "/auto.json"), "the room a load puts you in is not 'new'")
	manager.call("notify_room_entered", "tower_floor_2", "stairs")
	assert_true(FileAccess.file_exists(_dir + "/auto.json"), "but the next one is")


func test_a_router_signal_drives_the_auto_save() -> void:
	var state: Node = _make_state()
	var manager: Node = _make_manager(state)
	var router: Node = own(FakeRouter.new()) as Node
	manager.call("connect_router", router)
	manager.call("connect_router", router)
	router.emit_signal("room_entered", "harrow_landing")
	assert_true(FileAccess.file_exists(_dir + "/auto.json"))
	assert_eq(state.call("get_location")["room"], "harrow_landing")
	var summary: Dictionary = manager.call("slot_summary", 0)
	assert_eq(summary["place"], "Harrow Landing")


class FakeRouter extends Node:
	signal room_entered(room_id: String)
