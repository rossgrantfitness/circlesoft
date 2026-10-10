extends TestCase
## BossBrain: which pattern the Hushmaster picks and when. Patterns are chosen only when their conditions fit, never the
## same one twice, the gap between them shrinks as leg pairs fall, the opening is fixed, a jam blocks the drone drop.


func _doc() -> Dictionary:
	return CombatData.read_json(CombatData.DIR + "bosses/hushmaster.json")


func _rig() -> Dictionary:
	return (_doc()["phases"] as Array)[0] as Dictionary


func _brain(rng_seed: int = 1) -> BossBrain:
	return BossBrain.from_data(_rig(), _doc()["rules"] as Dictionary, rng_seed)


## Red 6 m away, nothing lost, nothing special.
## How far the opening leg stomp reaches, from the data.
func _stomp_reach_m() -> float:
	for raw: Variant in _rig()["patterns"] as Array:
		var pattern: Dictionary = raw
		if str(pattern["id"]) == "leg_stomp":
			return float((pattern["when"] as Dictionary)["dist_max_m"])
	return 0.0


func _view(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"dist_m": 6.0, "pairs_lost": 0, "pairs_standing": 4, "parts_alive": {"dish": true},
			"drones_alive": 0, "since_start_s": 10.0, "hacks_locked": false}
	base.merge(overrides, true)
	return base


func _run(brain: BossBrain, now: float, view: Dictionary) -> Dictionary:
	var pick: Dictionary = brain.step(now, view)
	if not pick.is_empty():
		brain.begin(pick["pattern"], now)
	return pick


func test_it_waits_the_first_attack_delay() -> void:
	var brain: BossBrain = _brain()
	assert_true(brain.step(2400.0, _view()).is_empty())
	assert_false(brain.step(2500.0, _view()).is_empty())


func test_the_opening_is_the_ring_then_the_line_then_the_ring() -> void:
	var brain: BossBrain = _brain()
	var seen: Array[StringName] = []
	var now: float = 2500.0
	for i: int in range(3):
		var pick: Dictionary = _run(brain, now, _view())
		seen.append(pick["pattern"])
		brain.finish(now + 3000.0, 0)
		now += 8000.0
	assert_eq(seen, [&"leg_stomp", &"dish_sweep", &"leg_stomp"] as Array[StringName])


func test_an_opening_attack_waits_for_the_boss_to_be_in_range() -> void:
	var brain: BossBrain = _brain()
	var reach: float = _stomp_reach_m()
	assert_gt(reach, 0.0, "the stomp has a reach in the data")
	assert_true(brain.step(2600.0, _view({"dist_m": reach + 4.0})).is_empty(), "the stomp needs Red within its reach: the boss walks closer")
	assert_eq(brain.step(3000.0, _view({"dist_m": reach - 1.0}))["pattern"], &"leg_stomp")


func test_an_opening_attack_that_never_becomes_possible_is_dropped_after_patience() -> void:
	var brain: BossBrain = _brain()
	var far: float = _stomp_reach_m() + 4.0
	assert_true(brain.step(2600.0, _view({"dist_m": far})).is_empty())
	var pick: Dictionary = brain.step(2600.0 + BossBrain.OPENING_PATIENCE_MS + 1.0, _view({"dist_m": far}))
	assert_ne(pick.get("pattern", &""), &"leg_stomp", "it gave up on the stomp and moves on")


func _after_opening(brain: BossBrain) -> float:
	var now: float = 2500.0
	for i: int in range(3):
		_run(brain, now, _view())
		brain.finish(now + 2000.0, 0)
		now += 10000.0
	return now


func test_no_pattern_twice_in_a_row() -> void:
	for rng_seed: int in range(1, 25):
		var brain: BossBrain = _brain(rng_seed)
		var now: float = _after_opening(brain)
		var last: StringName = brain.last_pattern()
		for i: int in range(12):
			var pick: Dictionary = _run(brain, now, _view({"since_start_s": 100.0}))
			if pick.is_empty():
				now += 5000.0
				continue
			assert_ne(pick["pattern"], last, "seed %d, step %d" % [rng_seed, i])
			last = pick["pattern"]
			brain.finish(now + 1000.0, 0)
			now += 6000.0


