extends TestCase
## M2-4: the nine slice skills. Porch Light (tap blinds, hold-and-release slashes), Heave-Ho
## (splash plus a perfect-release stun), Patent Pending (the slot wheel), and the basic skills.

const DEFEND: Dictionary = {"kind": "defend"}


func _data() -> BattleData:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	(data.formulas["damage"] as Dictionary)["variance_pct"] = 0
	for enemy_id: String in data.enemies:
		data.enemy(enemy_id).erase("flee_at_hp_pct")
		(data.enemy(enemy_id)["stats"] as Dictionary)["attack"] = 1
	return data


func _damage(data: BattleData, atk: float, power: float, def: float, mult: float = 1.0) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	return BattleDamage.hit_damage(data, atk, power, def, mult, 1.0, 0.0, rng)


## Plays the first round (3 party commands) with every attack press at the given deltas.
func _cast(data: BattleData, encounter: String, level: int, commands: Array[Dictionary], deltas: Dictionary, seed: int = 1, setup_edit: Callable = Callable()) -> Dictionary:
	var setup: BattleSetup = BattleTestKit.setup_for(data, encounter, level, seed)
	if setup_edit.is_valid():
		setup_edit.call(setup)
	var presses: BattleTestKit.FixedPressSource = BattleTestKit.FixedPressSource.new(0.0)
	presses.per_index = deltas
	presses.attack_only = true
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.queue = commands.duplicate()
	source.fallback = DEFEND
	source.limit = 3
	setup.command_source = source
	setup.press_source = presses
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	await controller.start()
	return {"controller": controller, "log": log}


func _from(log: BattleTestKit.Recorder, source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in log.hits():
		if info["source"] == source:
			out.append(info)
	return out


func _porch_light(target: String = "e1") -> Array[Dictionary]:
	return [{"kind": "skill", "skill_id": "porch_light", "targets": [target]}]


# ---- Porch Light ----

func test_porch_light_is_a_tap_then_a_hold_and_release() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_solo", 3, _porch_light(), {})
	var action: Dictionary = (run["log"].of("action_started")[0]["args"] as Array)[0]
	assert_eq(action["skill_id"], "porch_light")
	assert_eq(action["name"], "Porch Light")
	assert_eq(action["show_name"], true, "the name slams onto the screen")
	var presses: Array = action["presses"]
	assert_eq(presses.size(), 2)
	assert_eq((presses[0] as Dictionary)["type"], "tap")
	assert_eq((presses[1] as Dictionary)["type"], "hold_release")
	assert_lt(float((presses[0] as Dictionary)["cue_ms"]), float((presses[1] as Dictionary)["cue_ms"]))
	assert_lt(float((presses[1] as Dictionary)["hold_by_ms"]), float((presses[1] as Dictionary)["cue_ms"]))
	assert_eq(((action["timeline_ms"] as Dictionary)["impacts"] as Array).size(), 2, "two impacts")


func test_porch_light_numbers_and_juice() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "grunt_solo", 3, _porch_light(), {0: 0.0, 1: 60.0})
	var log: BattleTestKit.Recorder = run["log"]
	var hits: Array[Dictionary] = _from(log, "red")
	assert_eq(hits.size(), 2)
	assert_eq(int(hits[0]["amount"]), _damage(data, 8.0, 0.5, 4.0, 1.4), "the lamp flare hits with Heart; a perfect tap is x1.4")
	assert_eq(int(hits[1]["amount"]), _damage(data, 14.0, 1.4, 4.0, 1.25), "the spin slash hits with Attack; Rad is x1.25")
	var red: BattleCombatant = (run["controller"] as BattleController).state.get_c("red")
	assert_eq(red.juice, 16 - 8 + 2 + 1, "costs 8, a TOTALLY RAD gives 2 and a Rad gives 1")


func test_a_good_tap_blinds_the_enemy_as_wobbly_and_a_miss_does_not() -> void:
	var perfect: Dictionary = await _cast(_data(), "grunt_solo", 3, _porch_light(), {0: 0.0, 1: 0.0})
	var statuses: Array = []
	for e: Dictionary in (perfect["log"] as BattleTestKit.Recorder).of("status_changed"):
		statuses.append((e["args"] as Array).duplicate())
	assert_has(statuses, ["e1", "wobbly", true], "TOTALLY RAD always blinds")
	var missed: Dictionary = await _cast(_data(), "grunt_solo", 3, _porch_light(), {0: 400.0, 1: 0.0})
	for e: Dictionary in (missed["log"] as BattleTestKit.Recorder).of("status_changed"):
		assert_ne((e["args"] as Array)[1], "wobbly", "a missed tap blinds nobody")


