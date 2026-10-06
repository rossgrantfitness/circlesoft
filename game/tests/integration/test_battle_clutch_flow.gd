extends TestCase
## M2-3: Clutch inside a running battle. Presses arrive through press_down / press_up with
## timestamps (like the view's _input does) or from a press source; the model judges them against
## t0 + cue + timing offset on the battle clock. Nothing here waits in real time.

const ATTACK_E1: Dictionary = {"kind": "attack", "targets": ["e1"]}
const DEFEND: Dictionary = {"kind": "defend"}


func _data() -> BattleData:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	(data.formulas["damage"] as Dictionary)["variance_pct"] = 0
	data.enemy("signals_grunt").erase("flee_at_hp_pct")
	return data


func _damage(data: BattleData, atk: float, power: float, def: float, mult: float = 1.0, defend: float = 1.0, reduction: float = 0.0) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	return BattleDamage.hit_damage(data, atk, power, def, mult, defend, reduction, rng)


## Runs round 1 (the three party commands and the enemy's turn). `presses` is called for every
## action_started and returns events [["down"/"up", delta_ms_from_cue, press_index], ...] for it.
func _round(setup: BattleSetup, commands: Array[Dictionary], presses: Callable = Callable(), who: String = "") -> Dictionary:
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.queue = commands.duplicate()
	source.fallback = DEFEND
	source.limit = 3
	setup.command_source = source
	setup.press_source = HumanPressSource.new()
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	var injector: Callable = Callable()
	if presses.is_valid():
		injector = func(action: Dictionary) -> void:
			if not who.is_empty() and action["actor"] != who:
				return
			if (action["presses"] as Array).is_empty():
				return
			var t0: int = int(action["t0_usec"])
			for ev: Array in presses.call(action):
				var press: Dictionary = {}
				for p: Dictionary in action["presses"]:
					if int(p["index"]) == int(ev[2]):
						press = p
				var t: int = t0 + int(press["cue_ms"]) * 1000 + int(float(ev[1]) * 1000.0)
				if ev[0] == "down":
					controller.press_down(t)
				else:
					controller.press_up(t)
		controller.action_started.connect(injector)
	await controller.start()
	if injector.is_valid():
		controller.action_started.disconnect(injector)
	return {"controller": controller, "log": log}


func _tap_at(delta_ms: float) -> Callable:
	return func(_action: Dictionary) -> Array: return [["down", delta_ms, 0]]


func _first_rating(log: BattleTestKit.Recorder) -> Dictionary:
	return log.presses()[0]


