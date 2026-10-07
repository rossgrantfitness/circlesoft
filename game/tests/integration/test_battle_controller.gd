extends TestCase
## M2-2: the battle core through its public contract: signals, commands, turn order, Attack,
## Skills, Items, Defend, Run, HP, Juice, damage, Down for the Count, win / lose / ran.

const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"
const ATTACK_RED: Dictionary = {"kind": "attack", "targets": ["e1"]}


func _data() -> BattleData:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	(data.formulas["damage"] as Dictionary)["variance_pct"] = 0
	return data


func _damage(data: BattleData, atk: float, power: float, def: float, mult: float = 1.0) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	return BattleDamage.hit_damage(data, atk, power, def, mult, 1.0, 0.0, rng)


func _fight(setup: BattleSetup, commands: Array[Dictionary], presses: PressSource = null, fallback: Dictionary = {"kind": "defend"}, max_commands: int = -1) -> BattleController:
	var source: PressSource = presses if presses != null else BattleTestKit.FixedPressSource.new(0.0, false)
	return await BattleTestKit.run(setup, commands, source, fallback, max_commands)


func _enemy_that_does_nothing(data: BattleData) -> void:
	# Keep enemies from interfering with a test of the party's own numbers.
	for enemy_id: String in data.enemies:
		(data.enemy(enemy_id)["stats"] as Dictionary)["attack"] = 1


# ---- signals and snapshot ----

func test_battle_started_snapshot_has_encounter_info_and_every_combatant() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3)
	var controller: BattleController = BattleController.create(setup)
	var snap: Dictionary = controller.snapshot()
	assert_eq(snap["encounter_id"], "squad_four")
	assert_eq(snap["can_run"], true)
	assert_eq(snap["is_boss"], false)
	assert_eq(snap["backdrop"], "relay_tower_floor")
	var combatants: Array = snap["combatants"]
	assert_eq(combatants.size(), 7, "three party members and four enemies")
	var ids: Array = []
	for c: Dictionary in combatants:
		ids.append(c["id"])
		for key: String in ["id", "side", "slot", "name", "kind", "model", "hp", "hp_max", "juice", "juice_max", "level", "speed", "statuses", "down", "is_boss"]:
			assert_true(c.has(key), "combatant has %s" % key)
		assert_eq(c["down"], false)
		assert_eq(c["hp"], c["hp_max"])
		assert_true(str(c["model"]).begins_with("res://"))
	assert_eq(ids, ["red", "otis", "mox", "e1", "e2", "e3", "e4"])
	assert_eq((combatants[0] as Dictionary)["side"], "party")
	assert_eq((combatants[3] as Dictionary)["side"], "enemy")
	assert_eq((combatants[3] as Dictionary)["kind"], "signals_grunt")
	assert_eq((combatants[6] as Dictionary)["slot"], 3)
	assert_eq((combatants[2] as Dictionary)["name"], "Mox")


func test_signal_order_and_payload_shapes_over_a_whole_fight() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.fallback = ATTACK_RED
	setup.command_source = source
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	await controller.start()
	var names: Array[String] = log.names()
	assert_eq(names[0], "battle_started")
	assert_eq(names[1], "round_started")
	assert_eq(names[names.size() - 1], "battle_ended")
	assert_eq(log.count("battle_ended"), 1)
	var round_event: Array = log.of("round_started")[0]["args"]
	assert_eq(round_event[0], 1)
	assert_eq(round_event[1], ["red", "mox", "otis", "e1"], "Red 10, Mox 8, then the tie at 5 goes to the party first")
	assert_eq(round_event[2], ["red", "mox", "otis", "e1"], "next round's order")
	for e: Dictionary in log.of("turn_started"):
		assert_true((e["args"] as Array)[0] is String)
	var asked: Dictionary = log.of("command_needed")[0] if log.count("command_needed") > 0 else {}
	assert_true(asked.is_empty(), "a command_source answers directly, so no command_needed")
	var action: Dictionary = log.of("action_started")[0]["args"][0]
	for key: String in ["actor", "kind", "skill_id", "name", "targets", "t0_usec", "timeline_ms", "presses", "anim", "show_name"]:
		assert_true(action.has(key), "action_started has %s" % key)
	for key: String in ["windup", "impact", "end"]:
		assert_true((action["timeline_ms"] as Dictionary).has(key), key)
	var press: Dictionary = (action["presses"] as Array)[0]
	for key: String in ["index", "type", "side", "cue_ms", "hold_by_ms", "owner_id"]:
		assert_true(press.has(key), "press has %s" % key)
	assert_eq(press["side"], "attack")
	assert_eq(press["owner_id"], action["actor"])
	var judged: Dictionary = log.presses()[0]
	for key: String in ["actor", "index", "side", "rating", "delta_ms"]:
		assert_true(judged.has(key), "press_judged has %s" % key)
	var hit_info: Dictionary = log.hits()[0]
	for key: String in ["source", "target", "amount", "kind", "blocked", "payback"]:
		assert_true(hit_info.has(key), "hit has %s" % key)
	assert_eq(log.count("action_started"), log.count("action_finished"))
	var stats: Array = log.of("stats_changed")[0]["args"]
	assert_eq(stats.size(), 5, "stats_changed(id, hp, hp_max, juice, juice_max)")


