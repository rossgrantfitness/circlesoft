extends TestCase
## M2-4: Burnt Toast, Noise Ticket, Wobbly, Stunned and Down for the Count, each by themselves.

const DEFEND: Dictionary = {"kind": "defend"}
const ATTACK_E1: Dictionary = {"kind": "attack", "targets": ["e1"]}


func _data() -> BattleData:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	(data.formulas["damage"] as Dictionary)["variance_pct"] = 0
	for enemy_id: String in data.enemies:
		data.enemy(enemy_id).erase("flee_at_hp_pct")
		(data.enemy(enemy_id)["stats"] as Dictionary)["attack"] = 1
		(data.enemy(enemy_id)["stats"] as Dictionary)["hp"] = 5000
	return data


func _play(setup: BattleSetup, commands: Array[Dictionary], fallback: Dictionary, limit: int) -> Dictionary:
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.queue = commands.duplicate()
	source.fallback = fallback
	source.limit = limit
	setup.command_source = source
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	await controller.start()
	return {"controller": controller, "log": log}


func _status_events(log: BattleTestKit.Recorder, id: String, status_id: String) -> Array:
	var out: Array = []
	for e: Dictionary in log.of("status_changed"):
		var args: Array = e["args"]
		if args[0] == id and args[1] == status_id:
			out.append(args[2])
	return out


# ---- Burnt Toast ----

func test_burnt_toast_costs_hp_at_the_start_of_each_turn_for_three_turns() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["statuses"] = ["burnt_toast"]
	var run: Dictionary = await _play(setup, [], DEFEND, 12)
	var log: BattleTestKit.Recorder = run["log"]
	var ticks: Array[Dictionary] = []
	for info: Dictionary in log.hits():
		if info["status"] == "burnt_toast" if info.has("status") else false:
			ticks.append(info)
	assert_eq(ticks.size(), 3, "three of Red's turns")
	var expected: int = maxi(int(round(53.0 * 8.0 / 100.0)), 2)
	for tick: Dictionary in ticks:
		assert_eq(int(tick["amount"]), expected, "8% of 53, at least 2")
		assert_eq(tick["target"], "red")
		assert_eq(tick["source"], "")
		assert_eq(tick["kind"], "damage")
	assert_eq(_status_events(log, "red", "burnt_toast"), [false], "it wears off after the third turn")


func test_burnt_toast_cannot_knock_anyone_out() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["statuses"] = ["burnt_toast"]
	setup.party[0]["hp"] = 3
	var run: Dictionary = await _play(setup, [], DEFEND, 12)
	var log: BattleTestKit.Recorder = run["log"]
	var tick_pending: bool = false
	var after_ticks: Array[int] = []
	for e: Dictionary in log.events:
		var args: Array = e["args"]
		if e["name"] == "hit" and (args[0] as Dictionary).get("status", "") == "burnt_toast":
			tick_pending = true
		elif e["name"] == "stats_changed" and tick_pending and args[0] == "red":
			after_ticks.append(int(args[1]))
			tick_pending = false
	assert_gt(float(after_ticks.size()), 0.0, "it ticked")
	for hp: int in after_ticks:
		assert_ge(float(hp), 1.0, "burnt toast never takes the last HP")
	assert_eq(after_ticks[0], 1, "3 HP, 2 lost to the first tick, then it stops short of the last point")


func test_a_burnt_enemy_loses_hp_too() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.bag["hot_sauce_bomb"] = 1
	var run: Dictionary = await _play(setup, [{"kind": "item", "item_id": "hot_sauce_bomb", "targets": ["e1"]}], DEFEND, 9)
	var log: BattleTestKit.Recorder = run["log"]
	assert_eq(_status_events(log, "e1", "burnt_toast"), [true, false])
	var ticks: int = 0
	for info: Dictionary in log.hits():
		if info.get("status", "") == "burnt_toast" and info["target"] == "e1":
			ticks += 1
	assert_eq(ticks, 3)


# ---- Noise Ticket ----

func test_noise_ticket_greys_out_skills_and_refuses_them() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["statuses"] = ["noise_ticket"]
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	var options: Dictionary = (log.of("command_needed")[0]["args"] as Array)[1]
	for entry: Dictionary in options["skills"]:
		assert_eq(entry["usable"], false, "%s is blocked" % entry["id"])
	assert_eq(options["attack"], true, "Attack still works")
	controller.submit_command({"kind": "skill", "skill_id": "double_swing", "targets": ["e1"]})
	assert_has(log.messages(), "Noise Ticket! No skills.")
	assert_eq(log.count("action_started"), 0)
	controller.submit_command(ATTACK_E1)
	assert_eq(log.count("action_started"), 1, "a plain attack is fine")
	controller.submit_command({"kind": "item", "item_id": "ration_bar", "targets": ["red"]})
	controller.abort()


