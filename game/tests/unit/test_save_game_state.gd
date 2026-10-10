extends TestCase
## GameState for the save system (M3-9): play time, location, story beat, opened ids, gear, hero
## name, resting, the save round trip and the version migrations (older saves still load).

const SCRIPT_PATH: String = "res://scripts/core/game_state.gd"
const FIXTURES: String = "res://tests/fixtures/saves/"


func _make() -> Node:
	var state: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


func _fixture(file_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + file_name))
	assert_true(parsed is Dictionary, "%s parses" % file_name)
	return parsed if parsed is Dictionary else {}


## What a save file would hold: the dictionary after a trip through JSON text.
func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data, "", false)) as Dictionary


func _played_state() -> Node:
	var state: Node = _make()
	state.call("add_item", "canned_coffee", 4)
	state.call("set_flag", "otis_met")
	state.call("add_credits", 275)
	state.call("tick_play_time", 3725.5)
	state.call("set_location", "tower_floor_2", "lamp")
	state.call("set_story_beat", "tower_climb")
	state.call("mark_opened", "crate_dock_1")
	state.call("mark_opened", "pickup_card_a")
	state.call("set_hero_name", "Dot")
	state.call("update_member", "red", {"level": 5, "xp": 410, "hp": 40, "hp_max": 52, "juice": 9, "juice_max": 15, "skills": ["porch_light"], "bonus": {"hp": 2}})
	state.call("set_equipment", "red", "weapon", "scrap_sword")
	state.call("set_equipment", "mox", "charm", "lucky_lamp")
	return state


# ---- the new pieces ----

func test_new_game_place_comes_from_data() -> void:
	var state: Node = _make()
	var start: Dictionary = DataDB.get_dict("world/save")["new_game"]
	var start_room: String = str(DataDB.get_value("world/rooms", "start_room", start["room"]))
	assert_eq(state.call("get_location")["room"], start_room, "a new game starts in the router's start room")
	assert_false(str(state.call("get_location")["spawn"]).is_empty())
	assert_eq(state.call("get_story_beat"), start["story_beat"])
	assert_eq(state.call("get_play_time_s"), 0.0)
	assert_eq(state.call("get_hero_name"), "Red")


func test_play_time_only_ticks_when_told_to() -> void:
	var state: Node = _make()
	state.call("tick_play_time", 1.5)
	state.call("tick_play_time", -3.0)
	state.call("tick_play_time", 0.25)
	assert_almost_eq(float(state.call("get_play_time_s")), 1.75)
	assert_false(bool(state.get("playing")), "off until Main turns it on")


func test_location_and_story_beat() -> void:
	var state: Node = _make()
	state.call("set_location", "harrow_red_home", "window")
	state.call("set_story_beat", "lamp_check_done")
	assert_eq(state.call("get_location"), {"room": "harrow_red_home", "spawn": "window"})
	assert_eq(state.call("get_story_beat"), "lamp_check_done")
	var copy: Dictionary = state.call("get_location")
	copy["room"] = "changed"
	assert_eq(state.call("get_location")["room"], "harrow_red_home", "get_location hands out a copy")


func test_opened_ids() -> void:
	var state: Node = _make()
	assert_false(state.call("is_opened", "crate_a"))
	state.call("mark_opened", "crate_a")
	state.call("mark_opened", "crate_a")
	state.call("mark_opened", "")
	assert_true(state.call("is_opened", "crate_a"))
	assert_false(state.call("is_opened", "crate_b"))
	assert_eq(state.call("get_opened_ids"), ["crate_a"] as Array[String])


func test_equipment_has_three_slots_and_rejects_nonsense() -> void:
	var state: Node = _make()
	var start: Dictionary = state.call("get_equipment", "red")
	assert_eq(start.keys(), ["weapon", "armor", "charm"], "always all three slots")
	var otis_before: Dictionary = state.call("get_equipment", "otis")
	assert_true(state.call("set_equipment", "red", "armor", "work_vest"))
	assert_eq(state.call("get_equipment", "red")["armor"], "work_vest")
	assert_eq(state.call("get_equipment", "red")["weapon"], start["weapon"], "the other slots stay")
	assert_false(state.call("set_equipment", "red", "hat", "x"), "unknown slot")
	assert_false(state.call("set_equipment", "nobody", "weapon", "x"), "unknown member")
	assert_eq(state.call("get_equipment", "nobody"), {"weapon": "", "armor": "", "charm": ""})
	assert_eq(state.call("get_equipment", "otis"), otis_before, "other members are untouched")