func test_the_blind_chance_grows_with_the_rating() -> void:
	var landed: Dictionary = {"nice": 0, "rad": 0}
	for seed: int in 80:
		for rating: String in ["nice", "rad"]:
			var delta: float = 100.0 if rating == "nice" else 60.0
			var data: BattleData = _data()
			(data.status("wobbly") as Dictionary)["duration_turns"] = 9
			var run: Dictionary = await _cast(data, "grunt_solo", 3, _porch_light(), {0: delta, 1: 400.0}, seed)
			if (run["controller"] as BattleController).state.get_c("e1").has_status("wobbly"):
				landed[rating] = int(landed[rating]) + 1
	assert_gt(float(landed["nice"]), 0.3 * 80.0)
	assert_lt(float(landed["nice"]), 0.9 * 80.0)
	assert_gt(float(landed["rad"]), float(landed["nice"]) - 6.0, "Rad blinds at least as often as Nice")


# ---- Heave-Ho ----

func _heave_ho(target: String = "e1") -> Array[Dictionary]:
	return [DEFEND, DEFEND, {"kind": "skill", "skill_id": "heave_ho", "targets": [target]}]


func test_heave_ho_hurts_the_target_and_a_second_enemy() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "grunt_pair", 3, _heave_ho(), {0: 60.0})
	var hits: Array[Dictionary] = _from(run["log"], "otis")
	assert_eq(hits.size(), 2, "both enemies feel it")
	assert_eq(hits[0]["target"], "e1")
	assert_eq(hits[1]["target"], "e2", "slammed onto the other one")
	assert_eq(int(hits[0]["amount"]), _damage(data, 12.0, 1.2, 4.0, 1.25), "Rad: x1.25 on the lifted enemy")
	assert_eq(int(hits[1]["amount"]), _damage(data, 12.0, 1.2, 4.0, 0.8), "Rad: 0.8 on the one it lands on")


func test_heave_ho_splash_scales_with_the_release() -> void:
	var expect: Dictionary = {400.0: 0.4, 100.0: 0.6, 60.0: 0.8, 0.0: 1.0}
	for delta: float in expect:
		var data: BattleData = _data()
		var run: Dictionary = await _cast(data, "grunt_pair", 3, _heave_ho(), {0: delta})
		var splash: Dictionary = _from(run["log"], "otis")[1]
		assert_eq(int(splash["amount"]), _damage(data, 12.0, 1.2, 4.0, float(expect[delta])), "release %s ms off" % delta)


func test_heave_ho_with_only_one_enemy_has_no_splash() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_solo", 3, _heave_ho(), {0: 0.0})
	assert_eq(_from(run["log"], "otis").size(), 1)


func test_a_perfect_release_stuns_both_and_they_lose_their_turn() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_pair", 3, _heave_ho(), {0: 0.0})
	var log: BattleTestKit.Recorder = run["log"]
	var stunned: Array = []
	for e: Dictionary in log.of("status_changed"):
		var args: Array = e["args"]
		if args[1] == "stunned" and args[2] == true:
			stunned.append(args[0])
	assert_eq(stunned, ["e1", "e2"])
	assert_eq(log.messages().count("Stunned! Skips the turn."), 2, "both lose the turn they had coming")
	assert_eq(_from(log, "e1").size(), 0, "a stunned enemy does not act")
	assert_eq(_from(log, "e2").size(), 0)
	var cleared: int = 0
	for e: Dictionary in log.of("status_changed"):
		if (e["args"] as Array)[1] == "stunned" and (e["args"] as Array)[2] == false:
			cleared += 1
	assert_eq(cleared, 2, "the stun lasts exactly one turn")


func test_an_ordinary_release_does_not_stun() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_pair", 3, _heave_ho(), {0: 60.0})
	var stuns: int = 0
	for e: Dictionary in (run["log"] as BattleTestKit.Recorder).of("status_changed"):
		if (e["args"] as Array)[1] == "stunned":
			stuns += 1
	assert_eq(stuns, 0, "Rad is not enough to stun")


# ---- Patent Pending ----

func _patent(target: String = "e1") -> Array[Dictionary]:
	return [DEFEND, {"kind": "skill", "skill_id": "patent_pending", "targets": [target]}]


func test_patent_pending_is_a_tap_that_stops_the_wheel() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_solo", 3, _patent(), {0: 0.0})
	var action: Dictionary = {}
	for e: Dictionary in (run["log"] as BattleTestKit.Recorder).of("action_started"):
		if (e["args"] as Array)[0]["actor"] == "mox":
			action = (e["args"] as Array)[0]
	assert_eq(action["skill_id"], "patent_pending")
	assert_eq((action["presses"] as Array).size(), 1)
	assert_eq(((action["presses"] as Array)[0] as Dictionary)["type"], "tap")


