extends TestCase
## The enemy AI's data (enemy_ai_design): every enemy attack meets the telegraph rules, every move the brain starts
## has the fields the body uses, and the numbers in enemies.json are inside their sensible ranges.

const ATTACK_KEYS: Array[String] = ["startup_ms", "active_ms", "recovery_ms", "impact_ms"]


func _enemies() -> Dictionary:
	return CombatData.enemies()


func _rules() -> Dictionary:
	return _enemies().get("telegraph_rules", {})


func test_the_rule_blocks_exist() -> void:
	var tokens: Dictionary = _enemies().get("token_rules", {})
	assert_almost_eq(float(tokens.get("min_impact_gap_ms", 0.0)), 450.0)
	assert_eq(int(tokens.get("max_rear_attackers", 0)), 1)
	assert_almost_eq(float(tokens.get("rear_arc_deg", 0.0)), 120.0)
	assert_gt(float(tokens.get("flanker_queue_bonus_ms", 0.0)), 0.0)
	assert_almost_eq(float(_rules().get("min_windup_ms", 0.0)), 500.0)
	assert_almost_eq(float(_rules().get("rear_min_windup_ms", 0.0)), 650.0)
	assert_almost_eq(float(_rules().get("min_aim_lock_before_impact_ms", 0.0)), 150.0)