func test_a_pattern_is_picked_only_when_its_conditions_fit() -> void:
	var brain: BossBrain = _brain()
	var now: float = _after_opening(brain)
	var seen: Dictionary = {}
	for i: int in range(60):
		var pick: Dictionary = _run(brain, now, _view({"dist_m": 3.0, "since_start_s": 10.0, "drones_alive": 3}))
		if not pick.is_empty():
			seen[String(pick["pattern"])] = true
			brain.finish(now + 500.0, 0)
		now += 6000.0
	assert_does_not_have(seen, "dish_sweep", "needs Red 5 m away")
	assert_does_not_have(seen, "drone_drop", "not while drones are up")
	assert_does_not_have(seen, "quiet_hours", "not before 35 s")
	assert_has(seen, "leg_stomp")


func test_a_pattern_whose_needs_do_not_hold_is_never_picked() -> void:
	var brain: BossBrain = _brain()
	var now: float = _after_opening(brain)
	for i: int in range(40):
		var pick: Dictionary = _run(brain, now, _view({"pairs_standing": 0, "parts_alive": {"dish": false}, "dist_m": 7.0}))
		if not pick.is_empty():
			assert_eq(pick["pattern"], &"drone_drop", "no legs, no dish: only the drone drop is left")
			brain.finish(now + 500.0, 0)
		now += 6000.0


func test_quiet_hours_waits_for_35_seconds_then_has_a_cooldown() -> void:
	var brain: BossBrain = _brain()
	var now: float = _after_opening(brain)
	var quiet: int = 0
	var first_at: float = -1.0
	for i: int in range(400):
		var pick: Dictionary = _run(brain, now, _view({"since_start_s": 40.0, "drones_alive": 1, "dist_m": 7.0}))
		if not pick.is_empty():
			brain.finish(now + 300.0, 0)
			if pick["pattern"] == &"quiet_hours":
				quiet += 1
				if first_at < 0.0:
					first_at = now
				else:
					assert_ge(now - first_at, 25000.0, "25 s between two Quiet Hours")
					first_at = now
		now += 2000.0
	assert_gt(float(quiet), 0.0, "it does come")


func test_a_jam_blocks_the_drone_drop() -> void:
	var brain: BossBrain = _brain()
	var now: float = _after_opening(brain)
	for i: int in range(60):
		var pick: Dictionary = _run(brain, now, _view({"hacks_locked": true, "since_start_s": 100.0, "dist_m": 7.0}))
		if not pick.is_empty():
			assert_ne(pick["pattern"], &"drone_drop", "Red cannot EMP while locked, so no drones")
			assert_ne(pick["pattern"], &"quiet_hours", "and no second jam on top")
			brain.finish(now + 500.0, 0)
		now += 6000.0


func test_the_gap_between_patterns_shrinks_as_pairs_fall() -> void:
	var brain: BossBrain = _brain()
	assert_eq(brain.gap_ms(0), 1900.0)
	assert_eq(brain.gap_ms(1), 1700.0)
	assert_eq(brain.gap_ms(2), 1500.0)
	assert_eq(brain.gap_ms(3), 1300.0)
	assert_eq(brain.gap_ms(9), 1300.0, "clamped")


func test_after_a_pattern_the_next_waits_its_gap() -> void:
	var brain: BossBrain = _brain()
	_run(brain, 2500.0, _view())
	brain.finish(5000.0, 0)
	assert_true(brain.step(6800.0, _view()).is_empty(), "1.9 s gap not over")
	assert_false(brain.step(6900.0, _view()).is_empty())


func test_nothing_is_picked_while_a_pattern_runs() -> void:
	var brain: BossBrain = _brain()
	_run(brain, 2500.0, _view())
	assert_true(brain.is_busy())
	assert_true(brain.step(99999.0, _view()).is_empty())


func test_a_reaction_can_hold_the_next_pick() -> void:
	var brain: BossBrain = _brain()
	brain.hold_until(10000.0)
	assert_true(brain.step(9000.0, _view()).is_empty())
	assert_false(brain.step(10000.0, _view()).is_empty())