func test_rest_party_fills_hp_and_juice() -> void:
	var state: Node = _make()
	state.call("update_member", "red", {"hp": 3, "juice": 0})
	state.call("rest_party")
	for member: Dictionary in state.call("get_party"):
		assert_eq(int(member["hp"]), int(member["hp_max"]), str(member["id"]))
		assert_eq(int(member["juice"]), int(member["juice_max"]), str(member["id"]))


func test_hero_name_is_trimmed_and_never_blank() -> void:
	var state: Node = _make()
	state.call("set_hero_name", "  Dot  ")
	assert_eq(state.call("get_hero_name"), "Dot")
	assert_eq(state.call("get_member", "red")["name"], "Dot")
	state.call("set_hero_name", "   ")
	assert_eq(state.call("get_hero_name"), "Red")


func test_reset_clears_everything_new_too() -> void:
	var state: Node = _played_state()
	state.call("set_equipment", "red", "armor", "test_only_vest")
	state.call("reset")
	assert_eq(state.call("get_play_time_s"), 0.0)
	assert_false(state.call("is_opened", "crate_dock_1"))
	assert_eq(state.call("get_hero_name"), "Red")
	assert_ne(state.call("get_equipment", "red")["armor"], "test_only_vest", "gear is back to the starting gear")
	assert_eq(int(state.call("get_member", "red")["level"]), int(DataDB.get_dict("party/party")["members"]["red"]["level"]))


# ---- the round trip ----

func test_save_round_trip_is_identical() -> void:
	var state: Node = _played_state()
	var saved: Dictionary = _through_json(state.call("to_dict"))
	var other: Node = _make()
	other.call("from_dict", saved)
	assert_eq(_through_json(other.call("to_dict")), saved, "to_dict after loading equals what was loaded")
	assert_almost_eq(float(other.call("get_play_time_s")), 3725.5)
	assert_eq(other.call("get_location"), {"room": "tower_floor_2", "spawn": "lamp"})
	assert_eq(other.call("get_story_beat"), "tower_climb")
	assert_true(other.call("is_opened", "pickup_card_a"))
	assert_eq(other.call("get_equipment", "red")["weapon"], "scrap_sword")
	assert_eq(other.call("get_equipment", "otis"), state.call("get_equipment", "otis"))
	assert_eq(other.call("get_equipment", "mox")["charm"], "lucky_lamp")
	assert_eq(other.call("get_hero_name"), "Dot")
	assert_eq(int(other.call("get_member", "red")["level"]), 5)
	assert_eq(other.call("get_member", "red")["skills"], ["porch_light"])
	assert_eq(other.call("item_count", "canned_coffee"), 4)
	assert_eq(other.call("get_credits"), 275)
	assert_eq(other.call("get_item_ids"), state.call("get_item_ids"), "the bag keeps its order")


func test_loading_replaces_the_current_run_instead_of_mixing() -> void:
	var saved: Dictionary = _through_json(_played_state().call("to_dict"))
	var other: Node = _make()
	other.call("add_item", "juice_box", 9)
	other.call("set_flag", "only_in_the_other_run")
	other.call("mark_opened", "stale_crate")
	other.call("update_member", "otis", {"level": 9})
	other.call("from_dict", saved)
	assert_false(other.call("has_item", "juice_box"))
	assert_false(other.call("get_flag", "only_in_the_other_run"))
	assert_false(other.call("is_opened", "stale_crate"))
	assert_eq(int(other.call("get_member", "otis")["level"]), int(DataDB.get_dict("party/party")["members"]["otis"]["level"]))


func test_stat_fields_come_back_as_ints() -> void:
	var saved: Dictionary = _through_json(_played_state().call("to_dict"))
	var other: Node = _make()
	other.call("from_dict", saved)
	var red: Dictionary = other.call("get_member", "red")
	for key: String in ["level", "xp", "hp", "hp_max", "juice", "juice_max"]:
		assert_eq(typeof(red[key]), TYPE_INT, key)


func test_to_dict_carries_the_current_version() -> void:
	var state: Node = _make()
	assert_eq(int(state.call("to_dict")["save_version"]), int(state.call("save_version")))
	assert_ge(int(state.call("save_version")), 2)


# ---- older saves ----

