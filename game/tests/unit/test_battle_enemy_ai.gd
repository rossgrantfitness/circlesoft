extends TestCase
## M2-5: enemy AI picks from a weighted list of actions with conditions; targets come from the
## conditions too. Grunts flee at flee_at_hp_pct (the fight-level flee is in the controller tests).


func _data() -> BattleData:
	return BattleData.load_from(tree.root.get_node("DataDB"))


func _party(count: int = 3) -> BattleState:
	var state: BattleState = BattleState.new()
	var ids: Array[String] = ["red", "otis", "mox"]
	for i: int in count:
		var c: BattleCombatant = BattleCombatant.new()
		c.id = ids[i]
		c.side = BattleCombatant.SIDE_PARTY
		c.slot = i
		c.hp_max = 50
		c.hp = 50
		state.add(c)
	return state


func _foe(data: BattleData, state: BattleState, enemy_id: String, id: String = "e1") -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.new()
	c.id = id
	c.side = BattleCombatant.SIDE_ENEMY
	c.enemy_data = data.enemy(enemy_id)
	c.hp_max = int(c.enemy_data["stats"]["hp"])
	c.hp = c.hp_max
	state.add(c)
	return c


func _rng(seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _tally(data: BattleData, enemy: BattleCombatant, state: BattleState, runs: int, round_number: int = 1) -> Dictionary:
	var counts: Dictionary = {}
	var rng: RandomNumberGenerator = _rng(11)
	for i: int in runs:
		var choice: Dictionary = BattleEnemyAI.choose(data, enemy, state, round_number, rng)
		var key: String = str(choice.get("skill_id", "none"))
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func test_every_pick_is_one_of_the_enemys_own_skills_aimed_at_the_party() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	var rng: RandomNumberGenerator = _rng(3)
	for i: int in 60:
		var choice: Dictionary = BattleEnemyAI.choose(data, grunt, state, 1, rng)
		assert_has(["grunt_bonk", "grunt_write_ticket"], choice["skill_id"])
		assert_eq((choice["targets"] as Array).size(), 1)
		assert_has(["red", "otis", "mox"], (choice["targets"] as Array)[0])


func test_weights_shape_how_often_each_action_is_picked() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	var counts: Dictionary = _tally(data, grunt, state, 2000)
	var bonk: float = float(counts["grunt_bonk"])
	var ticket: float = float(counts["grunt_write_ticket"])
	assert_almost_eq(bonk / ticket, 3.0, 0.5, "weights 3 : 1")


func test_target_lacks_status_condition_filters_targets() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	state.get_c("red").statuses["noise_ticket"] = 2
	state.get_c("otis").statuses["noise_ticket"] = 2
	var rng: RandomNumberGenerator = _rng(5)
	var wrote_ticket: int = 0
	for i: int in 300:
		var choice: Dictionary = BattleEnemyAI.choose(data, grunt, state, 1, rng)
		if choice["skill_id"] == "grunt_write_ticket":
			wrote_ticket += 1
			assert_eq((choice["targets"] as Array)[0], "mox", "only the one without a ticket can get one")
	assert_gt(float(wrote_ticket), 0.0)


func test_the_action_is_off_the_table_when_every_target_already_has_the_status() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	for c: BattleCombatant in state.side_members(BattleCombatant.SIDE_PARTY):
		c.statuses["noise_ticket"] = 3
	var counts: Dictionary = _tally(data, grunt, state, 200)
	assert_false(counts.has("grunt_write_ticket"))
	assert_eq(int(counts["grunt_bonk"]), 200)


func test_self_hp_condition_unlocks_the_dive_bomb_when_hurt() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var drone: BattleCombatant = _foe(data, state, "signals_drone")
	drone.hp_max = 100
	drone.hp = 100
	assert_false(_tally(data, drone, state, 300).has("drone_dive"), "healthy drones do not dive")
	drone.hp = 50
	assert_true(_tally(data, drone, state, 300).has("drone_dive"), "a hurt drone dives")
	drone.hp = 60
	assert_false(_tally(data, drone, state, 300).has("drone_dive"), "the limit is below 60%, not at it")


func test_round_and_ally_count_conditions() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	grunt.enemy_data = grunt.enemy_data.duplicate(true)
	grunt.enemy_data["ai"] = [
		{"skill": "grunt_bonk", "weight": 1, "if": {"round_at_most": 1}},
		{"skill": "grunt_write_ticket", "weight": 1, "if": {"round_at_least": 3, "allies_alive_at_most": 1}},
	]
	assert_eq(_tally(data, grunt, state, 50, 1), {"grunt_bonk": 50})
	assert_eq(_tally(data, grunt, state, 50, 2), {"none": 50}, "nothing allowed in round 2")
	assert_eq(_tally(data, grunt, state, 50, 3), {"grunt_write_ticket": 50}, "alone from round 3")
	var friend: BattleCombatant = _foe(data, state, "signals_grunt", "e2")
	assert_eq(_tally(data, grunt, state, 50, 3), {"none": 50}, "with a friend alive the late action is off")
	friend.down = true
	assert_eq(_tally(data, grunt, state, 50, 3), {"grunt_write_ticket": 50})


func test_target_hp_condition_and_lowest_hp_pick() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	state.get_c("mox").hp = 10
	state.get_c("otis").hp = 30
	grunt.enemy_data = grunt.enemy_data.duplicate(true)
	grunt.enemy_data["ai"] = [{"skill": "grunt_bonk", "weight": 1, "pick": "lowest_hp"}]
	var rng: RandomNumberGenerator = _rng(2)
	for i: int in 20:
		assert_eq((BattleEnemyAI.choose(data, grunt, state, 1, rng)["targets"] as Array)[0], "mox")
	grunt.enemy_data["ai"] = [{"skill": "grunt_bonk", "weight": 1, "if": {"target_hp_below_pct": 40}}]
	for i: int in 20:
		assert_eq((BattleEnemyAI.choose(data, grunt, state, 1, rng)["targets"] as Array)[0], "mox", "only Mox is under 40%")


func test_downed_party_members_are_never_targeted() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	state.get_c("red").down = true
	state.get_c("otis").down = true
	var rng: RandomNumberGenerator = _rng(9)
	for i: int in 30:
		assert_eq((BattleEnemyAI.choose(data, grunt, state, 1, rng)["targets"] as Array)[0], "mox")


func test_no_choice_when_the_party_is_gone() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var grunt: BattleCombatant = _foe(data, state, "signals_grunt")
	for c: BattleCombatant in state.side_members(BattleCombatant.SIDE_PARTY):
		c.down = true
	assert_eq(BattleEnemyAI.choose(data, grunt, state, 1, _rng(1)), {})


func test_same_seed_same_choices() -> void:
	var data: BattleData = _data()
	var state: BattleState = _party()
	var drone: BattleCombatant = _foe(data, state, "signals_drone")
	var a: Array = []
	var b: Array = []
	var rng_a: RandomNumberGenerator = _rng(21)
	var rng_b: RandomNumberGenerator = _rng(21)
	for i: int in 25:
		a.append(BattleEnemyAI.choose(data, drone, state, 1, rng_a))
		b.append(BattleEnemyAI.choose(data, drone, state, 1, rng_b))
	assert_eq(a, b)