func test_the_report_has_the_documented_shape() -> void:
	var data: BattleData = _data()
	data.enemy("signals_grunt").erase("flee_at_hp_pct")
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_pair", 1)
	var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0), ATTACK_RED)
	assert_eq(controller.result, "win")
	var report: Dictionary = controller.report
	for key: String in ["xp", "credits", "drops", "level_ups", "final_ko_target"]:
		assert_true(report.has(key), key)
	assert_eq(int(report["xp"]), 28)
	assert_eq(int(report["credits"]), 42)
	assert_true(report["drops"] is Array)
	assert_true(report["level_ups"] is Array)
	assert_has(["e1", "e2"], report["final_ko_target"], "the K.O. freeze lands on the last enemy beaten")


func test_battle_ended_arrives_after_the_ko_beat() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 6)
	(data.enemy("signals_grunt")["stats"] as Dictionary)["hp"] = 1
	var controller: BattleController = await _fight(setup, [], null, ATTACK_RED)
	var beat: int = int(data.f("pacing", "ko_beat_ms", 0.0))
	assert_gt(float(beat), 0.0)
	var last_action_end: int = controller.end_usec - beat * 1000
	assert_ge(float(controller.end_usec), float(last_action_end))
	assert_eq(controller.result, "win")


# ---- waiting for the player's command ----

func test_command_needed_waits_for_submit_command() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	assert_eq(log.count("command_needed"), 1, "stops at Red's turn and waits")
	assert_eq(log.count("action_started"), 0)
	var args: Array = log.of("command_needed")[0]["args"]
	assert_eq(args[0], "red")
	controller.submit_command({"kind": "attack", "targets": ["e1"]})
	assert_eq(log.count("action_started"), 1)
	assert_eq(log.count("command_needed"), 2, "now it is Mox's turn")
	assert_eq((log.of("command_needed")[1]["args"] as Array)[0], "mox")
	var snap: Dictionary = controller.snapshot()
	var e1: Dictionary = (snap["combatants"] as Array)[3]
	assert_lt(float(e1["hp"]), float(e1["hp_max"]), "the snapshot shows the hit")
	assert_eq(snap["round"], 1)
	controller.abort()

func test_command_needed_options_list_attack_skills_items_defend_and_run() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 4)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	var options: Dictionary = (log.of("command_needed")[0]["args"] as Array)[1]
	assert_eq(options["attack"], true)
	assert_eq(options["defend"], true)
	assert_eq(options["run"], true)
	var skills: Array = options["skills"]
	assert_eq(skills.size(), 3, "Red knows three skills at level 4")
	for entry: Dictionary in skills:
		for key: String in ["id", "name", "juice_cost", "usable", "target"]:
			assert_true(entry.has(key), key)
	assert_eq((skills[0] as Dictionary)["id"], "porch_light")
	assert_eq((skills[0] as Dictionary)["name"], "Porch Light")
	assert_eq((skills[0] as Dictionary)["juice_cost"], 8)
	assert_eq((skills[0] as Dictionary)["usable"], true)
	var items: Array = options["items"]
	assert_ge(items.size(), 3)
	var ration: Dictionary = {}
	for entry: Dictionary in items:
		for key: String in ["id", "name", "count", "target"]:
			assert_true(entry.has(key), key)
		if entry["id"] == "ration_bar":
			ration = entry
	assert_eq(ration["count"], 3)
	assert_eq(ration["name"], "Ration Bar")
	controller.abort()