func _hits_from(log: BattleTestKit.Recorder, source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in log.hits():
		if info["source"] == source:
			out.append(info)
	return out


# ---- the attack-side ladder ----

func test_every_delta_gets_its_rating_and_its_damage_bonus() -> void:
	var cases: Array = [[0.0, "totally_rad"], [50.0, "totally_rad"], [-50.0, "totally_rad"], [55.0, "rad"], [-80.0, "rad"],
		[90.0, "nice"], [-125.0, "nice"], [130.0, "miss"], [-300.0, "miss"]]
	for case: Array in cases:
		var data: BattleData = _data()
		var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
		var run: Dictionary = await _round(setup, [ATTACK_E1], _tap_at(float(case[0])), "red")
		var log: BattleTestKit.Recorder = run["log"]
		var judged: Dictionary = _first_rating(log)
		assert_eq(judged["rating"], case[1], "tap %s ms off" % case[0])
		if float(case[0]) <= 125.0:
			assert_almost_eq(float(judged["delta_ms"]), float(case[0]), 0.01)
		else:
			assert_eq(judged["pressed"], false, "a press after the window is just too late")
		assert_eq(judged["side"], "attack")
		assert_eq(judged["actor"], "red")
		var mult: float = data.rating_power(str(case[1]))
		assert_eq(int(_hits_from(log, "red")[0]["amount"]), _damage(data, 14.0, 1.0, 4.0, mult), "damage for %s" % case[1])


func test_no_press_is_a_miss_with_normal_damage() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _round(BattleTestKit.setup_for(data, "grunt_solo", 3), [ATTACK_E1])
	var log: BattleTestKit.Recorder = run["log"]
	assert_eq(_first_rating(log)["rating"], "miss")
	assert_eq(_first_rating(log)["pressed"], false)
	assert_eq(int(_hits_from(log, "red")[0]["amount"]), _damage(data, 14.0, 1.0, 4.0))


func test_mashing_does_not_help_the_first_press_is_the_one_judged() -> void:
	var data: BattleData = _data()
	var mash: Callable = func(_action: Dictionary) -> Array:
		return [["down", -390.0, 0], ["down", -300.0, 0], ["down", -200.0, 0], ["down", -100.0, 0], ["down", 0.0, 0], ["down", 20.0, 0]]
	var run: Dictionary = await _round(BattleTestKit.setup_for(data, "grunt_solo", 3), [ATTACK_E1], mash, "red")
	var judged: Dictionary = _first_rating(run["log"])
	assert_eq(judged["rating"], "miss", "mashing earned nothing")
	assert_almost_eq(float(judged["delta_ms"]), -390.0, 0.01)
	var red_presses: int = 0
	for info: Dictionary in (run["log"] as BattleTestKit.Recorder).presses():
		if info["actor"] == "red":
			red_presses += 1
	assert_eq(red_presses, 1, "one press, one judgement")


func test_presses_before_the_action_started_are_thrown_away() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.queue = [ATTACK_E1]
	source.limit = 1
	setup.command_source = source
	setup.press_source = HumanPressSource.new()
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.press_down(0)
	controller.press_up(10)
	await controller.start()
	assert_eq(_first_rating(log)["pressed"], false, "a press from the menu does not count")


func test_the_cue_moves_with_the_timing_offset_setting() -> void:
	var data: BattleData = _data()
	var plain_setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var plain: Dictionary = await _round(plain_setup, [ATTACK_E1], _tap_at(60.0), "red")
	assert_eq(_first_rating(plain["log"])["rating"], "rad", "60 ms late")
	var shifted_setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
	shifted_setup.timing_offset_ms = 60
	var shifted: Dictionary = await _round(shifted_setup, [ATTACK_E1], _tap_at(60.0), "red")
	var judged: Dictionary = _first_rating(shifted["log"])
	assert_eq(judged["rating"], "totally_rad", "with a +60 ms offset the same press is perfect")
	assert_almost_eq(float(judged["delta_ms"]), 0.0, 0.01)
	var early_setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
	early_setup.timing_offset_ms = -40
	var early: Dictionary = await _round(early_setup, [ATTACK_E1], _tap_at(-40.0), "red")
	assert_eq(_first_rating(early["log"])["rating"], "totally_rad", "negative offsets too")


func test_wide_windows_make_a_late_press_count() -> void:
	var normal: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_solo", 3), [ATTACK_E1], _tap_at(150.0), "red")
	assert_eq(_first_rating(normal["log"])["rating"], "miss")
	var wide_setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
	wide_setup.wide_windows = true
	var wide: Dictionary = await _round(wide_setup, [ATTACK_E1], _tap_at(150.0), "red")
	assert_eq(_first_rating(wide["log"])["rating"], "nice", "125 ms * 1.5 = 187 ms")
	var wide_perfect: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
	wide_perfect.wide_windows = true
	var perfect: Dictionary = await _round(wide_perfect, [ATTACK_E1], _tap_at(70.0), "red")
	assert_eq(_first_rating(perfect["log"])["rating"], "totally_rad", "50 ms * 1.5 = 75 ms")


func test_auto_timing_lands_every_press_as_rad_without_any_input() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.auto_timing = true
	var run: Dictionary = await _round(setup, [ATTACK_E1])
	var log: BattleTestKit.Recorder = run["log"]
	assert_ge(log.presses().size(), 2, "Red's attack and the grunt's attack")
	for judged: Dictionary in log.presses():
		assert_eq(judged["rating"], "rad", "Auto-Timing = Rad, attack and block alike")
	assert_eq(int(_hits_from(log, "red")[0]["amount"]), _damage(data, 14.0, 1.0, 4.0, data.rating_power("rad")))


func test_auto_timing_covers_holds_and_strings_too() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.auto_timing = true
	var cmds: Array[Dictionary] = [{"kind": "skill", "skill_id": "porch_light", "targets": ["e1"]}, {"kind": "skill", "skill_id": "pocket_sparkler", "targets": ["e1"]}]
	var run: Dictionary = await _round(setup, cmds)
	var types: Array = []
	for e: Dictionary in (run["log"] as BattleTestKit.Recorder).of("action_started"):
		for press: Dictionary in (e["args"] as Array)[0]["presses"]:
			types.append(press["type"])
	assert_has(types, "tap")
	assert_has(types, "hold_release")
	for judged: Dictionary in (run["log"] as BattleTestKit.Recorder).presses():
		assert_eq(judged["rating"], "rad")


# ---- hold and release, strings ----

func _hold_presses(down_delta_from_hold_by: float, up_delta: float) -> Callable:
	return func(action: Dictionary) -> Array:
		var press: Dictionary = (action["presses"] as Array)[0]
		var down_delta: float = float(int(press["hold_by_ms"]) - int(press["cue_ms"])) + down_delta_from_hold_by
		return [["down", down_delta, 0], ["up", up_delta, 0]]


func test_heave_ho_is_judged_on_the_release() -> void:
	var cmd: Array[Dictionary] = [{"kind": "skill", "skill_id": "heave_ho", "targets": ["e1"]}]
	for case: Array in [[0.0, "totally_rad"], [60.0, "rad"], [-100.0, "nice"], [-250.0, "miss"], [300.0, "miss"]]:
		var setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_pair", 3)
		setup.party[0]["juice"] = 0
		var run: Dictionary = await _round(setup, [{"kind": "defend"}, {"kind": "defend"}] as Array[Dictionary], Callable(), "")
		var otis_setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_pair", 3)
		var run2: Dictionary = await _round(otis_setup, [DEFEND, DEFEND, cmd[0]] as Array[Dictionary], _hold_presses(-50.0, float(case[0])), "otis")
		var judged: Dictionary = (run2["log"] as BattleTestKit.Recorder).presses()[0]
		assert_eq(judged["rating"], case[1], "released %s ms from the cue" % case[0])
		assert_eq(judged["actor"], "otis")
		assert_eq(run["controller"].result, "aborted")


func test_a_hold_that_starts_after_hold_by_is_a_miss_even_if_released_perfectly() -> void:
	var cmd: Array[Dictionary] = [DEFEND, DEFEND, {"kind": "skill", "skill_id": "heave_ho", "targets": ["e1"]}]
	var late: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_pair", 3), cmd, _hold_presses(40.0, 0.0), "otis")
	assert_eq((late["log"] as BattleTestKit.Recorder).presses()[0]["rating"], "miss", "hold started 40 ms after hold_by")
	var on_time: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_pair", 3), cmd, _hold_presses(-1.0, 0.0), "otis")
	assert_eq((on_time["log"] as BattleTestKit.Recorder).presses()[0]["rating"], "totally_rad")


func test_a_hold_never_released_is_a_miss_after_the_window() -> void:
	var cmd: Array[Dictionary] = [DEFEND, DEFEND, {"kind": "skill", "skill_id": "heave_ho", "targets": ["e1"]}]
	var holding: Callable = func(action: Dictionary) -> Array:
		var press: Dictionary = (action["presses"] as Array)[0]
		return [["down", float(int(press["hold_by_ms"]) - int(press["cue_ms"])) - 50.0, 0]]
	var run: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_pair", 3), cmd, holding, "otis")
	assert_eq((run["log"] as BattleTestKit.Recorder).presses()[0]["rating"], "miss")


func test_a_string_is_judged_one_cue_at_a_time() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var swing: Callable = func(_action: Dictionary) -> Array:
		return [["down", 10.0, 0], ["down", 90.0, 1]]
	var run: Dictionary = await _round(setup, [{"kind": "skill", "skill_id": "double_swing", "targets": ["e1"]}], swing, "red")
	var log: BattleTestKit.Recorder = run["log"]
	var judged: Array = log.presses()
	assert_eq(judged[0]["rating"], "totally_rad")
	assert_eq(judged[0]["index"], 0)
	assert_eq(judged[1]["rating"], "nice", "the second stamp was 90 ms late")
	assert_eq(judged[1]["index"], 1)
	var swings: Array[Dictionary] = _hits_from(log, "red")
	assert_eq(int(swings[0]["amount"]), _damage(data, 14.0, 0.7, 4.0, data.rating_power("totally_rad")))
	assert_eq(int(swings[1]["amount"]), _damage(data, 14.0, 0.7, 4.0, data.rating_power("nice")))


func test_missing_one_cue_of_a_string_does_not_cost_the_others() -> void:
	var swing: Callable = func(_action: Dictionary) -> Array:
		return [["down", 0.0, 0]]
	var run: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_solo", 3), [{"kind": "skill", "skill_id": "double_swing", "targets": ["e1"]}], swing, "red")
	var judged: Array = (run["log"] as BattleTestKit.Recorder).presses()
	assert_eq(judged[0]["rating"], "totally_rad")
	assert_eq(judged[1]["rating"], "miss")


# ---- the defender's side ----

func _block_setup(data: BattleData, enemy_skill: String = "grunt_bonk") -> BattleSetup:
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["hp"] = 20
	(data.enemy("signals_grunt")["ai"] as Array).assign([{"skill": enemy_skill, "weight": 1, "pick": "lowest_hp"}])
	return setup


func test_block_ladder_and_damage_reduction() -> void:
	var cases: Array = [[0.0, "totally_rad", "perfect", 1.0], [60.0, "rad", "partial", 0.5], [100.0, "nice", "partial", 0.25], [200.0, "miss", "none", 0.0]]
	for case: Array in cases:
		var data: BattleData = _data()
		var run: Dictionary = await _round(_block_setup(data), [ATTACK_E1], _tap_at(float(case[0])), "e1")
		var log: BattleTestKit.Recorder = run["log"]
		var judged: Dictionary = log.presses().back()
		assert_eq(judged["rating"], case[1])
		assert_eq(judged["side"], "block")
		assert_eq(judged["owner_id"], "red", "the defender gets the '!' and the pop-up")
		assert_eq(judged["actor"], "e1")
		var blow: Dictionary = _hits_from(log, "e1")[0]
		assert_eq(blow["blocked"], case[2])
		assert_eq(int(blow["amount"]), _damage(data, 13.0, 1.0, 6.0, 1.0, 1.0, float(case[3])), "block reduction %s" % case[3])


func test_a_perfect_block_takes_no_damage_at_all() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _round(_block_setup(data), [ATTACK_E1], _tap_at(0.0), "e1")
	var blow: Dictionary = _hits_from(run["log"], "e1")[0]
	assert_eq(int(blow["amount"]), 0)
	assert_eq((run["controller"] as BattleController).state.get_c("red").hp, 20)


func test_block_press_belongs_to_the_defender_in_the_action_data() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _round(_block_setup(data), [ATTACK_E1])
	var action: Dictionary = {}
	for e: Dictionary in (run["log"] as BattleTestKit.Recorder).of("action_started"):
		if (e["args"] as Array)[0]["actor"] == "e1":
			action = (e["args"] as Array)[0]
	assert_eq(action["targets"], ["red"])
	var press: Dictionary = (action["presses"] as Array)[0]
	assert_eq(press["side"], "block")
	assert_eq(press["owner_id"], "red")
	assert_eq(press["type"], "tap")
	assert_eq(int(press["cue_ms"]), 900)
	assert_eq(int((action["timeline_ms"] as Dictionary)["windup"]), 650, "the tell is the wind-up")


func test_defending_makes_the_block_window_easier() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = _block_setup(data)
	var defend_run: Dictionary = await _round(setup, [DEFEND], _tap_at(60.0), "e1")
	assert_eq((defend_run["log"] as BattleTestKit.Recorder).presses().back()["rating"], "totally_rad", "Defend: 50 ms * 1.25 = 62.5")
	var data2: BattleData = _data()
	var plain_run: Dictionary = await _round(_block_setup(data2), [ATTACK_E1], _tap_at(60.0), "e1")
	assert_eq((plain_run["log"] as BattleTestKit.Recorder).presses().back()["rating"], "rad", "the same press without Defend is only Rad")


func test_rad_or_better_gives_a_sip_of_juice_and_nice_does_not() -> void:
	for case: Array in [[0.0, 2], [60.0, 1], [100.0, 0], [300.0, 0]]:
		var setup: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
		setup.party[0]["juice"] = 0
		var run: Dictionary = await _round(setup, [ATTACK_E1], _tap_at(float(case[0])), "red")
		var red: BattleCombatant = (run["controller"] as BattleController).state.get_c("red")
		assert_eq(red.juice, case[1], "attack press %s ms off" % case[0])


func test_a_good_block_also_gives_juice_to_the_defender() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = _block_setup(data)
	setup.party[0]["juice"] = 0
	var run: Dictionary = await _round(setup, [ATTACK_E1], _tap_at(0.0), "e1")
	assert_eq((run["controller"] as BattleController).state.get_c("red").juice, 1, "a Perfect Block earns one Juice")


func test_payback_on_a_perfect_block_of_a_melee_hit() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _round(_block_setup(data, "grunt_bonk"), [ATTACK_E1], _tap_at(0.0), "e1")
	var log: BattleTestKit.Recorder = run["log"]
	var paybacks: Array[Dictionary] = []
	for info: Dictionary in log.hits():
		if info["payback"]:
			paybacks.append(info)
	assert_eq(paybacks.size(), 1)
	assert_eq(paybacks[0]["source"], "red")
	assert_eq(paybacks[0]["target"], "e1")
	assert_eq(int(paybacks[0]["amount"]), _damage(data, 14.0, 0.8, 4.0), "0.8 of a basic hit, for free")


func test_no_payback_without_a_perfect_block() -> void:
	for delta: float in [60.0, 100.0, 250.0]:
		var run: Dictionary = await _round(_block_setup(_data(), "grunt_bonk"), [ATTACK_E1], _tap_at(delta), "e1")
		for info: Dictionary in (run["log"] as BattleTestKit.Recorder).hits():
			assert_false(info["payback"], "a %s ms press is not perfect" % delta)


func test_no_payback_for_ranged_hits_even_when_blocked_perfectly() -> void:
	var data: BattleData = _data()
	var run: Dictionary = await _round(_block_setup(data, "drone_zap"), [ATTACK_E1], _tap_at(0.0), "e1")
	var log: BattleTestKit.Recorder = run["log"]
	assert_eq(_hits_from(log, "e1")[0]["blocked"], "perfect")
	for info: Dictionary in log.hits():
		assert_false(info["payback"], "only close-up hits can be Paybacked")


# ---- missing never hurts ----

func test_ratings_only_ever_add_in_the_data() -> void:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	var ladder: Array[String] = ["miss", "nice", "rad", "totally_rad"]
	var last: float = -1.0
	for rating: String in ladder:
		assert_ge(data.rating_power(rating), last, "default attack bonus rises with the rating")
		last = data.rating_power(rating)
	assert_almost_eq(data.rating_power("miss"), 1.0, 0.0001, "a miss is exactly a normal hit")
	var reductions: Dictionary = data.windows_doc["block_reduction"]
	assert_false(reductions.has("miss"), "a miss blocks nothing: normal hurt")
	assert_le(float(reductions["nice"]), float(reductions["rad"]))
	assert_le(float(reductions["rad"]), float(reductions["totally_rad"]))
	for skill_id: String in data.skills:
		for fx: Dictionary in data.skill(skill_id)["effects"]:
			var table: Dictionary = fx.get("on_rating", {})
			if table.is_empty():
				continue
			var previous: float = 0.0
			for rating: String in ladder:
				var mult: float = float((table[rating] as Dictionary).get("power_mult", 1.0))
				assert_ge(mult, previous, "%s: %s never worse than a worse rating" % [skill_id, rating])
				previous = mult
			var chances: float = 0.0
			for rating: String in ladder:
				var c: float = 0.0
				for entry: Dictionary in (table[rating] as Dictionary).get("statuses", []):
					c = maxf(c, float(entry["chance"]))
				assert_ge(c, chances, "%s: status odds never shrink with better timing" % skill_id)
				chances = c


func test_a_badly_mistimed_fight_equals_a_fight_with_no_pressing_at_all() -> void:
	var results: Array[Dictionary] = []
	for press: bool in [false, true]:
		var data: BattleData = _data()
		var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3, 9)
		var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
		source.fallback = {"kind": "attack", "targets": ["e1"]}
		source.queue = [{"kind": "skill", "skill_id": "heave_ho", "targets": ["e1"]}, {"kind": "skill", "skill_id": "porch_light", "targets": ["e2"]}]
		source.limit = 6
		setup.command_source = source
		setup.press_source = BattleTestKit.FixedPressSource.new(700.0, press)
		var controller: BattleController = BattleController.create(setup)
		var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
		await controller.start()
		var amounts: Array = []
		for info: Dictionary in log.hits():
			amounts.append([info["source"], info["target"], info["amount"], info["blocked"]])
		results.append({"hits": amounts, "party": controller.get_result()["party"], "statuses": log.count("status_changed")})
	assert_eq(results[0], results[1], "pressing at the wrong time changes nothing compared with not pressing")


