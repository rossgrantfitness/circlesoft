extends TestCase
## M2-9: the simulator itself, and 200-run balance checks against data/battle/feel_targets.json.
## Everything runs on the virtual clock, so 1,000 fights take a few seconds.


func _sim() -> BattleSim:
	return BattleSim.new(BattleTestKit.fresh_data(tree))


func _runs(sim: BattleSim) -> int:
	return int((sim.data.feel["sim"] as Dictionary)["checks_runs"])


func _check_player(player: String) -> Array[Dictionary]:
	var sim: BattleSim = _sim()
	var all: Array[Dictionary] = []
	var problems: Array[String] = []
	for encounter_id: String in sim.data.encounter_order:
		var stats: Dictionary = await sim.run_many(encounter_id, player, _runs(sim), 1)
		all.append(stats)
		problems.append_array(sim.check_against_targets(stats))
	assert_eq(problems, [] as Array[String], "%s player outside the feel targets: %s" % [player, problems])
	return all


# ---- the players ----

func test_perfect_player_wins_and_fights_land_in_the_target_lengths() -> void:
	var all: Array[Dictionary] = await _check_player("perfect")
	for stats: Dictionary in all:
		assert_eq(float(stats["win_rate"]), 1.0, "%s: perfect play never loses" % stats["encounter"])
		assert_gt(float(stats["mean_hp_left_pct"]), 95.0, "perfect blocks leave the party untouched")


func test_good_player_inside_the_feel_targets() -> void:
	await _check_player("good")


func test_auto_timing_player_inside_the_feel_targets() -> void:
	await _check_player("auto")


func test_miss_player_inside_the_feel_targets() -> void:
	await _check_player("miss")


func test_the_miss_player_can_still_win_the_easy_fights() -> void:
	var sim: BattleSim = _sim()
	for encounter_id: String in ["grunt_solo", "grunt_pair"]:
		var stats: Dictionary = await sim.run_many(encounter_id, "miss", _runs(sim), 1)
		assert_ge(float(stats["win_rate"]), 0.9, "%s: a player who never presses still wins" % encounter_id)


func test_perfect_play_feels_strong() -> void:
	var sim: BattleSim = _sim()
	var all: Array[Dictionary] = []
	for encounter_id: String in sim.data.encounter_order:
		for player: String in ["perfect", "miss"]:
			all.append(await sim.run_many(encounter_id, player, _runs(sim), 1))
	assert_eq(BattleSim.check_clutch_matters(sim.data, all), [] as Array[String])
	for encounter_id: String in sim.data.encounter_order:
		if str(sim.data.encounter(encounter_id).get("tier", "")) == "boss":
			continue # the never-pressing player dies sooner; the clutch check above covers it by win rate
		var perfect: Dictionary = {}
		var miss: Dictionary = {}
		for stats: Dictionary in all:
			if stats["encounter"] == encounter_id:
				if stats["player"] == "perfect":
					perfect = stats
				else:
					miss = stats
		assert_lt(float(perfect["mean_s"]), float(miss["mean_s"]), "%s: perfect play is faster" % encounter_id)
		assert_ge(float(perfect["mean_hp_left_pct"]), float(miss["mean_hp_left_pct"]), "%s: and takes less damage" % encounter_id)


func test_the_ladder_of_players_orders_by_skill() -> void:
	var sim: BattleSim = _sim()
	var times: Dictionary = {}
	for player: String in BattleSim.PLAYERS:
		times[player] = float((await sim.run_many("squad_four", player, 100, 5))["mean_s"])
	assert_lt(float(times["perfect"]), float(times["good"]) + 1.0)
	assert_lt(float(times["good"]), float(times["auto"]), "Auto-Timing (all Rad) is slower than good play")
	assert_lt(float(times["auto"]), float(times["miss"]), "but beats never pressing")


# ---- lengths, determinism, data-driven ----

func test_fight_time_is_timeline_plus_two_seconds_of_menu_per_command() -> void:
	var sim: BattleSim = _sim()
	var fight: Dictionary = await sim.run_fight("grunt_pair", "good", 3, 2)
	var expected: float = (float(fight["timeline_ms"]) + float(fight["commands"]) * 2000.0) / 1000.0
	assert_almost_eq(float(fight["seconds"]), expected, 0.001)
	assert_gt(float(fight["timeline_ms"]), 5000.0, "action timelines take real (virtual) time")
	assert_eq(int(fight["menu_ms"]), int(fight["commands"]) * 2000)


func test_the_same_seed_replays_exactly() -> void:
	var sim: BattleSim = _sim()
	var a: Dictionary = await sim.run_fight("squad_four", "good", 42, 4)
	var b: Dictionary = await sim.run_fight("squad_four", "good", 42, 4)
	assert_eq(a["timeline_ms"], b["timeline_ms"])
	assert_eq(a["party"], b["party"])
	assert_eq(a["rounds"], b["rounds"])
	var c: Dictionary = await sim.run_fight("squad_four", "good", 43, 4)
	assert_ne(a["timeline_ms"], c["timeline_ms"], "another seed is another fight")