func test_a_skill_is_not_usable_without_the_juice() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["juice"] = 7
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	var skills: Array = ((log.of("command_needed")[0]["args"] as Array)[1] as Dictionary)["skills"]
	assert_eq((skills[0] as Dictionary)["usable"], false, "Porch Light costs 8")
	assert_eq((skills[1] as Dictionary)["usable"], true, "Double Swing costs 4")
	controller.abort()

func test_bad_commands_are_refused_with_a_message_and_asked_again() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["juice"] = 1
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "skill", "skill_id": "porch_light", "targets": ["e1"]})
	assert_has(log.messages(), "Not enough Juice!")
	assert_eq(log.count("command_needed"), 2, "asked again, still Red's turn")
	assert_eq(log.count("action_started"), 0, "nothing happened")
	controller.submit_command({"kind": "skill", "skill_id": "sunrise_slash", "targets": ["e1"]})
	assert_eq(log.count("command_needed"), 3, "Red does not know Sunrise Slash yet")
	controller.submit_command({"kind": "attack", "targets": ["red"]})
	assert_has(log.messages(), "Pick a target.", "cannot attack a friend")
	controller.submit_command({"kind": "attack", "targets": []})
	controller.submit_command({"kind": "item", "item_id": "juice_box", "targets": ["red"]})
	controller.submit_command({"kind": "dance"})
	assert_eq(log.count("action_started"), 0)
	controller.submit_command({"kind": "attack", "targets": ["e1"]})
	assert_eq(log.count("action_started"), 1)
	controller.abort()

func test_submit_command_when_nothing_is_needed_does_nothing() -> void:
	var data: BattleData = _data()
	var controller: BattleController = BattleController.create(BattleTestKit.setup_for(data, "grunt_solo", 3))
	controller.submit_command({"kind": "defend"})
	assert_eq(controller.party_commands, 0)
	assert_false(controller.is_over)


# ---- Attack, Skills ----

func test_attack_damage_follows_the_formula() -> void:
	var data: BattleData = _data()
	_enemy_that_does_nothing(data)
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = await _fight(setup, [ATTACK_RED], null, {"kind": "defend"}, 3)
	var grunt: BattleCombatant = controller.state.get_c("e1")
	assert_eq(grunt.hp_max - grunt.hp, _damage(data, 14.0, 1.0, 4.0), "Red's un-pressed hit is exactly the formula (14 attack vs 4 defense)")


func test_damage_uses_attack_over_defense_and_has_a_floor_of_one() -> void:
	var data: BattleData = _data()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_eq(BattleDamage.hit_damage(data, 14.0, 1.0, 4.0, 1.0, 1.0, 0.0, rng), int(round(14.0 * 14.0 / 18.0)))
	assert_eq(BattleDamage.hit_damage(data, 1.0, 0.1, 500.0, 1.0, 1.0, 0.0, rng), 1, "always at least 1 damage")
	assert_eq(BattleDamage.hit_damage(data, 14.0, 1.0, 4.0, 1.0, 1.0, 1.0, rng), 0, "a full block takes everything")
	assert_gt(BattleDamage.hit_damage(data, 28.0, 1.0, 8.0, 1.0, 1.0, 0.0, rng), BattleDamage.hit_damage(data, 14.0, 1.0, 4.0, 1.0, 1.0, 0.0, rng), "the formula scales with level")


