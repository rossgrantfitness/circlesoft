extends TestCase
## GameState: the bag (add / remove / count / cap), flags, the party from data, and the save round trip.

const SCRIPT_PATH: String = "res://scripts/core/game_state.gd"


func _make() -> Node:
	var state: Node = own((load(SCRIPT_PATH) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


func test_starting_bag_comes_from_data() -> void:
	var state: Node = _make()
	var starting: Dictionary = DataDB.get_dict("party/party")["starting_items"]
	for id: String in starting:
		assert_eq(state.call("item_count", id), int(starting[id]), id)


func test_add_remove_and_count() -> void:
	var state: Node = _make()
	assert_eq(state.call("item_count", "canned_coffee"), 0)
	assert_eq(state.call("add_item", "canned_coffee", 2), 2)
	assert_eq(state.call("item_count", "canned_coffee"), 2)
	assert_true(state.call("has_item", "canned_coffee"))
	assert_true(state.call("remove_item", "canned_coffee", 1))
	assert_eq(state.call("item_count", "canned_coffee"), 1)
	assert_false(state.call("remove_item", "canned_coffee", 5), "cannot remove more than you have")
	assert_eq(state.call("item_count", "canned_coffee"), 1, "a failed remove changes nothing")
	assert_true(state.call("remove_item", "canned_coffee", 1))
	assert_false(state.call("has_item", "canned_coffee"))
	assert_does_not_have(state.call("get_item_ids"), "canned_coffee")


func test_stack_cap_is_99() -> void:
	var state: Node = _make()
	state.call("add_item", "juice_box", 98)
	assert_eq(state.call("add_item", "juice_box", 5), 1, "only one more fits")
	assert_eq(state.call("item_count", "juice_box"), 99)


func test_bad_item_calls_do_nothing() -> void:
	var state: Node = _make()
	assert_eq(state.call("add_item", "", 1), 0)
	assert_eq(state.call("add_item", "x", 0), 0)
	assert_false(state.call("remove_item", "x", 0))


func test_item_changed_signal() -> void:
	var state: Node = _make()
	var seen: Array = []
	state.connect("item_changed", func(id: String, count: int) -> void: seen.append([id, count]))
	state.call("add_item", "juice_box", 3)
	state.call("remove_item", "juice_box", 1)
	assert_eq(seen, [["juice_box", 3], ["juice_box", 2]])


func test_flags() -> void:
	var state: Node = _make()
	assert_false(state.call("get_flag", "zero_gift"))
	var seen: Array = []
	state.connect("flag_changed", func(id: String, value: bool) -> void: seen.append([id, value]))
	state.call("set_flag", "zero_gift")
	state.call("set_flag", "zero_gift")
	assert_true(state.call("get_flag", "zero_gift"))
	state.call("clear_flag", "zero_gift")
	assert_false(state.call("get_flag", "zero_gift"))
	assert_eq(seen, [["zero_gift", true], ["zero_gift", false]], "signal only on a real change")


func test_party_loads_red_otis_mox_in_order() -> void:
	var state: Node = _make()
	var party: Array = state.call("get_party")
	assert_eq(party.size(), 3)
	assert_eq(party[0]["id"], "red")
	assert_eq(party[1]["name"], "Otis")
	assert_eq(party[2]["id"], "mox")
	for member: Dictionary in party:
		assert_ge(int(member["hp_max"]), int(member["hp"]))
		assert_ge(int(member["level"]), 1)


func test_party_copies_cannot_change_the_state() -> void:
	var state: Node = _make()
	var red: Dictionary = state.call("get_member", "red")
	red["hp"] = 1
	assert_ne(int(state.call("get_member", "red")["hp"]), 1)
	assert_eq(state.call("get_member", "nobody"), {})


func test_item_info_names_and_fallback() -> void:
	var state: Node = _make()
	var info: Dictionary = state.call("get_item_info", "ration_bar")
	assert_eq(info["name"], "Ration Bar")
	assert_false(str(info["desc"]).is_empty())
	assert_eq(state.call("get_item_info", "mystery_goo")["name"], "Mystery Goo", "unknown ids get a tidied name")


func test_save_round_trip() -> void:
	var state: Node = _make()
	state.call("add_item", "canned_coffee", 4)
	state.call("set_flag", "prize_crate_taken")
	var saved: Dictionary = state.call("to_dict")
	var other: Node = _make()
	other.call("from_dict", JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.call("item_count", "canned_coffee"), 4)
	assert_true(other.call("get_flag", "prize_crate_taken"))
	assert_eq(other.call("item_count", "ration_bar"), state.call("item_count", "ration_bar"))


func test_reset_returns_to_the_starting_bag() -> void:
	var state: Node = _make()
	state.call("add_item", "canned_coffee", 4)
	state.call("set_flag", "x")
	state.call("reset")
	assert_eq(state.call("item_count", "canned_coffee"), 0)
	assert_false(state.call("get_flag", "x"))
