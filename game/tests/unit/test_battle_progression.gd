extends TestCase
## M2-6: the XP curve, level-up gains, skills learned at the right level, the bench-XP and
## catch-up rules (built now, off in the data), and writing a finished fight back into GameState.

const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"


func _progression() -> Progression:
	return Progression.new(BattleData.load_from(tree.root.get_node("DataDB")))


func _game_state() -> Node:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	return state


# ---- XP curve and levels ----

func test_xp_thresholds_come_from_the_curve_file() -> void:
	var p: Progression = _progression()
	var rows: Array = tree.root.get_node("DataDB").get_table("party/xp_curve")
	assert_eq(p.max_level(), 6)
	for row: Dictionary in rows:
		assert_eq(p.xp_for_level(int(row["level"])), int(row["total_xp"]))
	assert_eq(p.xp_for_level(1), 0)


func test_level_for_xp_changes_exactly_on_the_threshold() -> void:
	var p: Progression = _progression()
	for level: int in range(2, 7):
		var need: int = p.xp_for_level(level)
		assert_eq(p.level_for_xp(need - 1), level - 1, "one XP short of level %d" % level)
		assert_eq(p.level_for_xp(need), level)
	assert_eq(p.level_for_xp(0), 1)
	assert_eq(p.level_for_xp(999999), 6, "the slice caps at the top of the table")


func test_xp_to_next() -> void:
	var p: Progression = _progression()
	assert_eq(p.xp_to_next(1, 0), p.xp_for_level(2))
	assert_eq(p.xp_to_next(2, p.xp_for_level(2) + 5), p.xp_for_level(3) - p.xp_for_level(2) - 5)
	assert_eq(p.xp_to_next(6, 600), 0, "nothing more at the cap")


# ---- stats and growth ----

func test_stats_come_from_the_growth_table_and_never_drop() -> void:
	var p: Progression = _progression()
	var rows: Array = tree.root.get_node("DataDB").get_table("party/growth")
	for row: Dictionary in rows:
		var stats: Dictionary = p.stats_at(str(row["character"]), int(row["level"]))
		for key: String in BattleData.STAT_KEYS:
			assert_eq(stats[key], int(row[key]), "%s L%s %s" % [row["character"], row["level"], key])
	for char_id: String in ["red", "otis", "mox"]:
		for level: int in range(1, 6):
			var now: Dictionary = p.stats_at(char_id, level)
			var next: Dictionary = p.stats_at(char_id, level + 1)
			for key: String in BattleData.STAT_KEYS:
				assert_ge(int(next[key]), int(now[key]), "%s %s only goes up" % [char_id, key])


func test_each_character_grows_in_their_own_shape() -> void:
	var p: Progression = _progression()
	assert_gt(int(p.stats_at("otis", 6)["hp"]), int(p.stats_at("red", 6)["hp"]), "Otis is the tank")
	assert_gt(int(p.stats_at("red", 6)["speed"]), int(p.stats_at("otis", 6)["speed"]), "Red is the quick one")
	assert_gt(int(p.stats_at("mox", 6)["heart"]), int(p.stats_at("red", 6)["heart"]), "Mox is the gadget wildcard")


func test_flat_bonuses_add_on_top() -> void:
	var p: Progression = _progression()
	var base: Dictionary = p.stats_at("red", 3)
	var boosted: Dictionary = p.stats_at("red", 3, {"attack": 5, "hp": 10})
	assert_eq(int(boosted["attack"]), int(base["attack"]) + 5)
	assert_eq(int(boosted["hp"]), int(base["hp"]) + 10)
	assert_eq(int(boosted["luck"]), int(base["luck"]))


# ---- level-ups ----