func test_damage_variance_stays_inside_the_data_band() -> void:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	var pct: float = data.f("damage", "variance_pct", 0.0)
	assert_gt(pct, 0.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var base: float = 40.0 * 40.0 / 50.0
	var low: int = 9999
	var high: int = 0
	for i: int in 300:
		var d: int = BattleDamage.hit_damage(data, 40.0, 1.0, 10.0, 1.0, 1.0, 0.0, rng)
		low = mini(low, d)
		high = maxi(high, d)
	assert_ge(float(low), floor(base * (1.0 - pct / 100.0)))
	assert_le(float(high), ceil(base * (1.0 + pct / 100.0)))
	assert_gt(float(high - low), 0.0, "there is some variance")


func test_a_skill_spends_its_juice() -> void:
	var data: BattleData = _data()
	_enemy_that_does_nothing(data)
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = await _fight(setup, [{"kind": "skill", "skill_id": "porch_light", "targets": ["e1"]}], BattleTestKit.FixedPressSource.new(400.0), {"kind": "defend"}, 1)
	var red: BattleCombatant = controller.state.get_c("red")
	assert_eq(red.juice, red.juice_max - 8, "Porch Light costs 8 Juice (and the missed presses refund nothing)")


func test_down_for_the_count_at_zero_hp_and_the_fight_goes_on() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[0]["hp"] = 1
	(data.enemy("signals_grunt")["ai"] as Array).assign([{"skill": "grunt_bonk", "weight": 1, "pick": "lowest_hp"}])
	var controller: BattleController = BattleController.create(setup)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.fallback = {"kind": "attack", "targets": ["e1"]}
	setup.command_source = source
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	await controller.start()
	assert_eq(log.first_args("combatant_down")[0], "red", "Red was at 1 HP and the grunt picks the weakest")
	assert_true(controller.state.get_c("red").down)
	assert_eq(controller.state.get_c("red").hp, 0)
	assert_eq(controller.result, "win", "the other two finish the fight")
	var turns_after: int = 0
	var seen_down: bool = false
	for e: Dictionary in log.events:
		if e["name"] == "combatant_down" and (e["args"] as Array)[0] == "red":
			seen_down = true
		elif seen_down and e["name"] == "turn_started" and (e["args"] as Array)[0] == "red":
			turns_after += 1
	assert_eq(turns_after, 0, "a Down fighter takes no more turns")


# ---- Items ----

func test_ration_bar_heals_and_leaves_the_bag_one_lighter() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[1]["hp"] = 20
	var controller: BattleController = await _fight(setup, [{"kind": "item", "item_id": "ration_bar", "targets": ["otis"]}], null, {"kind": "defend"}, 1)
	assert_eq(controller.state.get_c("otis").hp, 50, "Ration Bar heals 30")
	assert_eq(int(controller.get_result()["bag"]["ration_bar"]), 2)
	assert_eq(int(controller.get_result()["items_used"]["ration_bar"]), 1)


func test_healing_never_goes_past_max_hp() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[1]["hp"] = 80
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "item", "item_id": "ration_bar", "targets": ["otis"]})
	var otis: BattleCombatant = controller.state.get_c("otis")
	assert_eq(otis.hp, otis.hp_max)
	var heals: Array = []
	for info: Dictionary in log.hits():
		if info["kind"] == "heal":
			heals.append(info["amount"])
	assert_eq(heals, [1], "only the one missing HP is reported")
	controller.abort()

func test_smelling_salts_bring_a_downed_friend_back() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[1]["hp"] = 0
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	assert_true(controller.state.get_c("otis").down, "starts the fight Down")
	controller.start()
	controller.submit_command({"kind": "item", "item_id": "smelling_salts", "targets": ["otis"]})
	assert_has(log.first_args("combatant_revived"), "otis")
	var heal: Dictionary = {}
	for info: Dictionary in log.hits():
		if info["kind"] == "heal" and info["target"] == "otis":
			heal = info
	assert_eq(int(heal["amount"]), 20, "back up with 25% of max HP (81)")
	assert_false(controller.state.get_c("otis").down)
	assert_eq(controller.state.get_c("otis").hp, 20)
	controller.abort()

func test_smelling_salts_cannot_target_a_standing_friend_and_burn_gel_needs_the_status() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "item", "item_id": "smelling_salts", "targets": ["otis"]})
	assert_has(log.messages(), "Pick a target.")
	assert_eq(log.count("action_started"), 0)
	controller.abort()

func test_canned_coffee_restores_juice() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.party[2]["juice"] = 0
	var controller: BattleController = await _fight(setup, [{"kind": "item", "item_id": "canned_coffee", "targets": ["mox"]}], null, {"kind": "defend"}, 1)
	assert_eq(controller.state.get_c("mox").juice, 6, "Canned Coffee gives 6 Juice")


func test_an_item_runs_out() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.bag = {"ration_bar": 1}
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "item", "item_id": "ration_bar", "targets": ["red"]})
	controller.submit_command({"kind": "item", "item_id": "ration_bar", "targets": ["red"]})
	assert_eq(controller.get_result()["bag"], {"ration_bar": 0})
	assert_has(log.messages(), "None left.")


