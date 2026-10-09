extends TestCase
## ComboSelector (docs/pivot/kh_combo_design.md): one attack button, and the situation decides the move.
## Every rule in data/combat/combo.json has a test below; the last test fails if a rule is added without one.

var _covered: Dictionary = {}


func _selector() -> ComboSelector:
	return ComboSelector.from_data(CombatData.combo())


## A situation with sensible defaults: Red on the ground, no live string, one launchable target 2 m away.
func _sit(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"from": &"idle", "player_airborne": false, "target_exists": true, "target_dist_m": 2.0,
			"target_airborne": false, "target_launchable": true, "target_guarding": false, "enemies_near": 1,
			"string_pos": 0, "last_hit_connected": false}
	base.merge(overrides, true)
	return base


func _expect(rule_id: String, move: StringName, overrides: Dictionary, prefix: StringName = &"", restart: bool = false) -> void:
	var pick: Dictionary = _selector().select(_sit(overrides))
	assert_eq(pick["rule"], StringName(rule_id), "rule for %s" % overrides)
	assert_eq(pick["move"], move, "move for rule %s" % rule_id)
	assert_eq(pick["prefix"], prefix, "prefix for rule %s" % rule_id)
	assert_eq(pick["restart"], restart, "restart for rule %s" % rule_id)
	_covered[rule_id] = true


# ---- from idle ----

func test_air_start_pressing_in_the_air_starts_the_air_string() -> void:
	_expect("air_start", &"air_1", {"player_airborne": true}, &"", true)


func test_air_start_beats_everything_else_while_airborne() -> void:
	# A far target and an airborne target do not matter when Red herself is in the air.
	_expect("air_start", &"air_1", {"player_airborne": true, "target_dist_m": 8.0, "target_airborne": true}, &"", true)


func test_rise_to_juggle_an_airborne_target_close_by_makes_red_jump_up_after_it() -> void:
	_expect("rise_to_juggle", &"air_1", {"target_airborne": true, "target_dist_m": 2.0}, &"follow_jump", true)


func test_rise_to_juggle_needs_the_target_within_3_5_m() -> void:
	var pick: Dictionary = _selector().select(_sit({"target_airborne": true, "target_dist_m": 3.6}))
	assert_ne(pick["rule"], &"rise_to_juggle")
	assert_eq(_selector().select(_sit({"target_airborne": true, "target_dist_m": 3.5}))["rule"], &"rise_to_juggle", "3.5 m is still in")


func test_lunge_far_a_target_beyond_4_5_m_gets_a_lunge() -> void:
	_expect("lunge_far", &"lunge", {"target_dist_m": 8.0}, &"", true)


func test_lunge_far_the_distance_band_is_4_5_to_12_m_inclusive() -> void:
	assert_eq(_selector().select(_sit({"target_dist_m": 4.5}))["rule"], &"lunge_far", "4.5 m lunges")
	assert_eq(_selector().select(_sit({"target_dist_m": 12.0}))["rule"], &"lunge_far", "12 m lunges")
	assert_eq(_selector().select(_sit({"target_dist_m": 4.49}))["rule"], &"ground_start", "4.49 m is a normal swing")
	assert_eq(_selector().select(_sit({"target_dist_m": 12.01}))["rule"], &"ground_start", "past 12 m there is nothing to lunge at")


func test_lunge_far_needs_a_target() -> void:
	var pick: Dictionary = _selector().select(_sit({"target_exists": false, "target_dist_m": 8.0}))
	assert_eq(pick["rule"], &"ground_start", "a stale distance without a target is ignored")


func test_ground_start_is_light_1() -> void:
	_expect("ground_start", &"light_1", {}, &"", true)


func test_ground_start_works_with_no_target_at_all() -> void:
	_expect("ground_start", &"light_1", {"target_exists": false, "target_dist_m": INF, "enemies_near": 0}, &"", true)


# ---- the ground string ----

func test_l1_to_l2() -> void:
	_expect("l1_to_l2", &"light_2", {"from": &"light_1", "string_pos": 1})