func test_apply_xp_reports_gains_and_skips_levels_when_it_should() -> void:
	var p: Progression = _progression()
	var red: Dictionary = p.new_member("red", 1)
	var small: Dictionary = p.apply_xp(red, 10)
	assert_eq(small, {}, "10 XP is not enough for level 2")
	assert_eq(int(red["xp"]), 10)
	var record: Dictionary = p.apply_xp(red, p.xp_for_level(2) - 10)
	assert_eq(record["id"], "red")
	assert_eq(record["from"], 1)
	assert_eq(record["to"], 2)
	var base: Dictionary = p.stats_at("red", 1)
	var up: Dictionary = p.stats_at("red", 2)
	assert_eq(int(record["gains"]["hp"]), int(up["hp"]) - int(base["hp"]))
	assert_eq(int(red["level"]), 2)
	assert_eq(int(red["hp_max"]), int(up["hp"]))
	assert_eq(int(red["hp"]), int(up["hp"]), "a level-up lifts current HP by the gain")
	assert_eq(record["learned"], [] as Array[String])


func test_one_big_win_can_climb_several_levels() -> void:
	var p: Progression = _progression()
	var mox: Dictionary = p.new_member("mox", 1)
	var record: Dictionary = p.apply_xp(mox, p.xp_for_level(4))
	assert_eq(record["from"], 1)
	assert_eq(record["to"], 4)
	assert_eq(record["learned"], ["duct_tape"] as Array[String], "the level 4 skill pops up on the victory screen")
	var total_hp: int = int(p.stats_at("mox", 4)["hp"]) - int(p.stats_at("mox", 1)["hp"])
	assert_eq(int(record["gains"]["hp"]), total_hp, "gains add up across levels")


func test_each_third_skill_is_learned_at_level_four() -> void:
	var p: Progression = _progression()
	var expected: Dictionary = {"red": "sunrise_slash", "otis": "cough_drop", "mox": "duct_tape"}
	for char_id: String in expected:
		assert_eq(p.skills_known(char_id, 1).size(), 2, "%s starts with two skills" % char_id)
		assert_eq(p.skills_known(char_id, 3).size(), 2)
		assert_eq(p.skills_known(char_id, 4).size(), 3)
		assert_eq(p.skills_known(char_id, 4)[2], expected[char_id])
		assert_eq(p.skills_learned_between(char_id, 3, 4), [expected[char_id]] as Array[String])
		assert_eq(p.skills_learned_between(char_id, 1, 3), [] as Array[String])
		assert_eq(p.skills_learned_between(char_id, 4, 6), [] as Array[String], "learned once")


func test_a_down_member_still_earns_full_xp_but_stays_down() -> void:
	var p: Progression = _progression()
	var otis: Dictionary = p.new_member("otis", 1)
	otis["hp"] = 0
	var record: Dictionary = p.apply_xp(otis, p.xp_for_level(2))
	assert_eq(int(otis["level"]), 2, "Down fighters earn full XP")
	assert_eq(record["to"], 2)
	assert_eq(int(otis["hp"]), 0, "leveling does not revive")


func test_no_level_past_the_cap() -> void:
	var p: Progression = _progression()
	var red: Dictionary = p.new_member("red", 6)
	var record: Dictionary = p.apply_xp(red, 5000)
	assert_eq(record, {})
	assert_eq(int(red["level"]), 6)


# ---- bench XP and catch-up (switched off, tested on) ----

func test_bench_xp_is_off_in_the_data() -> void:
	var p: Progression = _progression()
	assert_false(p.bench_xp_enabled())
	assert_false(p.catch_up_enabled())
	var shares: Dictionary = p.xp_shares(["red", "otis", "mox"] as Array[String], ["vela"] as Array[String])
	assert_eq(shares.size(), 3, "the bench earns nothing while the rule is off")
	assert_false(shares.has("vela"))