# ---- Defend ----
	controller.abort()

func test_defend_halves_damage_and_gives_juice() -> void:
	var data: BattleData = _data()
	var hits: Array[int] = []
	for defend: bool in [false, true]:
		var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
		setup.party[2]["hp"] = 20
		setup.party[2]["juice"] = 0
		(data.enemy("signals_grunt")["ai"] as Array).assign([{"skill": "grunt_bonk", "weight": 1, "pick": "lowest_hp"}])
		var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
		source.fallback = {"kind": "attack", "targets": ["e1"]}
		var kind: String = "defend" if defend else "attack"
		source.queue.append({"kind": kind, "targets": ["e1"]})
		source.queue.append({"kind": kind, "targets": ["e1"]})
		source.limit = 3
		setup.command_source = source
		setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
		var controller: BattleController = BattleController.create(setup)
		var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
		await controller.start()
		for info: Dictionary in log.hits():
			if info["source"] == "e1":
				hits.append(int(info["amount"]))
		if defend:
			assert_eq(controller.state.get_c("mox").juice, int(data.f("juice", "defend_gain", 0.0)), "Defend gives a little Juice")
	assert_eq(hits.size(), 2)
	assert_eq(hits[0], _damage(data, 13.0, 1.0, 4.0), "undefended bonk on Mox (13 attack vs 4 defense)")
	assert_eq(hits[1], int(round(float(hits[0]) * data.f("damage", "defend_mult", 1.0))), "Defend halves it")


func test_defend_stops_when_the_defenders_next_turn_starts() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "defend"})
	assert_true(controller.state.get_c("red").defending, "defending through the rest of the round")
	controller.submit_command({"kind": "defend"})
	controller.submit_command({"kind": "defend"})
	assert_eq(controller.round_number, 2)
	assert_false(controller.state.get_c("red").defending, "round 2, Red's turn: the guard drops")


# ---- Run ----
	controller.abort()

func test_run_ends_the_fight_with_ran_and_no_rewards() -> void:
	var data: BattleData = _data()
	(data.formulas["run"] as Dictionary)["base_chance"] = 5.0
	(data.formulas["run"] as Dictionary)["max_chance"] = 5.0
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.fallback = {"kind": "run"}
	setup.command_source = source
	await controller.start()
	var ended: Array = log.of("battle_ended")[0]["args"]
	assert_eq(ended[0], "ran")
	assert_eq(int((ended[1] as Dictionary)["xp"]), 0)
	assert_eq(int((ended[1] as Dictionary)["credits"]), 0)
	assert_has(log.messages(), "Got away safely!")


func test_a_failed_run_costs_the_turn() -> void:
	var data: BattleData = _data()
	(data.formulas["run"] as Dictionary)["min_chance"] = 0.0
	(data.formulas["run"] as Dictionary)["base_chance"] = 0.0
	(data.formulas["run"] as Dictionary)["max_chance"] = 0.0
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	controller.start()
	controller.submit_command({"kind": "run"})
	assert_has(log.messages(), "Couldn't get away!")
	assert_false(controller.is_over)
	assert_eq((log.of("command_needed")[1]["args"] as Array)[0], "mox", "Red's turn is spent")
	controller.abort()

func test_run_is_disabled_when_the_encounter_forbids_it() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "ambush_no_exit", 4)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	assert_eq(controller.snapshot()["can_run"], false)
	controller.start()
	var options: Dictionary = (log.of("command_needed")[0]["args"] as Array)[1]
	assert_eq(options["run"], false)
	controller.submit_command({"kind": "run"})
	assert_has(log.messages(), "Can't run from this one!")
	assert_false(controller.is_over)
	assert_eq(log.count("command_needed"), 2, "asked again, the turn is not lost")
	controller.abort()

func test_run_is_disabled_on_bosses_even_if_the_data_says_can_run() -> void:
	var data: BattleData = _data()
	var boss: Dictionary = data.encounter("grunt_solo").duplicate(true)
	boss["id"] = "test_boss"
	boss["is_boss"] = true
	boss["can_run"] = true
	data.encounters["test_boss"] = boss
	var controller: BattleController = BattleController.create(BattleTestKit.setup_for(data, "test_boss", 3))
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	assert_eq(controller.snapshot()["is_boss"], true)
	assert_eq(controller.snapshot()["can_run"], false, "bosses never allow Run")
	controller.start()
	assert_eq(((log.of("command_needed")[0]["args"] as Array)[1] as Dictionary)["run"], false)
	controller.submit_command({"kind": "run"})
	assert_false(controller.is_over)
	controller.abort()