func test_the_unversioned_pre_save_system_format_still_loads() -> void:
	var state: Node = _make()
	var old: Dictionary = _fixture("legacy_v1_unversioned.json")
	assert_false(old.has("save_version"), "the fixture is the old format")
	state.call("from_dict", old)
	assert_eq(state.call("item_count", "canned_coffee"), 4)
	assert_true(state.call("get_flag", "defeated_grunt"))
	assert_eq(state.call("get_credits"), 120)
	assert_eq(int(state.call("get_member", "red")["level"]), 4)
	assert_eq(int(state.call("get_member", "red")["hp"]), 33)
	assert_eq(state.call("get_party_ids"), ["red", "otis", "mox"] as Array[String])
	var start_room: String = str(DataDB.get_value("world/rooms", "start_room", DataDB.get_dict("world/save")["new_game"]["room"]))
	assert_eq(state.call("get_location")["room"], start_room, "old saves start at the new-game place")
	assert_eq(state.call("get_play_time_s"), 0.0)
	assert_eq(state.call("get_hero_name"), "Red")
	assert_eq(int(state.call("to_dict")["save_version"]), int(state.call("save_version")), "re-saving writes the new version")


func test_the_smallest_old_save_still_loads() -> void:
	var state: Node = _make()
	state.call("add_credits", 50)
	state.call("from_dict", _fixture("legacy_v1_minimal.json"))
	assert_eq(state.call("item_count", "ration_bar"), 2)
	assert_eq(state.call("get_credits"), 0, "missing credits load as zero")
	assert_eq(state.call("item_count", "camp_stove"), 0, "the saved bag is the bag, not the starting one")


func test_a_version_2_save_loads_exactly() -> void:
	var state: Node = _make()
	var golden: Dictionary = _fixture("v2_golden.json")
	state.call("from_dict", golden)
	var expected: Dictionary = golden.duplicate(true)
	expected["save_version"] = state.call("save_version")        # re-saving writes the current version; every other key survives
	_assert_contains(_through_json(state.call("to_dict")), expected, "the golden v2 file survives load then save")
	assert_eq(state.call("get_party_ids"), ["red", "mox"] as Array[String])
	assert_almost_eq(float(state.call("get_play_time_s")), 3725.5)


func test_migrate_does_not_touch_its_argument() -> void:
	var state: Node = _make()
	var old: Dictionary = _fixture("legacy_v1_unversioned.json")
	var before: String = JSON.stringify(old)
	var upgraded: Dictionary = state.call("migrate", old)
	assert_eq(JSON.stringify(old), before)
	assert_true(upgraded.has("location"))
	assert_true(upgraded.has("opened"))
	assert_eq(int(upgraded["save_version"]), int(state.call("save_version")))


## Every key in `expected` is in `actual` with the same value (recursively). Extra keys in `actual`
## are fine: the starting gear in party.json may grow.
func _assert_contains(actual: Variant, expected: Variant, path: String) -> void:
	if expected is Dictionary and actual is Dictionary:
		for key: Variant in (expected as Dictionary):
			if not (actual as Dictionary).has(key):
				fail("%s: missing '%s'" % [path, key])
			else:
				_assert_contains((actual as Dictionary)[key], (expected as Dictionary)[key], "%s.%s" % [path, key])
	else:
		assert_eq(actual, expected, path)


# ---- Retry ----

func test_restore_snapshot_goes_back_but_play_time_keeps_running() -> void:
	var state: Node = _played_state()
	var snapshot: Dictionary = state.call("snapshot")
	state.call("add_item", "juice_box", 3)
	state.call("set_flag", "during_the_fight")
	state.call("mark_opened", "crate_in_the_fight")
	state.call("add_credits", 99)
	state.call("update_member", "red", {"hp": 1})
	state.call("set_location", "elsewhere", "x")
	state.call("tick_play_time", 120.0)
	state.call("restore_snapshot", snapshot)
	assert_false(state.call("has_item", "juice_box"))
	assert_false(state.call("get_flag", "during_the_fight"))
	assert_false(state.call("is_opened", "crate_in_the_fight"))
	assert_eq(state.call("get_credits"), 275)
	assert_eq(int(state.call("get_member", "red")["hp"]), 40)
	assert_eq(state.call("get_location")["room"], "tower_floor_2")
	assert_almost_eq(float(state.call("get_play_time_s")), 3845.5, 0.001, "the 120 s spent in the fight still count")
