extends TestCase
## M3-6: battles use gear. Stats come through StatCalc (growth + boosters + gear), charms block their
## status through the status rules, Sore Loser Patch makes Payback hit harder, level-ups keep the
## gear's bonus, and the GameState copy of a fighter agrees with what the battle uses.

const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"
const DEFEND: Dictionary = {"kind": "defend"}

var _members: Array[Dictionary] = []


func _state() -> Node:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	return state


func _data() -> BattleData:
	var data: BattleData = BattleTestKit.fresh_data(tree)
	(data.formulas["damage"] as Dictionary)["variance_pct"] = 0
	return data


func _setup(data: BattleData, gear: Dictionary, level: int = 3, encounter: String = "grunt_solo") -> BattleSetup:
	var setup: BattleSetup = BattleTestKit.setup_for(data, encounter, level)
	var progression: Progression = Progression.new(data)
	setup.party.clear()
	for char_id: String in data.character_order:
		setup.party.append(progression.new_member(char_id, level, gear.get(char_id, {})))
	return setup


func _red(controller: BattleController) -> BattleCombatant:
	return controller.state.get_c("red")


# ---- stats ----

func test_battle_stats_are_growth_plus_gear() -> void:
	var data: BattleData = _data()
	var gear: Dictionary = {"red": {"weapon": "rebar_blade", "armor": "hi_vis_vest", "charm": "lucky_bolt"}}
	var controller: BattleController = BattleController.create(_setup(data, gear))
	var red: BattleCombatant = _red(controller)
	var base: Dictionary = data.growth["red"][3]
	assert_eq(red.stats["attack"], base["attack"] + 7)
	assert_eq(red.stats["defense"], base["defense"] + 3)
	assert_eq(red.stats["luck"], base["luck"] + 2 + 4)
	assert_eq(red.stats["hp"], base["hp"])
	var otis: BattleCombatant = controller.state.get_c("otis")
	assert_eq(otis.stats["attack"], data.growth["otis"][3]["attack"], "no gear given, no gear bonus")


func test_armor_hp_raises_the_fighters_maximum() -> void:
	var data: BattleData = _data()
	var controller: BattleController = BattleController.create(_setup(data, {"otis": {"weapon": "", "armor": "lucky_coveralls", "charm": ""}}))
	var otis: BattleCombatant = controller.state.get_c("otis")
	assert_eq(otis.hp_max, data.growth["otis"][3]["hp"] + 8)
	assert_eq(otis.hp, otis.hp_max, "a fresh member starts full")


func test_a_weapon_makes_the_hero_hit_harder() -> void:
	var data: BattleData = _data()
	var hit_for: Array[int] = []
	for weapon: String in ["", "scrap_sword", "rebar_blade"]:
		var setup: BattleSetup = _setup(data, {"red": {"weapon": weapon, "armor": "", "charm": ""}})
		var controller: BattleController = await BattleTestKit.run(setup, [{"kind": "attack", "targets": ["e1"]}], BattleTestKit.FixedPressSource.new(0.0, true), DEFEND, 1)
		var enemy: BattleCombatant = controller.state.get_c("e1")
		hit_for.append(enemy.hp_max - enemy.hp)
	assert_gt(hit_for[1], hit_for[0], "Scrap Sword beats bare hands")
	assert_gt(hit_for[2], hit_for[1], "Rebar Blade beats Scrap Sword")


func test_setup_from_game_state_reads_gear_through_stat_calc() -> void:
	var state: Node = _state()
	state.call("update_member", "red", {"hp": 42})  # hurt, so the saved HP is what the fight starts with
	Bag.add("rebar_blade", 1, state)
	Equipment.equip("red", "weapon", "rebar_blade", state)
	var setup: BattleSetup = BattleSetup.from_game_state(state, "grunt_solo")
	setup.clock = VirtualClock.new()
	setup.rng_seed = 1
	var controller: BattleController = BattleController.create(setup)
	for who: String in ["red", "otis", "mox"]:
		var fighter: BattleCombatant = controller.state.get_c(who)
		var expected: Dictionary = StatCalc.stats(who, state)
		for key: String in BattleData.STAT_KEYS:
			assert_eq(fighter.stats[key], expected[key], "%s %s: the menu and the battle agree" % [who, key])
	assert_eq(_red(controller).hp, 42, "current HP still comes from the saved member")