func test_noise_ticket_wears_off_after_three_turns_and_skills_return() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["statuses"] = ["noise_ticket"]
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	for turn: int in 9:
		controller.submit_command(DEFEND)
	var red_menus: Array[bool] = []
	for e: Dictionary in log.of("command_needed"):
		var args: Array = e["args"]
		if args[0] == "red":
			red_menus.append(((args[1] as Dictionary)["skills"] as Array)[0]["usable"])
	assert_eq(red_menus.slice(0, 4), [false, false, false, true], "blocked on turns 1 to 3, back on turn 4")
	assert_eq(_status_events(log, "red", "noise_ticket"), [false])
	controller.abort()


func test_the_grunts_ticket_lands_and_comes_from_the_data() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["attack"] = 13
	data.enemy("signals_grunt")["ai"] = [{"skill": "grunt_write_ticket", "weight": 1}]
	var skill: Dictionary = data.skill("grunt_write_ticket")
	((skill["effects"] as Array)[0] as Dictionary)["statuses"] = [{"id": "noise_ticket", "chance": 1.0}]
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var run: Dictionary = await _play(setup, [], DEFEND, 3)
	var landed: Array = []
	for e: Dictionary in (run["log"] as BattleTestKit.Recorder).of("status_changed"):
		if (e["args"] as Array)[1] == "noise_ticket" and (e["args"] as Array)[2] == true:
			landed.append((e["args"] as Array)[0])
	assert_eq(landed.size(), 1)
	assert_has(["red", "otis", "mox"], landed[0])


# ---- Wobbly ----

func test_a_wobbly_fighter_sometimes_hits_the_wrong_target() -> void:
	var targets_seen: Dictionary = {}
	for seed: int in 40:
		var data: BattleData = _data()
		(data.status("wobbly") as Dictionary)["random_target_chance"] = 1.0
		var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3, seed)
		setup.party[0]["statuses"] = ["wobbly"]
		var run: Dictionary = await _play(setup, [ATTACK_E1], DEFEND, 1)
		for info: Dictionary in (run["log"] as BattleTestKit.Recorder).hits():
			if info["source"] == "red":
				targets_seen[info["target"]] = true
	assert_true(targets_seen.has("otis") or targets_seen.has("mox"), "Red sometimes hits a friend")
	assert_true(targets_seen.has("e2") or targets_seen.has("e3") or targets_seen.has("e4"), "or a different enemy")
	assert_false(targets_seen.has("red"), "never herself")


func test_a_wobbly_fighter_with_zero_chance_aims_straight() -> void:
	for seed: int in 15:
		var data: BattleData = _data()
		(data.status("wobbly") as Dictionary)["random_target_chance"] = 0.0
		var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3, seed)
		setup.party[0]["statuses"] = ["wobbly"]
		var run: Dictionary = await _play(setup, [ATTACK_E1], DEFEND, 1)
		for info: Dictionary in (run["log"] as BattleTestKit.Recorder).hits():
			if info["source"] == "red":
				assert_eq(info["target"], "e1")


func test_a_wobbly_enemy_can_hit_its_own_side_and_a_friend_cannot_block() -> void:
	var friendly_fire: Array[Dictionary] = []
	var any_blockable_press: bool = false
	for seed: int in 40:
		var data: BattleData = _data()
		(data.status("wobbly") as Dictionary)["random_target_chance"] = 1.0
		(data.enemy("signals_grunt")["stats"] as Dictionary)["attack"] = 30
		var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3, seed)
		var controller: BattleController = BattleController.create(setup)
		controller.state.get_c("e1").statuses["wobbly"] = 3
		var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
		source.fallback = DEFEND
		source.limit = 3
		setup.command_source = source
		setup.press_source = BattleTestKit.FixedPressSource.new(0.0)
		var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
		await controller.start()
		var enemy_ids: Array = ["e1", "e2", "e3", "e4"]
		for e: Dictionary in log.of("action_started"):
			var action: Dictionary = (e["args"] as Array)[0]
			if action["actor"] == "e1" and enemy_ids.has((action["targets"] as Array)[0]):
				assert_eq((action["presses"] as Array).size(), 0, "nobody to press for a hit between enemies")
		for info: Dictionary in log.hits():
			if info["source"] == "e1" and enemy_ids.has(info["target"]):
				friendly_fire.append(info)
				assert_eq(info["blocked"], "none")
	assert_gt(float(friendly_fire.size()), 0.0, "a wobbly grunt hit its own side at least once")
	assert_false(any_blockable_press)


# ---- Stunned ----

func test_a_stunned_fighter_skips_exactly_one_turn() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["statuses"] = ["stunned"]
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	assert_has(log.messages(), "Stunned! Skips the turn.")
	assert_eq((log.of("command_needed")[0]["args"] as Array)[0], "mox", "Red's turn was skipped, so Mox is first to be asked")
	for turn: int in 4:
		controller.submit_command(DEFEND)
	var red_asks: int = 0
	for e: Dictionary in log.of("command_needed"):
		if (e["args"] as Array)[0] == "red":
			red_asks += 1
	assert_ge(red_asks, 1, "Red is back in the second round")
	assert_eq(_status_events(log, "red", "stunned"), [false])
	controller.abort()


# ---- Down for the Count ----