func test_a_scrambled_cue_still_judges_against_the_real_window() -> void:
	var data: BattleData = _data()
	data.skill("red_attack")["presses"][0]["shown_cue_ms"] = 300
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var run: Dictionary = await _round(setup, [ATTACK_E1], _tap_at(0.0), "red")
	var log: BattleTestKit.Recorder = run["log"]
	var action: Dictionary = (log.of("action_started")[0]["args"] as Array)[0]
	var press: Dictionary = (action["presses"] as Array)[0]
	assert_eq(press["scrambled"], true)
	assert_eq(int(press["shown_cue_ms"]), 300, "the view flashes at the fake time")
	assert_eq(int(press["cue_ms"]), 450, "the real cue never moves")
	assert_eq(_first_rating(log)["rating"], "totally_rad", "a press on the real cue is perfect")
	var data2: BattleData = _data()
	data2.skill("red_attack")["presses"][0]["shown_cue_ms"] = 300
	var fooled: Dictionary = await _round(BattleTestKit.setup_for(data2, "grunt_solo", 3), [ATTACK_E1], _tap_at(-150.0), "red")
	assert_eq(_first_rating(fooled["log"])["rating"], "miss", "following the fake flash misses")


func test_unscrambled_presses_carry_no_fake_cue() -> void:
	var run: Dictionary = await _round(BattleTestKit.setup_for(_data(), "grunt_solo", 3), [ATTACK_E1])
	var action: Dictionary = ((run["log"] as BattleTestKit.Recorder).of("action_started")[0]["args"] as Array)[0]
	var press: Dictionary = (action["presses"] as Array)[0]
	assert_eq(press["scrambled"], false)
	assert_false(press.has("shown_cue_ms"))