func test_the_timing_picks_the_wheel_tier() -> void:
	var tiers: Dictionary = {0.0: "totally_rad", 60.0: "rad", 100.0: "nice", 300.0: "miss"}
	var results_by_tier: Dictionary = {}
	for tier_seed: int in 30:
		for delta: float in tiers:
			var data: BattleData = _data()
			var run: Dictionary = await _cast(data, "squad_four", 3, _patent(), {0: delta}, tier_seed)
			var logged: Array[Dictionary] = (run["log"] as BattleTestKit.Recorder).of("skill_result")
			assert_eq(logged.size(), 1)
			var info: Dictionary = (logged[0]["args"] as Array)[0]
			assert_eq(info["tier"], tiers[delta])
			if not results_by_tier.has(info["tier"]):
				results_by_tier[info["tier"]] = {}
			(results_by_tier[info["tier"]] as Dictionary)[info["result_id"]] = true
			assert_has((run["log"] as BattleTestKit.Recorder).messages(), "%s!" % info["name"], "the gadget is announced")
	assert_eq((results_by_tier["totally_rad"] as Dictionary).keys(), ["mox_o_matic"], "TOTALLY RAD always lands the amazing one")
	for id: String in (results_by_tier["miss"] as Dictionary):
		assert_has(["fizzle", "tuesday_bonk"], id)
	for id: String in (results_by_tier["nice"] as Dictionary):
		assert_has(["zappy_thing", "sticky_foam"], id)
	for id: String in (results_by_tier["rad"] as Dictionary):
		assert_has(["heat_lamp_cannon", "mega_magnet", "soup_dispenser"], id)
	assert_gt(float((results_by_tier["rad"] as Dictionary).size()), 1.0, "the wheel has variety below perfect")


func test_the_amazing_gadget_hits_every_enemy_and_heals_the_party() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "squad_four", 3, _patent(), {0: 0.0}, 3, func(setup: BattleSetup) -> void:
		setup.party[0]["hp"] = 30
		setup.party[1]["hp"] = 60)
	var log: BattleTestKit.Recorder = run["log"]
	var damaged: Array = []
	var healed: Array = []
	for info: Dictionary in _from(log, "mox"):
		if info["kind"] == "damage":
			damaged.append(info["target"])
			assert_eq(int(info["amount"]), _damage(data, 14.0, 1.6, float((data.enemy(_kind_of(run, str(info["target"])))["stats"] as Dictionary)["defense"])))
		else:
			healed.append(info["target"])
	assert_eq(damaged, ["e1", "e2", "e3", "e4"])
	assert_eq(healed, ["red", "otis"], "only the hurt ones show a heal number")


func _kind_of(run: Dictionary, id: String) -> String:
	return (run["controller"] as BattleController).state.get_c(id).kind


func test_the_wheel_is_deterministic_for_a_seed() -> void:
	var picks: Array = []
	for i: int in 2:
		var run: Dictionary = await _cast(_data(), "grunt_solo", 3, _patent(), {0: 60.0}, 12)
		picks.append(((run["log"] as BattleTestKit.Recorder).of("skill_result")[0]["args"] as Array)[0])
	assert_eq(picks[0], picks[1])


func test_a_missed_wheel_still_does_a_little() -> void:
	var run: Dictionary = await _cast(_data(), "grunt_solo", 3, _patent(), {0: 400.0})
	assert_gt(float(_from(run["log"], "mox").size()), 0.0, "a fizzle is still a hit: missing never hurts")


# ---- the other six skills ----

func test_double_swing_hits_twice() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "grunt_solo", 3, [{"kind": "skill", "skill_id": "double_swing", "targets": ["e1"]}], {0: 0.0, 1: 0.0})
	var swings: Array[Dictionary] = _from(run["log"], "red")
	assert_eq(swings.size(), 2)
	var action: Dictionary = ((run["log"] as BattleTestKit.Recorder).of("action_started")[0]["args"] as Array)[0]
	for press: Dictionary in action["presses"]:
		assert_eq(press["type"], "string")
	assert_eq((run["controller"] as BattleController).state.get_c("red").juice, 16 - 4 + 2 + 2)


