extends TestCase
## M2-6: XP, credits and drops (rolled with Luck) for a win, and white-flag enemies paying out.


func _data() -> BattleData:
	return BattleData.load_from(tree.root.get_node("DataDB"))


func _enemy(data: BattleData, enemy_id: String, down: bool, fled: bool = false) -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.new()
	c.id = enemy_id
	c.side = BattleCombatant.SIDE_ENEMY
	c.enemy_data = data.enemy(enemy_id)
	c.down = down
	c.fled = fled
	return c


func _rng(seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_totals_are_the_sum_of_the_enemies() -> void:
	var data: BattleData = _data()
	var foes: Array[BattleCombatant] = [_enemy(data, "signals_grunt", true), _enemy(data, "signals_drone", true), _enemy(data, "whistle_blower", true)]
	var rewards: Dictionary = BattleRewards.compute(data, foes, 0.0, _rng(1))
	assert_eq(int(rewards["xp"]), int(data.enemy("signals_grunt")["xp"]) + int(data.enemy("signals_drone")["xp"]) + int(data.enemy("whistle_blower")["xp"]))
	assert_eq(int(rewards["credits"]), int(data.enemy("signals_grunt")["credits"]) + int(data.enemy("signals_drone")["credits"]) + int(data.enemy("whistle_blower")["credits"]))


func test_enemies_still_standing_pay_nothing() -> void:
	var data: BattleData = _data()
	var foes: Array[BattleCombatant] = [_enemy(data, "signals_grunt", true), _enemy(data, "signals_drone", false)]
	var rewards: Dictionary = BattleRewards.compute(data, foes, 0.0, _rng(1))
	assert_eq(int(rewards["xp"]), int(data.enemy("signals_grunt")["xp"]))


func test_a_white_flag_pays_xp_and_credits_but_drops_nothing() -> void:
	var data: BattleData = _data()
	data.enemy("signals_grunt")["drops"] = [{"item": "ration_bar", "chance": 1.0}]
	var flag: Array[BattleCombatant] = [_enemy(data, "signals_grunt", false, true)]
	var rewards: Dictionary = BattleRewards.compute(data, flag, 0.0, _rng(1))
	assert_eq(int(rewards["xp"]), int(data.enemy("signals_grunt")["xp"]), "it surrendered, so you still get the XP")
	assert_eq(int(rewards["credits"]), int(data.enemy("signals_grunt")["credits"]))
	assert_eq((rewards["drops"] as Array).size(), 0, "it ran off with its loot")
	var beaten: Array[BattleCombatant] = [_enemy(data, "signals_grunt", true)]
	assert_eq((BattleRewards.compute(data, beaten, 0.0, _rng(1))["drops"] as Array).size(), 1, "a beaten one drops it")


func test_flee_payouts_are_data() -> void:
	var data: BattleData = _data()
	(data.formulas["rewards"] as Dictionary)["flee"] = {"xp": 0.5, "credits": 0.0, "drops": 0.0}
	var flag: Array[BattleCombatant] = [_enemy(data, "signals_grunt", false, true)]
	var rewards: Dictionary = BattleRewards.compute(data, flag, 0.0, _rng(1))
	assert_eq(int(rewards["xp"]), int(round(float(data.enemy("signals_grunt")["xp"]) * 0.5)))
	assert_eq(int(rewards["credits"]), 0)


func test_drop_chance_rises_with_luck_and_is_capped() -> void:
	var data: BattleData = _data()
	var base: float = 0.2
	assert_almost_eq(BattleRewards.drop_chance(data, base, 0.0), base)
	assert_gt(BattleRewards.drop_chance(data, base, 10.0), BattleRewards.drop_chance(data, base, 2.0))
	assert_le(BattleRewards.drop_chance(data, 0.9, 500.0), data.f("drops", "max_chance", 1.0))


func test_luck_gives_more_drops_over_many_rolls() -> void:
	var data: BattleData = _data()
	data.enemy("signals_grunt")["drops"] = [{"item": "ration_bar", "chance": 0.2}]
	var low: int = 0
	var high: int = 0
	var rng_low: RandomNumberGenerator = _rng(7)
	var rng_high: RandomNumberGenerator = _rng(7)
	for i: int in 400:
		var foes: Array[BattleCombatant] = [_enemy(data, "signals_grunt", true)]
		for drop: Dictionary in BattleRewards.compute(data, foes, 0.0, rng_low)["drops"]:
			low += int(drop["count"])
		for drop: Dictionary in BattleRewards.compute(data, foes, 12.0, rng_high)["drops"]:
			high += int(drop["count"])
	assert_gt(float(high), float(low), "more Luck, more drops (same dice)")


func test_drops_are_deterministic_for_a_seed_and_counted_per_item() -> void:
	var data: BattleData = _data()
	data.enemy("signals_grunt")["drops"] = [{"item": "ration_bar", "chance": 1.0}]
	var foes: Array[BattleCombatant] = [_enemy(data, "signals_grunt", true), _enemy(data, "signals_grunt", true), _enemy(data, "signals_grunt", true)]
	var a: Dictionary = BattleRewards.compute(data, foes, 0.0, _rng(5))
	var b: Dictionary = BattleRewards.compute(data, foes, 0.0, _rng(5))
	assert_eq(a, b)
	assert_eq(a["drops"], [{"item": "ration_bar", "count": 3}] as Array[Dictionary])