## Every move an enemy's brain can start as an attack: the data's `attacks` list, the flank move, the rear move and
## the cornered move.
func _attack_ids(enemy: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry: Variant in enemy.get("attacks", []):
		var id: String = str((entry as Dictionary)["move"])
		if not ids.has(id):
			ids.append(id)
	var beh: Dictionary = enemy.get("behaviour", {})
	var low: Dictionary = beh.get("low_health", {})
	for id: String in [str(beh.get("rear_move", "")), str((low.get("flank", {}) as Dictionary).get("move", "")), str((low.get("flee", {}) as Dictionary).get("cornered_move", ""))]:
		if id != "" and not ids.has(id):
			ids.append(id)
	return ids


func test_every_enemy_attack_has_the_minimum_windup() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for enemy_id: String in (_enemies().get("enemies", {}) as Dictionary).keys():
		var enemy: Dictionary = _enemies()["enemies"][enemy_id]
		var ids: Array[String] = _attack_ids(enemy)
		assert_gt(float(ids.size()), 0.0, enemy_id)
		for id: String in ids:
			var move: Dictionary = moves.get_move(StringName(str(enemy.get("move_set", enemy_id))), StringName(id))
			assert_false(move.is_empty(), "%s.%s exists" % [enemy_id, id])
			assert_true(EnemyRules.windup_ok(move, _rules(), false), "%s.%s: %.0f ms from telegraph to impact" % [enemy_id, id, EnemyRules.windup_ms(move)])


func test_attacks_from_behind_have_the_longer_windup() -> void:
	var moves: MoveSet = MoveSet.load_default()
	var grunt: Dictionary = _enemies()["enemies"]["grunt"]
	var rear: String = str(grunt["behaviour"].get("rear_move", ""))
	assert_ne(rear, "", "the Grunt has a move for attacking from behind")
	assert_true(EnemyRules.windup_ok(moves.get_move(&"grunt", StringName(rear)), _rules(), true), "swipe_flank is 710 ms")
	assert_eq(str(grunt["behaviour"]["low_health"]["flank"]["move"]), rear)
	var brute_slam: Dictionary = moves.get_move(&"brute", &"slam")
	assert_true(EnemyRules.windup_ok(brute_slam, _rules(), true), "the slam (900 ms) is long enough from behind too")


func test_the_aim_locks_early_enough_in_every_attack() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for enemy_id: String in (_enemies().get("enemies", {}) as Dictionary).keys():
		var enemy: Dictionary = _enemies()["enemies"][enemy_id]
		var set_id: StringName = StringName(str(enemy.get("move_set", enemy_id)))
		for entry: Variant in enemy.get("attacks", []):
			var attack: Dictionary = entry
			var move: Dictionary = moves.get_move(set_id, StringName(str(attack["move"])))
			var locks_at: float = EnemyRules.aim_lock_ms(float(attack["track_ms"]), float(move["impact_ms"]), _rules())
			assert_le(locks_at, float(move["impact_ms"]) - 150.0 + 0.001, "%s.%s locks at %.0f of %.0f" % [enemy_id, attack["move"], locks_at, move["impact_ms"]])
			assert_almost_eq(locks_at, float(attack["track_ms"]), 0.001, "%s.%s: the data already respects the rule" % [enemy_id, attack["move"]])
		var flank: Dictionary = (enemy.get("behaviour", {}) as Dictionary).get("low_health", {}).get("flank", {})
		if not flank.is_empty():
			var flank_move: Dictionary = moves.get_move(set_id, StringName(str(flank["move"])))
			assert_le(float(flank["track_ms"]), float(flank_move["impact_ms"]) - 150.0, "the flank swipe locks early too")


func test_the_reaction_moves_the_body_uses_are_in_moves_json() -> void:
	var moves: MoveSet = MoveSet.load_default()
	var grunt_needs: Array[String] = ["dodge", "getup_roll", "block_start", "block_hold", "block_break", "strafe", "retreat", "flee", "swipe_flank"]
	for id: String in grunt_needs:
		assert_true(moves.has_move(&"grunt", StringName(id)), "grunt." + id)
	for id: String in ["block_start", "block_hold", "block_break", "strafe", "retreat", "enrage"]:
		assert_true(moves.has_move(&"brute", StringName(id)), "brute." + id)
	var dodge: Dictionary = moves.get_move(&"grunt", &"dodge")
	var frames: Dictionary = dodge["iframes"]
	assert_ge(float(frames["from_ms"]), 0.0)
	assert_le(float(frames["to_ms"]), float(dodge["total_ms"]), "the i-frames sit inside the move")
	assert_almost_eq(float(frames["to_ms"]) - float(frames["from_ms"]), 220.0, 0.001, "220 ms of invulnerability")
	assert_gt(float(dodge["motion"]["travel_m"]), 2.0)
	for set_id: String in ["grunt", "brute"]:
		var start: Dictionary = moves.get_move(StringName(set_id), &"block_start")
		var guard: Dictionary = start["guard"]
		assert_le(float(guard["to_ms"]), float(start["total_ms"]) + 0.001, set_id + ": the guard window sits inside block_start")
		var broke: Dictionary = moves.get_move(StringName(set_id), &"block_break")
		assert_almost_eq(float(broke["total_ms"]), 1100.0 if set_id == "grunt" else 1300.0, 0.001, set_id + ": the guard-break stagger")
		assert_true(broke.has("punish"))
	assert_true(bool(moves.get_move(&"brute", &"enrage").get("armor", {}).has("to_ms")), "super armor through the roar")
	assert_false(bool(moves.get_move(&"brute", &"enrage").get("parryable", true)), "a roar cannot be parried")


func test_reaction_and_locomotion_moves_deal_no_damage() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for set_id: String in ["grunt", "brute"]:
		for id: StringName in moves.move_ids(StringName(set_id)):
			var move: Dictionary = moves.get_move(StringName(set_id), id)
			if str(move.get("kind", "")) in ["reaction", "locomotion"]:
				assert_true((move["hitboxes"] as Array).is_empty(), "%s.%s has no hitbox" % [set_id, id])
				assert_true((move["hit"] as Dictionary).is_empty(), "%s.%s has no hit" % [set_id, id])


func test_the_behaviour_numbers_are_sane() -> void:
	for enemy_id: String in (_enemies().get("enemies", {}) as Dictionary).keys():
		var beh: Dictionary = _enemies()["enemies"][enemy_id].get("behaviour", {})
		assert_false(beh.is_empty(), enemy_id + " has a behaviour block")
		var defend: Dictionary = beh["defend"]
		assert_le(float(defend["dodge_chance"]) + float(defend["block_chance"]), 1.0, enemy_id)
		for weight: float in (defend["read_weight"] as Dictionary).values():
			assert_ge(weight, 0.0)
			assert_le(weight, 1.0)
		var reaction: Array = defend["reaction_ms"]
		assert_le(float(reaction[0]), float(reaction[1]))
		var guard: Dictionary = beh["guard"]
		assert_gt(float(guard["arc_deg"]), 0.0)
		assert_le(float(guard["arc_deg"]), 360.0)
		var hold: Array = guard["hold_ms"]
		assert_le(float(hold[0]), float(hold[1]))
		assert_gt(float(guard["meter"]), float(guard["break_poise"]) * 0.0)
		var repo: Dictionary = beh["reposition"]
		var ring: Array = repo["ring_m"]
		assert_lt(float(ring[0]), float(ring[1]))
		var low: Dictionary = beh["low_health"]
		assert_gt(float(low["threshold_frac"]), 0.0)
		assert_lt(float(low["threshold_frac"]), 1.0)
	var brute_low: Dictionary = _enemies()["enemies"]["brute"]["behaviour"]["low_health"]
	assert_true(bool(brute_low.get("never_flee", false)), "the Brute never flees")
	assert_eq(str(brute_low["mode"]), "enrage")
	assert_eq(str(_enemies()["enemies"]["grunt"]["behaviour"]["low_health"]["mode"]), "flee_or_flank")


func test_a_blocked_hit_never_breaks_a_guard_of_a_light_but_a_heavy_always_does() -> void:
	# design 6: Light 1, 2 poise 8 (3 break the Grunt), Heavy 30 always breaks (break_poise 20 and 30)
	var moves: MoveSet = MoveSet.load_default()
	var heavy: Dictionary = moves.get_move(&"red", &"heavy")["hit"]
	var light: Dictionary = moves.get_move(&"red", &"light_1")["hit"]
	var launcher: Dictionary = moves.get_move(&"red", &"launcher")
	for enemy_id: String in ["grunt", "brute"]:
		var guard: Dictionary = _enemies()["enemies"][enemy_id]["behaviour"]["guard"]
		assert_ge(float(heavy["poise_damage"]), float(guard["break_poise"]), enemy_id + ": a Heavy breaks the guard")
		assert_lt(float(light["poise_damage"]), float(guard["break_poise"]), enemy_id + ": a Light does not")
		assert_true(bool(launcher["launcher"]) and bool(guard["break_by_launcher"]), enemy_id + ": a Launcher breaks it")