func test_a_fighter_at_zero_hp_is_down_loses_statuses_and_is_skipped() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["attack"] = 80
	data.enemy("signals_grunt")["ai"] = [{"skill": "grunt_bonk", "weight": 1, "pick": "lowest_hp"}]
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[2]["hp"] = 5
	setup.party[2]["statuses"] = ["wobbly"]
	var run: Dictionary = await _play(setup, [], DEFEND, 6)
	var log: BattleTestKit.Recorder = run["log"]
	assert_has(log.first_args("combatant_down"), "mox")
	assert_eq(_status_events(log, "mox", "wobbly"), [false], "statuses clear when you go down")
	var mox: BattleCombatant = (run["controller"] as BattleController).state.get_c("mox")
	assert_true(mox.down)
	assert_eq(mox.hp, 0)
	var rounds: Array = log.of("round_started")
	assert_ge(rounds.size(), 2)
	assert_false(((rounds[1]["args"] as Array)[1] as Array).has("mox"), "a Down fighter is not in the next round's order")
	assert_false(((rounds[1]["args"] as Array)[2] as Array).has("mox"))


func test_enemies_do_not_target_a_downed_fighter() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["attack"] = 2
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_pair", 3)
	setup.party[0]["hp"] = 0
	setup.party[1]["hp"] = 0
	var run: Dictionary = await _play(setup, [], DEFEND, 12)
	for info: Dictionary in (run["log"] as BattleTestKit.Recorder).hits():
		if info["source"] in ["e1", "e2"]:
			assert_eq(info["target"], "mox", "only Mox is still standing")


func test_all_down_is_game_over() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["attack"] = 300
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_pair", 1)
	var run: Dictionary = await _play(setup, [], DEFEND, -1)
	assert_eq((run["controller"] as BattleController).result, "lose")
	assert_eq((run["log"] as BattleTestKit.Recorder).count("combatant_down"), 3)
	assert_eq((run["log"] as BattleTestKit.Recorder).first_args("battle_ended")[0], "lose")


func test_a_downed_fighter_can_be_revived_and_rejoins_the_order() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[1]["hp"] = 0
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "item", "item_id": "smelling_salts", "targets": ["otis"]})
	for turn: int in 4:
		controller.submit_command(DEFEND)
	var rounds: Array = log.of("round_started")
	assert_false(((rounds[0]["args"] as Array)[1] as Array).has("otis"), "Down in round 1")
	assert_true(((rounds[1]["args"] as Array)[1] as Array).has("otis"), "back in round 2")
	controller.abort()


# ---- landing chance (pure) ----

func test_status_landing_chance_rules() -> void:
	var data: BattleData = _data()
	assert_almost_eq(BattleStatusRules.landing_chance(data, 1.0, 5.0, 5.0, 0.0), 1.0, 0.0001, "guaranteed means guaranteed")
	assert_almost_eq(BattleStatusRules.landing_chance(data, 1.0, 5.0, 5.0, 1.0), 0.0, 0.0001, "unless immune")
	assert_almost_eq(BattleStatusRules.landing_chance(data, 1.0, 5.0, 5.0, 0.5), 0.5, 0.0001)
	assert_almost_eq(BattleStatusRules.landing_chance(data, 0.5, 5.0, 5.0, 0.0), 0.5, 0.0001)
	assert_gt(BattleStatusRules.landing_chance(data, 0.5, 15.0, 5.0, 0.0), 0.5, "more Luck on the attacker helps")
	assert_lt(BattleStatusRules.landing_chance(data, 0.5, 5.0, 15.0, 0.0), 0.5, "more Luck on the target hurts")
	assert_le(BattleStatusRules.landing_chance(data, 0.9, 500.0, 0.0, 0.0), data.f("status", "max_chance", 1.0))
	assert_ge(BattleStatusRules.landing_chance(data, 0.5, 0.0, 500.0, 0.0), data.f("status", "min_chance", 0.0))


func test_resist_makes_an_enemy_immune() -> void:
	for seed: int in 20:
		var data: BattleData = _data()
		data.enemy("signals_grunt")["status_resist"] = {"wobbly": 1.0}
		var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3, seed)
		var run: Dictionary = await _play(setup, [{"kind": "skill", "skill_id": "porch_light", "targets": ["e1"]}], DEFEND, 1)
		assert_eq(_status_events(run["log"], "e1", "wobbly"), [], "immune")


func test_tick_damage_math() -> void:
	var data: BattleData = _data()
	var c: BattleCombatant = BattleCombatant.new()
	c.hp_max = 100
	c.hp = 100
	c.statuses["burnt_toast"] = 3
	assert_eq(BattleStatusRules.tick_damage(data, c), 8)
	c.hp_max = 10
	c.hp = 10
	assert_eq(BattleStatusRules.tick_damage(data, c), 2, "never less than the minimum")
	c.hp = 2
	assert_eq(BattleStatusRules.tick_damage(data, c), 1, "cannot take the last HP")
	c.hp = 1
	assert_eq(BattleStatusRules.tick_damage(data, c), 0)
	c.statuses.clear()
	assert_eq(BattleStatusRules.tick_damage(data, c), 0)
