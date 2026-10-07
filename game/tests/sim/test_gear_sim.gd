extends TestCase
## M3-6: the simulator with gear. Starting gear and the shop weapons must keep every fight inside
## the feel targets (enemy HP was raised 30 percent when gear arrived; see docs/decisions.md), gear
## must make fights shorter, and the shop prices must fit the credits the player has by Kasp.


func _sim(gear: bool = true) -> BattleSim:
	var sim: BattleSim = BattleSim.new(BattleTestKit.fresh_data(tree))
	sim.use_gear = gear
	return sim


func test_every_encounter_stays_inside_the_feel_targets_with_gear() -> void:
	var sim: BattleSim = _sim()
	var problems: Array[String] = []
	var all: Array[Dictionary] = []
	for encounter_id: String in sim.data.encounter_order:
		for player: String in ["perfect", "good", "auto", "miss"]:
			var stats: Dictionary = await sim.run_many(encounter_id, player, 100, 1)
			all.append(stats)
			problems.append_array(sim.check_against_targets(stats))
	problems.append_array(BattleSim.check_clutch_matters(sim.data, all))
	assert_eq(problems, [] as Array[String], "gear shifted the balance: %s" % [problems])


func test_gear_makes_fights_shorter_and_safer() -> void:
	var geared: Dictionary = await _sim(true).run_many("squad_four", "auto", 60, 1)
	var bare: Dictionary = await _sim(false).run_many("squad_four", "auto", 60, 1)
	assert_lt(float(geared["mean_s"]), float(bare["mean_s"]), "weapons mean fewer rounds")
	assert_gt(float(geared["mean_hp_left_pct"]), float(bare["mean_hp_left_pct"]), "armor means more HP left")


func test_the_walkthrough_with_gear_still_reaches_level_6_with_enough_credits() -> void:
	var sim: BattleSim = _sim()
	var walk: Dictionary = await sim.walkthrough("good", 5)
	assert_true(bool(walk["completed"]), "the good player finishes the slice's fights")
	assert_eq(int(walk["level"]), 6)
	var items: ItemData = sim.data.item_data
	var budget: int = int(sim.data.feel["credits_at_kasp"])
	assert_ge(float(walk["credits"]), 0.6 * float(budget), "battles alone pay most of the way to the Kasp budget (crates and side jobs add the rest)")
	var weapons: int = items.price("rebar_blade") + items.price("rivet_hammer") + items.price("pipe_wrench")
	var vests: int = items.price("padded_work_vest") + items.price("hi_vis_vest")
	assert_le(weapons + 10 * items.price("ration_bar"), budget, "the shop weapons and a pocketful of Ration Bars")
	assert_gt(weapons + vests, budget, "...but not every vest as well")


func test_a_loadout_changes_when_the_party_levels_up_in_the_walkthrough() -> void:
	var sim: BattleSim = _sim()
	var member: Dictionary = sim.progression.new_member("red", 2, sim.gear_for_level(2)["red"])
	assert_eq(member["equipment"]["weapon"], "scrap_sword")
	member["level"] = 3
	member["hp"] = 5
	sim.refit(member)
	assert_eq(member["equipment"]["weapon"], "rebar_blade", "bought the shop weapon")
	assert_eq(member["hp"], 5, "refitting never heals")
	assert_eq(member["hp_max"], StatCalc.stats_for_member(sim.data, member)["hp"])