func test_boosters_and_gear_both_count() -> void:
	var state: Node = _state()
	state.call("update_member", "mox", {"bonus": {"attack": 2}})
	var setup: BattleSetup = BattleSetup.from_game_state(state, "grunt_solo")
	setup.clock = VirtualClock.new()
	var mox: BattleCombatant = BattleController.create(setup).state.get_c("mox")
	assert_eq(mox.stats["attack"], BattleData.shared().growth["mox"][3]["attack"] + 2 + 2, "growth + booster + Big Wrench")
	assert_eq(mox.bonus, {"attack": 2}, "the gear bonus is not mixed into the saved boosters")


# ---- charms ----

func test_earplugs_stop_the_noise_ticket() -> void:
	var data: BattleData = _data()
	var with_plugs: BattleController = BattleController.create(_setup(data, {"red": {"weapon": "", "armor": "", "charm": "earplugs"}}))
	var red: BattleCombatant = _red(with_plugs)
	assert_eq(red.status_resist.get("noise_ticket", 0.0), 1.0)
	for i: int in 50:
		with_plugs.call("_try_status", with_plugs.state.get_c("e1"), red, "noise_ticket", 1.0)
	assert_false(red.has_status("noise_ticket"), "never lands")
	with_plugs.call("_try_status", with_plugs.state.get_c("e1"), red, "burnt_toast", 1.0)
	assert_true(red.has_status("burnt_toast"), "other statuses still do")
	var bare: BattleController = BattleController.create(_setup(data, {}))
	bare.call("_try_status", bare.state.get_c("e1"), _red(bare), "noise_ticket", 1.0)
	assert_true(_red(bare).has_status("noise_ticket"), "without the charm it lands")


func test_oven_mitts_stop_burnt_toast_even_from_a_bomb() -> void:
	var data: BattleData = _data()
	var controller: BattleController = BattleController.create(_setup(data, {"mox": {"weapon": "", "armor": "", "charm": "oven_mitts"}}))
	var mox: BattleCombatant = controller.state.get_c("mox")
	controller.call("_try_status", controller.state.get_c("e1"), mox, "burnt_toast", 1.0)
	assert_false(mox.has_status("burnt_toast"))
	controller.call("_try_status", controller.state.get_c("e1"), mox, "noise_ticket", 1.0)
	assert_true(mox.has_status("noise_ticket"))


func test_noise_ticket_events_happen_without_plugs_and_not_with() -> void:
	var data: BattleData = _data()
	var counts: Array[int] = [0, 0]
	for plugged: int in 2:
		for seed_value: int in 12:
			var gear: Dictionary = {}
			if plugged == 1:
				for who: String in ["red", "otis", "mox"]:
					gear[who] = {"weapon": "", "armor": "", "charm": "earplugs"}
			var setup: BattleSetup = _setup(data, gear, 3, "grunt_pair")
			setup.rng_seed = seed_value + 1
			var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
			source.fallback = DEFEND
			source.limit = 9
			setup.command_source = source
			setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
			var controller: BattleController = BattleController.create(setup)
			var log: BattleTestKit.Recorder = BattleTestKit.Recorder.new(controller)
			await controller.start()
			for e: Dictionary in log.of("status_changed"):
				if (e["args"] as Array)[1] == "noise_ticket" and bool((e["args"] as Array)[2]):
					counts[plugged] += 1
	assert_gt(counts[0], 0, "control: grunts do write tickets")
	assert_eq(counts[1], 0, "with Earplugs on all three, none stick")


# ---- Payback ----