func test_lunge_to_l2_a_lunge_counts_as_hit_1() -> void:
	_expect("lunge_to_l2", &"light_2", {"from": &"lunge", "string_pos": 1})


func test_l2_to_l3_in_a_short_string() -> void:
	_expect("l2_to_l3", &"light_3", {"from": &"light_2", "string_pos": 2})


func test_l2_long_finisher_the_fifth_hit_is_the_heavy_slam() -> void:
	_expect("l2_long_finisher", &"heavy", {"from": &"light_2", "string_pos": 5})


func test_l2_long_finisher_starts_at_hit_5_not_4() -> void:
	assert_eq(_selector().select(_sit({"from": &"light_2", "string_pos": 4}))["rule"], &"l2_to_l3")
	assert_eq(_selector().select(_sit({"from": &"light_2", "string_pos": 5}))["rule"], &"l2_long_finisher")


func test_l3_launcher_is_the_default_finisher() -> void:
	_expect("l3_launcher", &"launcher", {"from": &"light_3", "string_pos": 3})


func test_l3_launcher_with_no_target_still_launches() -> void:
	# No target must not read as "a target that cannot be launched".
	_expect("l3_launcher", &"launcher", {"from": &"light_3", "string_pos": 3, "target_exists": false, "target_dist_m": INF, "enemies_near": 0})


func test_l3_crowd_three_enemies_near_gets_the_sweep() -> void:
	_expect("l3_crowd", &"sweep", {"from": &"light_3", "string_pos": 3, "enemies_near": 3})


func test_l3_crowd_two_enemies_is_not_a_crowd() -> void:
	assert_eq(_selector().select(_sit({"from": &"light_3", "string_pos": 3, "enemies_near": 2}))["rule"], &"l3_launcher")


func test_l3_crowd_wins_over_a_guarding_target() -> void:
	_expect("l3_crowd", &"sweep", {"from": &"light_3", "string_pos": 3, "enemies_near": 4, "target_guarding": true})


func test_l3_extend_vs_guard_a_guarding_target_keeps_the_string_going() -> void:
	_expect("l3_extend_vs_guard", &"light_1", {"from": &"light_3", "string_pos": 3, "target_guarding": true})


func test_l3_extend_vs_heavy_target_something_that_cannot_launch_gets_the_long_string() -> void:
	_expect("l3_extend_vs_heavy_target", &"light_1", {"from": &"light_3", "string_pos": 3, "target_launchable": false})


# ---- finishers ----

func test_launcher_follow_a_connected_launcher_with_the_target_up_follows_it_into_the_air() -> void:
	_expect("launcher_follow", &"air_1", {"from": &"launcher", "string_pos": 4, "last_hit_connected": true, "target_airborne": true}, &"follow_jump")


func test_launcher_follow_needs_the_hit_and_the_target_in_the_air() -> void:
	var no_hit: Dictionary = _selector().select(_sit({"from": &"launcher", "string_pos": 4, "last_hit_connected": false, "target_airborne": true}))
	assert_eq(no_hit["rule"], &"launcher_whiff")
	var on_ground: Dictionary = _selector().select(_sit({"from": &"launcher", "string_pos": 4, "last_hit_connected": true, "target_airborne": false}))
	assert_eq(on_ground["rule"], &"launcher_whiff", "the target got away or landed")


func test_launcher_whiff_starts_a_new_string() -> void:
	_expect("launcher_whiff", &"light_1", {"from": &"launcher", "string_pos": 4}, &"", true)


func test_heavy_restart() -> void:
	_expect("heavy_restart", &"light_1", {"from": &"heavy", "string_pos": 6}, &"", true)


func test_sweep_restart() -> void:
	_expect("sweep_restart", &"light_1", {"from": &"sweep", "string_pos": 4}, &"", true)


# ---- the air string ----

func test_air_1_to_2() -> void:
	_expect("air_1_to_2", &"air_2", {"from": &"air_1", "player_airborne": true, "string_pos": 5})