func test_the_third_skills_need_level_four() -> void:
	var cases: Array = [["red", "sunrise_slash", ["e1"]], ["otis", "cough_drop", ["red"]], ["mox", "duct_tape", ["red"]]]
	for case: Array in cases:
		var data: BattleData = _data()
		var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
		var controller: BattleController = BattleController.create(setup)
		var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
		controller.start()
		var actor: String = str((log.of("command_needed")[0]["args"] as Array)[0])
		controller.submit_command({"kind": "skill", "skill_id": case[1], "targets": case[2]})
		assert_eq(log.count("action_started"), 0 if actor == case[0] else log.count("action_started"), "%s is not known at level 3" % case[1])
		var options: Dictionary = (log.of("command_needed")[0]["args"] as Array)[1]
		for entry: Dictionary in options["skills"]:
			assert_ne(entry["id"], case[1])
		controller.abort()
		var learned: Array[String] = Progression.new(data).skills_known(str(case[0]), 4)
		assert_has(learned, case[1])


func test_sunrise_slash_door_slam_and_pocket_sparkler_do_their_damage() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "squad_four", 4, [
		{"kind": "skill", "skill_id": "sunrise_slash", "targets": ["e1"]},
		{"kind": "skill", "skill_id": "pocket_sparkler", "targets": ["e1", "e2", "e3", "e4"]},
		{"kind": "skill", "skill_id": "door_slam", "targets": ["e2"]}], {0: 0.0})
	var log: BattleTestKit.Recorder = run["log"]
	var red: Array[Dictionary] = _from(log, "red")
	assert_eq(red.size(), 1)
	assert_eq(int(red[0]["amount"]), _damage(data, 16.0, 2.0, 4.0, 1.4))
	var mox: Array[Dictionary] = _from(log, "mox")
	assert_eq(mox.size(), 4, "Pocket Sparkler hits every enemy")
	assert_eq(int(mox[0]["amount"]), _damage(data, 16.0, 0.7, 4.0, 1.4))
	var otis: Array[Dictionary] = _from(log, "otis")
	assert_eq(otis.size(), 1)
	assert_eq(int(otis[0]["amount"]), _damage(data, 13.0, 1.4, 4.0, 1.4))


func test_cough_drop_and_duct_tape_heal_a_friend() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _cast(data, "grunt_solo", 4, [
		DEFEND,
		{"kind": "skill", "skill_id": "duct_tape", "targets": ["otis"]},
		{"kind": "skill", "skill_id": "cough_drop", "targets": ["red"]}], {0: 0.0}, 1, func(setup: BattleSetup) -> void:
			setup.party[0]["hp"] = 10
			setup.party[1]["hp"] = 10)
	var heals: Dictionary = {}
	for info: Dictionary in (run["log"] as BattleTestKit.Recorder).hits():
		if info["kind"] == "heal":
			heals[info["source"]] = info
	assert_eq(int(heals["mox"]["amount"]), int(round(3.2 * 16.0 * 1.4)), "Duct Tape: Mox's Heart x3.2, perfect x1.4")
	assert_eq(heals["mox"]["target"], "otis")
	assert_eq(int(heals["otis"]["amount"]), int(round(4.5 * 6.0 * 1.4)), "Cough Drop: Otis's Heart x4.5")
	assert_eq(heals["otis"]["target"], "red")


func test_every_party_skill_costs_juice_and_does_something() -> void:
	var data: BattleData = _data()
	var progression: Progression = Progression.new(data)
	for char_id: String in data.character_order:
		for skill_id: String in progression.skills_known(char_id, 4):
			var skill: Dictionary = data.skill(skill_id)
			var targets: Array = ["e1"]
			if str(skill["target"]) == "one_ally":
				targets = [char_id]
			elif str(skill["target"]) == "all_enemies":
				targets = ["e1", "e2", "e3", "e4"]
			var commands: Array[Dictionary] = []
			var order: Array[String] = ["red", "mox", "otis"]
			for who: String in order:
				commands.append({"kind": "skill", "skill_id": skill_id, "targets": targets} if who == char_id else DEFEND)
			var run: Dictionary = await _cast(data, "squad_four", 4, commands, {0: 400.0, 1: 400.0, 2: 400.0}, 1, func(setup: BattleSetup) -> void:
				for member: Dictionary in setup.party:
					member["hp"] = 12)
			var log: BattleTestKit.Recorder = run["log"]
			var found: bool = false
			for e: Dictionary in log.of("action_started"):
				var action: Dictionary = (e["args"] as Array)[0]
				if action["actor"] == char_id and action["skill_id"] == skill_id:
					found = true
			assert_true(found, "%s used %s" % [char_id, skill_id])
			assert_gt(float(_from(log, char_id).size()), 0.0, "%s did something" % skill_id)
			var fighter: BattleCombatant = (run["controller"] as BattleController).state.get_c(char_id)
			assert_le(fighter.juice, fighter.juice_max - int(skill["juice_cost"]) + 3, "%s spent its Juice (defend refunds at most 3 later)" % skill_id)