func test_sore_loser_patch_makes_payback_hit_harder() -> void:
	var data: BattleData = _data()
	var dealt: Array[int] = []
	for charm: String in ["", "sore_loser_patch"]:
		var controller: BattleController = BattleController.create(_setup(data, {"red": {"weapon": "", "armor": "", "charm": charm}}))
		var enemy: BattleCombatant = controller.state.get_c("e1")
		var before: int = enemy.hp
		controller.call("_payback", _red(controller), enemy)
		dealt.append(before - enemy.hp)
	assert_gt(dealt[0], 0)
	assert_gt(dealt[1], dealt[0], "the patch adds to Payback")
	var power: float = float(data.windows_doc["payback_power"])
	var attack: float = float(data.growth["red"][3]["attack"])
	var defense: float = float(data.enemy("signals_grunt")["stats"]["defense"])
	assert_eq(dealt[1], BattleDamage.hit_damage(data, attack, power * 1.5, defense, 1.0, 1.0, 0.0, RandomNumberGenerator.new()), "payback_mult 1.5 from equipment.json")


# ---- level-ups and results ----

func test_level_ups_keep_the_gear_bonus() -> void:
	var data: BattleData = _data()
	var progression: Progression = Progression.new(data)
	var gear: Dictionary = {"weapon": "scrap_sword", "armor": "lucky_coveralls", "charm": ""}
	var member: Dictionary = progression.new_member("otis", 1, gear)
	assert_eq(member["hp_max"], data.growth["otis"][1]["hp"] + 8, "armor HP in the starting maximum")
	var record: Dictionary = progression.apply_xp(member, 9999)
	assert_eq(member["level"], 6)
	assert_eq(member["hp_max"], data.growth["otis"][6]["hp"] + 8, "still there at level 6")
	assert_eq((record["gains"] as Dictionary)["hp"], data.growth["otis"][6]["hp"] - data.growth["otis"][1]["hp"], "gear is not counted as a level-up gain")


func test_a_won_fight_writes_gear_adjusted_maximums_back() -> void:
	var state: Node = _state()
	var setup: BattleSetup = BattleSetup.from_game_state(state, "grunt_solo")
	setup.clock = VirtualClock.new()
	setup.rng_seed = 3
	setup.command_source = BattleSimPolicy.new(BattleData.shared().feel["sim"])
	setup.press_source = SimPressSource.make("perfect", 40.0, 450.0, 0.0)
	var controller: BattleController = BattleController.create(setup)
	await controller.start()
	assert_eq(controller.result, BattleController.RESULT_WIN)
	for who: String in ["red", "otis", "mox"]:
		assert_eq(state.call("get_member", who)["hp_max"], StatCalc.stats(who, state)["hp"], "%s: saved maximum matches StatCalc" % who)
	assert_eq(Equipment.get_equipped("red", state)["weapon"], "scrap_sword", "gear is untouched by a fight")


func test_the_simulator_dresses_the_party_in_the_configured_gear() -> void:
	var sim: BattleSim = BattleSim.new(BattleTestKit.fresh_data(tree))
	var starting: Dictionary = sim.gear_for_level(1)
	assert_eq(starting["red"]["weapon"], "scrap_sword")
	assert_eq(sim.gear_for_level(4)["red"]["weapon"], "rebar_blade", "shop weapons by level 3")
	assert_eq(sim.gear_for_level(6)["mox"]["armor"], "padded_work_vest")
	var setup: BattleSetup = sim.make_setup("grunt_solo", "perfect", 1, 1)
	assert_eq(setup.party[0]["equipment"]["weapon"], "scrap_sword")
	var bare: BattleSim = BattleSim.new(BattleTestKit.fresh_data(tree))
	bare.use_gear = false
	assert_false(bare.make_setup("grunt_solo", "perfect", 1, 1).party[0].has("equipment"), "--no-gear")
	for loadout_id: String in (sim.data.feel["sim"]["gear"]["loadouts"] as Dictionary):
		var loadout: Dictionary = sim.data.feel["sim"]["gear"]["loadouts"][loadout_id]
		for who: String in loadout:
			for slot: String in ItemData.SLOTS:
				var gear_id: String = str(loadout[who][slot])
				assert_true(gear_id.is_empty() or Equipment.can_wear(who, gear_id), "%s/%s can wear %s" % [loadout_id, who, gear_id])
	assert_eq(sim.data.feel["sim"]["gear"]["loadouts"]["starting"], sim.data.item_data.starting_gear, "the sim starts in the real starting gear")