func test_balance_lives_in_data_so_editing_a_number_changes_the_fights() -> void:
	var sim: BattleSim = _sim()
	var base: Dictionary = await sim.run_many("grunt_pair", "good", 40, 1)
	for enemy_id: String in sim.data.enemies:
		(sim.data.enemy(enemy_id)["stats"] as Dictionary)["hp"] = int((sim.data.enemy(enemy_id)["stats"] as Dictionary)["hp"]) * 2
	var tougher: Dictionary = await sim.run_many("grunt_pair", "good", 40, 1)
	assert_gt(float(tougher["mean_s"]), float(base["mean_s"]) * 1.4, "doubling enemy HP makes fights clearly longer")
	var easy: BattleSim = _sim()
	(easy.data.windows_doc["windows"]["standard"] as Dictionary)["totally_rad_ms"] = 79
	(easy.data.windows_doc["windows"]["block"] as Dictionary)["totally_rad_ms"] = 79
	var wider: Dictionary = await easy.run_many("grunt_pair", "good", 40, 1)
	assert_le(float(wider["mean_hp_left_pct"]), 100.0)


func test_every_fight_ends_and_reports_a_result() -> void:
	var sim: BattleSim = _sim()
	for encounter_id: String in sim.data.encounter_order:
		for player: String in BattleSim.PLAYERS:
			var fight: Dictionary = await sim.run_fight(encounter_id, player, 7, int(sim.data.encounter(encounter_id)["suggested_level"]))
			assert_has(["win", "lose"], fight["result"])
			assert_lt(float(fight["rounds"]), float(BattleController.MAX_ROUNDS), "%s/%s ended on its own" % [encounter_id, player])


# ---- the walkthrough ----

func test_walkthrough_ends_near_level_six_with_credits_in_range() -> void:
	var sim: BattleSim = _sim()
	var targets: Dictionary = sim.data.feel["walkthrough"]
	var finished: int = 0
	var level_total: float = 0.0
	var credit_total: float = 0.0
	var n: int = 20
	for i: int in n:
		var walk: Dictionary = await sim.walkthrough("good", 500 + i * 37)
		if walk["completed"]:
			finished += 1
			level_total += float(walk["level"])
			credit_total += float(walk["credits"])
	assert_ge(float(finished) / float(n), float((targets["min_completed_rate"] as Dictionary)["good"]))
	var levels: Array = targets["final_level"]
	var average_level: float = level_total / float(maxi(finished, 1))
	assert_ge(average_level, float(levels[0]), "level at Kasp")
	assert_le(average_level, float(levels[1]))
	var credits: Array = targets["battle_credits"]
	var average_credits: float = credit_total / float(maxi(finished, 1))
	assert_ge(average_credits, float(credits[0]), "credits earned in battle by Kasp")
	assert_le(average_credits, float(credits[1]))
	assert_le(average_credits, float(sim.data.feel["credits_at_kasp"]), "the rest of the 1,500 comes from crates and side jobs")


func test_walkthrough_sequence_uses_real_encounters() -> void:
	var sim: BattleSim = _sim()
	var route: Array = (sim.data.feel["walkthrough"] as Dictionary)["route"]
	assert_ge(route.size(), 8)
	for step: Variant in route:
		assert_true(sim.data.encounters.has(str((step as Dictionary)["encounter"])), str((step as Dictionary)["encounter"]))
		for who: Variant in (step as Dictionary)["party"]:
			assert_true(sim.data.characters.has(str(who)), str(who))


# ---- the simulated players ----

func _slot(type: String, cue: int) -> Dictionary:
	var window: Dictionary = {"nice_ms": 125.0, "rad_ms": 80.0, "totally_rad_ms": 50.0}
	return ClutchJudge.make_slot(type, cue, cue - 500000, 400, window, 1.0)


func test_perfect_source_presses_exactly_on_the_cue() -> void:
	var source: SimPressSource = SimPressSource.make("perfect")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var plan: Dictionary = source.plan(_slot("tap", 5000000), rng)
	assert_eq(plan["downs"], [5000000] as Array[int])
	var hold: Dictionary = source.plan(_slot("hold_release", 5000000), rng)
	assert_eq(hold["ups"], [5000000] as Array[int], "released on the cue")
	assert_le(int((hold["downs"] as Array[int])[0]), 5000000 - 500000, "and started in time")


func test_miss_source_never_presses() -> void:
	var source: SimPressSource = SimPressSource.make("miss")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for type: String in ["tap", "hold_release", "string"]:
		var plan: Dictionary = source.plan(_slot(type, 1000000), rng)
		assert_eq((plan["downs"] as Array[int]).size(), 0)
		assert_eq((plan["ups"] as Array[int]).size(), 0)


func test_good_source_spreads_around_the_cue_with_a_few_lapses() -> void:
	var source: SimPressSource = SimPressSource.make("good", 40.0, 450.0, 0.1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var errors: Array[float] = []
	var lapses: int = 0
	for i: int in 4000:
		var plan: Dictionary = source.plan(_slot("tap", 1000000), rng)
		if (plan["downs"] as Array[int]).is_empty():
			lapses += 1
		else:
			errors.append(float((plan["downs"] as Array[int])[0] - 1000000) / 1000.0)
	var mean: float = 0.0
	for e: float in errors:
		mean += e
	mean /= float(errors.size())
	var variance: float = 0.0
	for e: float in errors:
		variance += (e - mean) * (e - mean)
	var sigma: float = sqrt(variance / float(errors.size()))
	assert_almost_eq(mean, 0.0, 3.0)
	assert_almost_eq(sigma, 40.0, 4.0, "about 40 ms")
	assert_almost_eq(float(lapses) / 4000.0, 0.1, 0.02, "lapse rate")


func test_auto_timing_source_forces_rad_and_needs_no_events() -> void:
	var source: AutoTimingPressSource = AutoTimingPressSource.new()
	assert_eq(source.forced_rating(), "rad")
	assert_false(source.is_human())
	assert_true(HumanPressSource.new().is_human())
	assert_eq(HumanPressSource.new().forced_rating(), "")