func test_the_stomp_chains_once_two_pairs_are_down() -> void:
	var brain: BossBrain = _brain()
	var pick: Dictionary = _run(brain, 2500.0, _view({"pairs_lost": 1, "pairs_standing": 3}))
	assert_eq(pick["repeat"], 1)
	var chained: BossBrain = _brain()
	var two: Dictionary = _run(chained, 2500.0, _view({"pairs_lost": 2, "pairs_standing": 2}))
	assert_eq(two["pattern"], &"leg_stomp")
	assert_eq(two["repeat"], 2)
	assert_eq(two["repeat_gap_ms"], 900.0)


func test_a_disabled_pattern_is_gone_for_good() -> void:
	var brain: BossBrain = _brain()
	var now: float = _after_opening(brain)
	brain.disable(&"dish_sweep")
	brain.disable(&"quiet_hours")
	for i: int in range(60):
		var pick: Dictionary = _run(brain, now, _view({"since_start_s": 100.0, "dist_m": 7.0}))
		if not pick.is_empty():
			assert_ne(pick["pattern"], &"dish_sweep")
			assert_ne(pick["pattern"], &"quiet_hours")
			brain.finish(now + 500.0, 0)
		now += 6000.0


func test_a_fresh_start_brings_the_opening_back() -> void:
	var brain: BossBrain = _brain()
	_after_opening(brain)
	assert_true(brain.opening_left().is_empty())
	brain.start(100000.0)
	assert_eq(brain.opening_left().size(), 3)
	assert_true(brain.step(101000.0, _view()).is_empty(), "and the first-attack delay again")


func test_every_pattern_in_the_data_names_a_move_that_exists() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for id: StringName in _brain().pattern_ids():
		var move: StringName = StringName(str(_brain().pattern(id).get("move", "")))
		assert_true(moves.has_move(&"hushmaster", move), "%s -> %s" % [id, move])


func test_the_same_seed_gives_the_same_fight() -> void:
	var a: BossBrain = _brain(7)
	var b: BossBrain = _brain(7)
	var now: float = _after_opening(a)
	_after_opening(b)
	for i: int in range(8):
		var first: Dictionary = _run(a, now, _view({"since_start_s": 100.0, "dist_m": 7.0}))
		var second: Dictionary = _run(b, now, _view({"since_start_s": 100.0, "dist_m": 7.0}))
		assert_eq(first.get("pattern", &""), second.get("pattern", &""))
		a.finish(now + 500.0, 0)
		b.finish(now + 500.0, 0)
		now += 6000.0


# ---- the Heap's brain (junk_mech.json) ----

func _heap_doc() -> Dictionary:
	return CombatData.read_json(CombatData.DIR + "bosses/junk_mech.json")


func _heap(rng_seed: int = 1) -> BossBrain:
	return BossBrain.from_heap(_heap_doc(), rng_seed)


func _heap_view(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"dist_m": 30.0, "stage": "armored", "allowed": ["scrap_swing", "wrecking_drop", "stomp_march", "scrap_barrage"], "bias": {}}
	base.merge(overrides, true)
	return base


func test_the_heap_opens_with_the_swing_then_the_drop() -> void:
	var brain: BossBrain = _heap()
	var first: Dictionary = brain.step(0.0, _heap_view())
	assert_eq(first["pattern"], &"scrap_swing")
	assert_eq(first["moves"], ["scrap_swing_l", "scrap_swing_r"])
	brain.begin(first["pattern"], 0.0)
	brain.finish(5000.0, 0, brain.stage_gap_ms("armored"))
	assert_eq(brain.step(8000.0, _heap_view())["pattern"], &"wrecking_drop")


func test_the_heap_waits_until_red_is_in_swing_range() -> void:
	var brain: BossBrain = _heap()
	assert_true(brain.step(0.0, _heap_view({"dist_m": 45.0})).is_empty(), "the swing needs her within 38 m: it keeps walking")


func test_the_gap_depends_on_the_stage() -> void:
	var brain: BossBrain = _heap()
	assert_eq(brain.stage_gap_ms("armored"), 2600.0)
	assert_eq(brain.stage_gap_ms("core"), 2200.0)
	assert_eq(brain.stage_gap_ms("last_stand"), 1800.0)