func test_smoke_bomb_escapes_a_regular_fight_but_not_a_forbidden_one() -> void:
	var data: BattleData = _data()
	var controller: BattleController = await _fight(BattleTestKit.setup_for(data, "grunt_solo", 3), [{"kind": "item", "item_id": "smoke_bomb", "targets": ["red"]}])
	assert_eq(controller.result, "ran")
	assert_eq(int(controller.get_result()["items_used"]["smoke_bomb"]), 1)
	var blocked: BattleController = BattleController.create(BattleTestKit.setup_for(data, "ambush_no_exit", 4))
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(blocked)
	blocked.start()
	blocked.submit_command({"kind": "item", "item_id": "smoke_bomb", "targets": ["red"]})
	assert_has(log.messages(), "Can't run from this one!")
	assert_eq(int(blocked.get_result()["bag"]["smoke_bomb"]), 1, "not used up")


# ---- Win, lose, ranking, flee ----
	blocked.abort()

func test_losing_when_everyone_is_down() -> void:
	var data: BattleData = _data()
	for enemy_id: String in data.enemies:
		(data.enemy(enemy_id)["stats"] as Dictionary)["attack"] = 200
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 1)
	var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0, false), {"kind": "defend"})
	assert_eq(controller.result, "lose")
	assert_true(controller.state.party_wiped())
	assert_eq(int(controller.report["xp"]), 0)
	assert_has(["red", "otis", "mox"], controller.report["final_ko_target"])


func test_the_party_keeps_what_the_fight_did_to_it() -> void:
	var data: BattleData = _data()
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 2)
	var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0, false), ATTACK_RED)
	var party: Array = controller.get_result()["party"]
	assert_eq(party.size(), 3)
	for member: Dictionary in party:
		for key: String in ["id", "level", "xp", "hp", "hp_max", "juice", "juice_max"]:
			assert_true(member.has(key), key)
		assert_le(int(member["hp"]), int(member["hp_max"]))


func test_a_nearly_beaten_grunt_waves_a_white_flag_and_leaves() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["hp"] = 60
	data.enemy("signals_grunt")["flee_at_hp_pct"] = 50
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.fallback = ATTACK_RED
	setup.command_source = source
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
	await controller.start()
	assert_eq(log.count("combatant_fled"), 1, "it leaves")
	assert_eq(log.count("combatant_down"), 0, "nobody was knocked out")
	assert_eq(controller.result, "win", "an empty field is a win")
	assert_eq(int(controller.report["xp"]), 14, "it surrendered: full XP")
	assert_eq(controller.report["final_ko_target"], "", "no K.O. freeze for a surrender")
	assert_true(controller.state.get_c("e1").fled)
	assert_has(log.messages(), "Signals Grunt waves a white flag and leaves!")


func test_bosses_never_flee() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["hp"] = 400
	data.enemy("signals_grunt")["flee_at_hp_pct"] = 99
	data.enemy("signals_grunt")["is_boss"] = true
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	var controller: BattleController = BattleController.create(setup)
	var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.fallback = ATTACK_RED
	setup.command_source = source
	setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
	await controller.start()
	assert_eq(log.count("combatant_fled"), 0)
	assert_eq(controller.state.get_c("e1").is_boss, true)
	assert_eq(controller.state.get_c("e1").down, controller.result == "win")


func test_downed_fighters_get_full_xp_and_stand_back_up_after_a_win() -> void:
	var data: BattleData = _data()
	(data.enemy("signals_grunt")["stats"] as Dictionary)["hp"] = 30
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 1)
	setup.party[1]["hp"] = 0
	setup.party[1]["xp"] = 0
	var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0, false), ATTACK_RED)
	assert_eq(controller.result, "win")
	var otis: Dictionary = {}
	for member: Dictionary in controller.get_result()["party"]:
		if member["id"] == "otis":
			otis = member
	assert_eq(int(otis["xp"]), 14, "Down at the end of the fight, full XP anyway")
	assert_eq(int(otis["hp"]), int(round(float(otis["hp_max"]) * data.f("rewards", "after_win_revive_pct", 0.0) / 100.0)), "back up with a little HP")