func test_air_2_to_3() -> void:
	_expect("air_2_to_3", &"air_3", {"from": &"air_2", "player_airborne": true, "string_pos": 6})


func test_air_3_end_the_next_press_starts_fresh() -> void:
	# air_3 ends the string ("next": ""): airborne, the press starts a new air string; on the ground, a new ground string.
	var in_air: Dictionary = _selector().select(_sit({"from": &"air_3", "player_airborne": true, "string_pos": 7}))
	assert_eq(in_air["move"], &"air_1")
	assert_true(in_air["restart"])
	var landed: Dictionary = _selector().select(_sit({"from": &"air_3", "player_airborne": false, "string_pos": 7}))
	assert_eq(landed["move"], &"light_1")
	assert_true(landed["restart"])
	_covered["air_3_end"] = true


# ---- the edges ----

func test_a_move_with_no_rule_falls_back_to_a_fresh_string() -> void:
	var pick: Dictionary = _selector().select(_sit({"from": &"parry"}))
	assert_eq(pick["move"], &"light_1")
	assert_true(pick["restart"])


func test_unknown_condition_keys_fail_the_rule_instead_of_matching_everything() -> void:
	var doc: Dictionary = {"rules": [
		{"id": "typo", "from": "idle", "when": {"targt_airborne": true}, "next": "light_2"},
		{"id": "ok", "from": "idle", "next": "light_1"}]}
	var pick: Dictionary = ComboSelector.from_data(doc).select({"from": &"idle"})
	assert_eq(pick["rule"], &"ok")


func test_the_first_rule_that_fits_wins() -> void:
	var doc: Dictionary = {"rules": [
		{"id": "a", "from": "idle", "when": {"enemies_near_min": 2}, "next": "sweep"},
		{"id": "b", "from": "idle", "next": "light_1"}]}
	var selector: ComboSelector = ComboSelector.from_data(doc)
	assert_eq(selector.select({"from": &"idle", "enemies_near": 2})["rule"], &"a")
	assert_eq(selector.select({"from": &"idle", "enemies_near": 1})["rule"], &"b")


func test_no_rules_means_nothing_starts() -> void:
	var pick: Dictionary = ComboSelector.from_data({}).select({"from": &"idle"})
	assert_eq(pick["move"], &"")


func test_finishers_come_from_the_data() -> void:
	var selector: ComboSelector = _selector()
	for id: StringName in [&"launcher", &"heavy", &"sweep", &"air_3"]:
		assert_true(selector.is_finisher(id), String(id))
	assert_false(selector.is_finisher(&"light_3"))


func test_every_move_a_rule_names_exists_for_red() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for rule: Dictionary in CombatData.combo().get("rules", []):
		var next_id: String = str(rule.get("next", ""))
		if next_id != "":
			assert_true(moves.has_move(&"red", StringName(next_id)), "%s -> %s" % [rule.get("id"), next_id])


# ---- the string shapes the design promises, walked with a ComboString ----

## Presses the button `count` times, feeding each pick back in the way ActionPlayer does. `world` is the situation.
func _walk(world: Dictionary, count: int) -> Array[StringName]:
	var selector: ComboSelector = _selector()
	var string: ComboString = ComboString.create(500.0)
	var out: Array[StringName] = []
	var now: int = 0
	for i: int in count:
		var sit: Dictionary = world.duplicate()
		sit["from"] = string.from_move(now, true)
		sit["string_pos"] = string.pos() if sit["from"] != &"idle" else 0
		sit["last_hit_connected"] = true
		var pick: Dictionary = selector.select(sit)
		if pick["move"] == &"":
			break
		if pick["prefix"] == &"follow_jump":
			world = world.duplicate()
			world["player_airborne"] = true         # the follow-jump put her in the air
		string.begin(pick["move"], bool(pick["restart"]))
		out.append(pick["move"])
		if pick["move"] == &"launcher":
			world["target_airborne"] = true          # the launcher sent it up
		now += 400000
	return out