func test_bench_xp_rule_when_switched_on() -> void:
	var p: Progression = _progression()
	var rules: Dictionary = {"bench_xp": {"enabled": true, "share": 1.0}}
	var shares: Dictionary = p.xp_shares(["red", "otis", "mox"] as Array[String], ["vela", "ruo"] as Array[String], rules)
	assert_eq(shares.size(), 5)
	assert_almost_eq(float(shares["vela"]), 1.0, 0.0001, "the bench earns full XP")
	assert_almost_eq(float(shares["red"]), 1.0, 0.0001)
	var half: Dictionary = p.xp_shares(["red"] as Array[String], ["vela"] as Array[String], {"bench_xp": {"enabled": true, "share": 0.5}})
	assert_almost_eq(float(half["vela"]), 0.5, 0.0001, "the share is data, not code")


func test_catch_up_rule_when_switched_on() -> void:
	var p: Progression = _progression()
	var levels: Array[int] = [5, 4, 6]
	assert_eq(p.catch_up_level(levels), 1, "off: late joiners start at level 1")
	var on: Dictionary = {"catch_up": {"enabled": true, "level_offset": 0}}
	assert_eq(p.catch_up_level(levels, on), 6, "late joiners start at the party's level")
	assert_eq(p.catch_up_level(levels, {"catch_up": {"enabled": true, "level_offset": 2}}), 4)
	var joiner: Dictionary = p.catch_up_member("mox", levels, on)
	assert_eq(int(joiner["level"]), 6)
	assert_eq(int(joiner["xp"]), p.xp_for_level(6))
	assert_eq(joiner["skills"], ["patent_pending", "pocket_sparkler", "duct_tape"] as Array[String], "already knows what they would have learned")
	assert_eq(int(joiner["hp"]), int(p.stats_at("mox", 6)["hp"]))


# ---- GameState write-back ----

func test_game_state_remembers_credits_and_member_changes_through_a_save() -> void:
	var state: Node = _game_state()
	assert_eq(state.call("get_credits"), 0)
	state.call("add_credits", 120)
	state.call("update_member", "red", {"level": 4, "xp": 200, "hp": 33, "juice": 2})
	state.call("update_member", "nobody", {"level": 9})
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.call("to_dict")))
	var other: Node = _game_state()
	other.call("from_dict", saved)
	assert_eq(other.call("get_credits"), 120)
	assert_eq(int(other.call("get_member", "red")["level"]), 4)
	assert_eq(int(other.call("get_member", "red")["xp"]), 200)
	assert_eq(int(other.call("get_member", "red")["hp"]), 33)
	assert_eq(other.call("get_member", "nobody"), {})


func test_old_saves_without_credits_still_load() -> void:
	var state: Node = _game_state()
	state.call("add_credits", 50)
	state.call("from_dict", {"bag": {"ration_bar": 2}, "flags": {}, "party": ["red", "otis", "mox"]})
	assert_eq(state.call("get_credits"), 0, "missing credits load as zero")
	assert_eq(state.call("item_count", "ration_bar"), 2)


func test_battle_results_write_party_bag_and_credits_back() -> void:
	var state: Node = _game_state()
	state.call("add_item", "ration_bar", 3)
	var before: int = state.call("item_count", "ration_bar")
	var outcome: Dictionary = {
		"party": [{"id": "red", "level": 2, "xp": 40, "hp": 30, "hp_max": 46, "juice": 5, "juice_max": 14}],
		"bench": [],
		"items_used": {"ration_bar": 2},
		"report": {"credits": 75, "drops": [{"item": "canned_coffee", "count": 2}]},
	}
	BattleResults.apply(state, outcome)
	var red: Dictionary = state.call("get_member", "red")
	assert_eq(int(red["level"]), 2)
	assert_eq(int(red["xp"]), 40)
	assert_eq(int(red["hp"]), 30)
	assert_eq(int(red["hp_max"]), 46)
	assert_eq(int(red["juice"]), 5)
	assert_eq(state.call("item_count", "ration_bar"), before - 2, "used items come out of the bag")
	assert_eq(state.call("item_count", "canned_coffee"), 2)
	assert_eq(state.call("get_credits"), 75)