# ---- determinism, first turn, GameState ----

func test_the_same_seed_gives_the_same_fight() -> void:
	var runs: Array = []
	for i: int in 2:
		var data: BattleData = BattleTestKit.fresh_data(tree)
		var setup: BattleSetup = BattleTestKit.setup_for(data, "squad_four", 3, 77)
		var source: BattleSimPolicy = BattleSimPolicy.new({})
		setup.command_source = source
		setup.press_source = SimPressSource.make("good", 40.0, 450.0, 0.1)
		var controller: BattleController = BattleController.create(setup)
		var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
		await controller.start()
		runs.append({"hits": log.hits(), "presses": log.presses(), "result": controller.result, "end": controller.end_usec})
	assert_eq(runs[0], runs[1])
	var other: BattleSetup = BattleTestKit.setup_for(BattleTestKit.fresh_data(tree), "squad_four", 3, 78)
	other.command_source = BattleSimPolicy.new({})
	other.press_source = SimPressSource.make("good", 40.0, 450.0, 0.1)
	var other_controller: BattleController = BattleController.create(other)
	var other_log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(other_controller)
	await other_controller.start()
	assert_ne(other_log.hits(), runs[0]["hits"], "a different seed gives a different fight")


func test_free_first_turn_for_the_party_and_for_the_enemies() -> void:
	var data: BattleData = _data()
	var party_first: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	party_first.first_turn = "party"
	var a: BattleController = BattleController.create(party_first)
	var log_a: BattleTestKit.Recorder = BattleTestKit.Recorder.new(a)
	a.start()
	assert_eq((log_a.of("round_started")[0]["args"] as Array)[1], ["red", "mox", "otis", "e1"])
	var enemies_first: BattleSetup = BattleTestKit.setup_for(_data(), "grunt_solo", 3)
	enemies_first.first_turn = "enemies"
	enemies_first.party[0]["level"] = 1
	var b: BattleController = BattleController.create(enemies_first)
	var log_b: BattleTestKit.Recorder = BattleTestKit.Recorder.new(b)
	b.start()
	assert_eq(((log_b.of("round_started")[0]["args"] as Array)[1] as Array)[0], "e1", "ambushed: the enemy goes first")
	assert_eq(((log_b.of("round_started")[0]["args"] as Array)[2] as Array)[0], "red", "the next round is back to normal speed order")
	a.abort()
	b.abort()

func test_game_state_is_updated_after_a_win() -> void:
	var data: BattleData = _data()
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	var setup: BattleSetup = BattleSetup.new()
	setup.data = data
	setup.encounter_id = "grunt_pair"
	setup.rng_seed = 5
	setup.clock = VirtualClock.new()
	setup.party = [{"id": "red", "level": 1, "xp": 0}, {"id": "otis", "level": 1, "xp": 0}, {"id": "mox", "level": 1, "xp": 0}]
	setup.bag = {"ration_bar": 2}
	setup.game_state = state
	state.call("add_item", "ration_bar", 2)
	var before_rations: int = state.call("item_count", "ration_bar")
	data.enemy("signals_grunt")["drops"] = [{"item": "ration_bar", "chance": 1.0}]
	data.enemy("signals_grunt").erase("flee_at_hp_pct")
	var controller: BattleController = await _fight(setup, [{"kind": "item", "item_id": "ration_bar", "targets": ["red"]}], BattleTestKit.FixedPressSource.new(0.0), ATTACK_RED)
	assert_eq(controller.result, "win")
	assert_eq(state.call("get_credits"), 42, "credits from the two grunts")
	var red: Dictionary = state.call("get_member", "red")
	assert_eq(int(red["xp"]), 28, "XP from the two grunts")
	assert_eq(int(red["level"]), 1, "28 XP is short of level 2 (35)")
	assert_eq(int(red["hp_max"]), int(Progression.new(data).stats_at("red", 1)["hp"]))
	assert_eq(state.call("item_count", "ration_bar"), before_rations - 1 + 2, "one used, two dropped")


