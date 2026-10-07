extends TestCase
## GameState's starting numbers and the party order: one source for HP and Juice (the growth table
## plus the starting gear, through StatCalc), and set_party_order() for the Party page.

const SCRIPT_PATH: String = "res://scripts/core/game_state.gd"
const STATS: Array[String] = ["hp", "juice"]


func _make() -> Node:
	var state: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


# ---- one source for the starting numbers ----

func test_party_json_carries_no_hp_or_juice() -> void:
	var members: Dictionary = DataDB.get_dict("party/party")["members"]
	for id: String in members:
		for key: String in ["hp", "hp_max", "juice", "juice_max"]:
			assert_false((members[id] as Dictionary).has(key), "%s has no %s in party.json" % [id, key])


func test_everyone_starts_at_full_with_the_numbers_stat_calc_gives() -> void:
	var state: Node = _make()
	for id: String in state.call("get_party_ids"):
		var member: Dictionary = state.call("get_member", id)
		var total: Dictionary = StatCalc.stats(id, state)
		assert_eq(int(member["hp_max"]), int(total["hp"]), "%s max HP matches StatCalc" % id)
		assert_eq(int(member["juice_max"]), int(total["juice"]), "%s max Juice matches StatCalc" % id)
		assert_eq(int(member["hp"]), int(member["hp_max"]), "%s starts at full HP" % id)
		assert_eq(int(member["juice"]), int(member["juice_max"]), "%s starts at full Juice" % id)


func test_the_numbers_come_from_the_growth_table() -> void:
	var state: Node = _make()
	var data: BattleData = BattleData.shared()
	var red: Dictionary = state.call("get_member", "red")
	var row: Dictionary = StatCalc.stats_for(data, "red", int(red["level"]))
	assert_ge(int(red["hp_max"]), int(row["hp"]), "growth HP plus any gear")
	assert_eq(int(red["hp_max"]), int(StatCalc.stats("red", state)["hp"]))
	assert_gt(int(red["hp_max"]), 42, "no longer the old placeholder 42")


func test_reset_goes_back_to_the_synced_start() -> void:
	var state: Node = _make()
	var start: Dictionary = state.call("get_member", "otis")
	state.call("update_member", "otis", {"hp": 1, "juice": 0, "level": 9, "hp_max": 500})
	state.call("reset")
	assert_eq(state.call("get_member", "otis"), start)


func test_the_real_autoload_agrees_with_stat_calc_too() -> void:
	var state: Node = tree.root.get_node("GameState")
	state.call("reset")
	for id: String in state.call("get_party_ids"):
		assert_eq(int(state.call("get_member", id)["hp_max"]), int(StatCalc.stats(id)["hp"]), id)


func test_a_member_with_no_growth_table_is_left_alone() -> void:
	var state: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", {"default_party": ["ghost"], "members": {"ghost": {"name": "Ghost", "level": 2, "hp": 7, "hp_max": 9, "juice": 1, "juice_max": 2}}})
	state.call("reset")
	assert_eq(int(state.call("get_member", "ghost")["hp_max"]), 9)
	assert_eq(int(state.call("get_member", "ghost")["hp"]), 7)


# ---- the party order ----

func test_set_party_order_reorders_the_party() -> void:
	var state: Node = _make()
	assert_true(state.call("set_party_order", ["red", "mox", "otis"] as Array[String]))
	assert_eq(state.call("get_party_ids"), ["red", "mox", "otis"] as Array[String])
	assert_eq(state.call("get_party")[1]["id"], "mox")
	assert_true(state.call("set_party_order", ["red", "mox", "otis"] as Array[String]), "the same order again is fine")


func test_set_party_order_refuses_a_different_set() -> void:
	var state: Node = _make()
	for bad: Array[String] in [
			["red", "otis"] as Array[String],
			["red", "otis", "mox", "red"] as Array[String],
			["red", "otis", "nobody"] as Array[String],
			["red", "otis", "otis"] as Array[String],
			[] as Array[String]]:
		assert_false(state.call("set_party_order", bad), str(bad))
	assert_eq(state.call("get_party_ids"), ["red", "otis", "mox"] as Array[String], "a refusal changes nothing")


func test_red_stays_the_leader() -> void:
	var state: Node = _make()
	assert_false(state.call("set_party_order", ["otis", "red", "mox"] as Array[String]))
	assert_false(state.call("set_party_order", ["mox", "otis", "red"] as Array[String]))
	assert_eq(state.call("get_party_ids")[0], "red")


func test_the_order_is_saved_and_loaded() -> void:
	var state: Node = _make()
	state.call("set_party_order", ["red", "mox", "otis"] as Array[String])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.call("to_dict")))
	assert_eq(saved["party"], ["red", "mox", "otis"])
	var other: Node = _make()
	other.call("from_dict", saved)
	assert_eq(other.call("get_party_ids"), ["red", "mox", "otis"] as Array[String])
	other.call("reset")
	assert_eq(other.call("get_party_ids"), ["red", "otis", "mox"] as Array[String], "a new game starts in the default order")


func test_the_ui_fixture_subclass_still_works_beside_the_real_method() -> void:
	var fixture: Node = own((load("res://tests/fixtures/ui/state_with_order.gd") as GDScript).new() as Node) as Node
	fixture.call("load_party", DataDB.get_dict("party/party"))
	fixture.call("reset")
	assert_true(fixture.has_method("set_party_order"))
	assert_true(fixture.call("set_party_order", ["red", "mox", "otis"] as Array[String]))