func test_shape_normal_ground_string_ends_in_the_launcher_and_the_air_string() -> void:
	var moves: Array[StringName] = _walk(_sit(), 7)
	assert_eq(moves, [&"light_1", &"light_2", &"light_3", &"launcher", &"air_1", &"air_2", &"air_3"])


func test_shape_guarding_target_gets_five_lights_and_the_heavy_slam() -> void:
	var moves: Array[StringName] = _walk(_sit({"target_guarding": true, "target_launchable": false}), 6)
	assert_eq(moves, [&"light_1", &"light_2", &"light_3", &"light_1", &"light_2", &"heavy"])


func test_shape_after_the_slam_the_string_starts_over() -> void:
	var moves: Array[StringName] = _walk(_sit({"target_guarding": true, "target_launchable": false}), 8)
	assert_eq(moves.slice(6), [&"light_1", &"light_2"], "and the count restarted: the slam does not come at once")


func test_shape_crowd_ends_in_the_sweep() -> void:
	var moves: Array[StringName] = _walk(_sit({"enemies_near": 3}), 4)
	assert_eq(moves, [&"light_1", &"light_2", &"light_3", &"sweep"])


func test_shape_far_target_opens_with_the_lunge() -> void:
	var world: Dictionary = _sit({"target_dist_m": 8.0})
	var selector: ComboSelector = _selector()
	var string: ComboString = ComboString.create(500.0)
	var first: Dictionary = selector.select(_sit(world))
	assert_eq(first["move"], &"lunge")
	string.begin(first["move"], first["restart"])
	# After the lunge she has closed in.
	var rest: Array[StringName] = []
	var now: int = 400000
	world["target_dist_m"] = 1.5
	for i: int in 3:
		var sit: Dictionary = world.duplicate()
		sit["from"] = string.from_move(now, true)
		sit["string_pos"] = string.pos()
		sit["last_hit_connected"] = true
		var pick: Dictionary = selector.select(sit)
		string.begin(pick["move"], pick["restart"])
		rest.append(pick["move"])
		now += 400000
	assert_eq(rest, [&"light_2", &"light_3", &"launcher"], "lunge, light 2, light 3, launcher")


func test_shape_a_launcher_that_whiffs_goes_back_to_light_1() -> void:
	var selector: ComboSelector = _selector()
	var pick: Dictionary = selector.select(_sit({"from": &"launcher", "string_pos": 4, "last_hit_connected": false}))
	assert_eq(pick["move"], &"light_1")


# ---- coverage ----

func test_every_rule_in_the_data_has_a_test() -> void:
	# The other tests fill _covered when they run; run them here too so this one passes on its own.
	test_air_start_pressing_in_the_air_starts_the_air_string()
	test_rise_to_juggle_an_airborne_target_close_by_makes_red_jump_up_after_it()
	test_lunge_far_a_target_beyond_4_5_m_gets_a_lunge()
	test_ground_start_is_light_1()
	test_l1_to_l2()
	test_lunge_to_l2_a_lunge_counts_as_hit_1()
	test_l2_long_finisher_the_fifth_hit_is_the_heavy_slam()
	test_l2_to_l3_in_a_short_string()
	test_l3_crowd_three_enemies_near_gets_the_sweep()
	test_l3_extend_vs_guard_a_guarding_target_keeps_the_string_going()
	test_l3_extend_vs_heavy_target_something_that_cannot_launch_gets_the_long_string()
	test_l3_launcher_is_the_default_finisher()
	test_launcher_follow_a_connected_launcher_with_the_target_up_follows_it_into_the_air()
	test_launcher_whiff_starts_a_new_string()
	test_heavy_restart()
	test_sweep_restart()
	test_air_1_to_2()
	test_air_2_to_3()
	test_air_3_end_the_next_press_starts_fresh()
	for rule: Dictionary in CombatData.combo().get("rules", []):
		assert_true(_covered.has(str(rule.get("id", ""))), "rule %s has a test" % rule.get("id"))