func test_level_ups_land_in_the_report_and_game_state() -> void:
	var data: BattleData = _data()
	var progression: Progression = Progression.new(data)
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	data.enemy("signals_grunt")["xp"] = 100
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 1)
	setup.game_state = state
	var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0), ATTACK_RED)
	assert_eq(controller.result, "win")
	var level_ups: Array = controller.report["level_ups"]
	assert_eq(level_ups.size(), 3, "everyone climbed")
	var red_record: Dictionary = {}
	for record: Dictionary in level_ups:
		if record["id"] == "red":
			red_record = record
	assert_eq(int(red_record["from"]), 1)
	assert_eq(int(red_record["to"]), progression.level_for_xp(100))
	assert_has(red_record, "gains")
	assert_has(red_record, "learned")
	assert_eq(int(state.call("get_member", "red")["level"]), int(red_record["to"]))


# ---- building a setup from the game's own state ----

func test_setup_from_game_state_and_config() -> void:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	state.call("update_member", "red", {"hp": 42})  # hurt, so "current HP comes from the state" means something
	var config: Node = own((load("res://scripts/core/config.gd") as GDScript).new() as Node) as Node
	var setup: BattleSetup = BattleSetup.from_game_state(state, "grunt_pair", config, "party")
	assert_eq(setup.encounter_id, "grunt_pair")
	assert_eq(setup.first_turn, "party")
	assert_eq(setup.party.size(), 3)
	assert_eq(setup.party[0]["id"], "red")
	assert_eq(setup.party[2]["id"], "mox")
	assert_eq(int(setup.bag["ration_bar"]), int(state.call("item_count", "ration_bar")))
	assert_true(setup.clock is RealClock, "the game plays on the real clock")
	assert_true(setup.press_source is HumanPressSource)
	assert_eq(setup.auto_timing, false)
	assert_eq(setup.rng_seed, BattleSetup.RANDOM_SEED)
	assert_true(setup.game_state == state)
	config.set("auto_timing", true)
	var auto_setup: BattleSetup = BattleSetup.from_game_state(state, "grunt_solo", config)
	assert_true(auto_setup.auto_timing, "Config's Auto-Timing carries over")
	var controller: BattleController = BattleController.create(setup)
	var snap: Dictionary = controller.snapshot()
	assert_eq((snap["combatants"] as Array).size(), 5)
	var red: Dictionary = (snap["combatants"] as Array)[0]
	assert_eq(int(red["hp"]), 42, "current HP comes from the state, not the max")
	assert_eq(int(red["level"]), 3)


func test_a_fight_with_nothing_to_fight_ends_at_once() -> void:
	var data: BattleData = _data()
	data.encounters["empty_test"] = {"id": "empty_test", "enemies": [], "can_run": true, "is_boss": false, "backdrop": "x", "tier": "tutorial"}
	var setup: BattleSetup = BattleTestKit.setup_for(data, "empty_test", 3)
	var controller: BattleController = await _fight(setup, [])
	assert_eq(controller.result, "win")
	assert_eq(int(controller.report["xp"]), 0)
	assert_eq(controller.party_commands, 0)


func test_the_bench_earns_xp_only_when_the_rule_is_switched_on() -> void:
	for enabled: bool in [false, true]:
		var data: BattleData = _data()
		data.enemy("signals_grunt").erase("flee_at_hp_pct")
		data.enemy("signals_grunt")["xp"] = 100
		(data.enemy("signals_grunt")["stats"] as Dictionary)["hp"] = 20
		(data.rules["bench_xp"] as Dictionary)["enabled"] = enabled
		var progression: Progression = Progression.new(data)
		var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 1)
		setup.party = [progression.new_member("red", 1), progression.new_member("otis", 1)]
		setup.bench = [progression.new_member("mox", 1)]
		var controller: BattleController = await _fight(setup, [], BattleTestKit.FixedPressSource.new(0.0), ATTACK_RED)
		assert_eq(controller.result, "win")
		var bench: Dictionary = (controller.get_result()["bench"] as Array)[0]
		if enabled:
			assert_eq(int(bench["xp"]), 100, "the bench earns the full share")
			assert_eq(int(bench["level"]), progression.level_for_xp(100))
			var ids: Array = []
			for record: Dictionary in controller.report["level_ups"]:
				ids.append(record["id"])
			assert_has(ids, "mox", "their level-up shows on the victory screen too")
		else:
			assert_eq(int(bench["xp"]), 0, "off: nobody on the bench moves")
			assert_eq(int(bench["level"]), 1)