func test_the_chains_only_come_in_the_last_stand() -> void:
	var brain: BossBrain = _heap(4)
	var now: float = 0.0
	for stage: String in ["armored", "core"]:
		for i: int in range(40):
			var pick: Dictionary = brain.step(now, _heap_view({"stage": stage, "allowed": ["scrap_swing", "wrecking_drop", "stomp_march", "scrap_barrage", "chain_a", "chain_b"], "dist_m": 32.0}))
			if not pick.is_empty():
				assert_does_not_have(["chain_a", "chain_b"], String(pick["pattern"]), "stage %s" % stage)
				brain.begin(pick["pattern"], now)
				brain.finish(now + 100.0, 0, 0.0)
			now += 3000.0


func test_a_stage_only_uses_its_own_patterns() -> void:
	var brain: BossBrain = _heap(2)
	var now: float = 0.0
	var seen: Dictionary = {}
	for i: int in range(60):
		var pick: Dictionary = brain.step(now, _heap_view({"stage": "last_stand", "allowed": ["chain_a", "chain_b", "scrap_barrage"], "dist_m": 35.0}))
		if not pick.is_empty():
			seen[String(pick["pattern"])] = true
			brain.begin(pick["pattern"], now)
			brain.finish(now + 100.0, 0, 0.0)
		now += 4000.0
	for id: Variant in seen.keys():
		assert_has(["chain_a", "chain_b", "scrap_barrage", "scrap_swing", "wrecking_drop"], str(id))
	assert_does_not_have(seen, "stomp_march", "not in the last stand's list")


func test_the_attack_that_opens_a_standing_plate_is_favoured() -> void:
	var counts: Dictionary = {"scrap_swing": 0, "wrecking_drop": 0, "stomp_march": 0, "scrap_barrage": 0}
	for rng_seed: int in range(1, 300):
		var brain: BossBrain = _heap(rng_seed)
		# the fixed opening (swing, drop) done; a distance where all four fit (barrage needs 30 m or more, the swing 38 or less)
		for opener: StringName in [&"scrap_swing", &"wrecking_drop"]:
			var first: Dictionary = brain.step(0.0, _heap_view({"dist_m": 33.0}))
			assert_eq(first["pattern"], opener)
			brain.begin(opener, 0.0)
			brain.finish(0.0, 0, 0.0)
		var pick: Dictionary = brain.step(10.0, _heap_view({"dist_m": 33.0, "bias": {"stomp_march": 1.6}}))
		if not pick.is_empty():
			counts[String(pick["pattern"])] += 1
	assert_gt(float(counts["stomp_march"]), float(counts["scrap_barrage"]), "weight 2 x 1.6 against weight 2: %s" % [counts])


func test_every_heap_attack_obeys_the_fair_play_rules_in_the_data() -> void:
	var doc: Dictionary = _heap_doc()
	var floor_ms: float = float((doc["rules"] as Dictionary)["boss_windup_floor_ms"])
	var min_width: float = float((doc["readability"] as Dictionary)["decal_min_width_m"])
	var moves: Dictionary = CombatData.moves()["sets"]["junk_mech"]["moves"]
	for name_raw: Variant in ["scrap_swing_l", "scrap_swing_r", "wrecking_drop", "stomp_march", "scrap_barrage"]:
		var move: Dictionary = moves[str(name_raw)]
		assert_ge(float(move["impact_ms"]), floor_ms, "%s: a wind-up of at least %d ms" % [name_raw, int(floor_ms)])
		var decal: Dictionary = move["floor_decal"]
		assert_ge(float(decal.get("radius_m", 0.0)) * 2.0, min_width, "%s: a decal at least 12 m wide" % name_raw)
		assert_true(float(decal.get("min_width_m", 0.0)) >= min_width, "%s: the decal says so" % name_raw)


func test_every_pattern_move_in_the_heap_data_exists() -> void:
	var moves: MoveSet = MoveSet.load_default()
	for spec: Variant in _heap_doc()["patterns"] as Array:
		for move: Variant in (spec as Dictionary)["moves"] as Array:
			assert_true(moves.has_move(&"junk_mech", StringName(str(move))), str(move))
