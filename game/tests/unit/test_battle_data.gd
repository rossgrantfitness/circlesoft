extends TestCase
## M2-1: the battle data files parse, cross-reference and hold the slice content the task asks for.

const SLICE_ENEMIES: Array[String] = ["signals_grunt", "signals_drone", "whistle_blower", "buzzkill_drone"]
const SIGNATURES: Array[String] = ["porch_light", "heave_ho", "patent_pending"]
const REQUIRED_STATUSES: Array[String] = ["burnt_toast", "noise_ticket", "wobbly", "down_for_the_count"]


func _data() -> BattleData:
	return BattleData.load_from(tree.root.get_node("DataDB"))


func test_all_battle_files_load_without_errors() -> void:
	var db: Node = tree.root.get_node("DataDB")
	assert_false(db.has_errors(), "DataDB errors: %s" % db.get_errors())
	for id: String in ["battle/skills", "battle/enemies", "battle/statuses", "battle/timing_windows", "battle/encounters",
			"battle/formulas", "battle/feel_targets", "battle/battle_items", "party/characters"]:
		assert_true(db.has_json(id), id)
	for id: String in ["party/growth", "party/xp_curve"]:
		assert_true(db.has_table(id), id)


func test_cross_references_resolve_and_values_are_in_range() -> void:
	var problems: Array[String] = _data().validate()
	assert_eq(problems, [], "data problems: %s" % str(problems))


func test_slice_party_has_signature_plus_two_basic_skills_each() -> void:
	var data: BattleData = _data()
	assert_eq(data.character_order, ["red", "otis", "mox"] as Array[String])
	for i: int in 3:
		var character: Dictionary = data.character(data.character_order[i])
		assert_eq(str(character["signature_skill"]), SIGNATURES[i])
		var learned: Array = character["skills_by_level"]
		assert_eq(learned.size(), 3, "signature + 2 basic")
		assert_eq(int((learned[0] as Dictionary)["level"]), 1)
		assert_eq(int((learned[1] as Dictionary)["level"]), 1)
		assert_eq(int((learned[2] as Dictionary)["level"]), 4, "the third skill is learned around level 4")
		assert_eq(str((learned[0] as Dictionary)["skill"]), SIGNATURES[i], "signature known from the start")


func test_every_press_type_is_used_by_the_party() -> void:
	var data: BattleData = _data()
	var seen: Dictionary = {}
	for skill_id: String in data.skills:
		for press: Dictionary in data.skill(skill_id)["presses"]:
			seen[str(press["type"])] = true
	for press_type: String in BattleData.PRESS_TYPES:
		assert_true(seen.has(press_type), "press type %s used" % press_type)


func test_four_enemy_types_each_with_a_tell_and_a_block_press() -> void:
	var data: BattleData = _data()
	assert_eq(data.enemies.size(), 5, "four slice enemy types plus the Kasp boss")
	for enemy_id: String in SLICE_ENEMIES:
		assert_true(data.enemies.has(enemy_id), enemy_id)
		for entry: Dictionary in data.enemy(enemy_id)["ai"]:
			var skill: Dictionary = data.skill(str(entry["skill"]))
			assert_false((skill["presses"] as Array).is_empty(), "%s has a block press" % skill["id"])
			assert_gt(float((skill["timeline_ms"] as Dictionary)["windup"]), 0.0, "%s has a wind-up (the tell)" % skill["id"])
			assert_false(str(skill.get("tell", "")).is_empty(), "%s describes its tell" % skill["id"])
			for press: Dictionary in skill["presses"]:
				assert_eq(str(press["window"]), "block")


func test_grunts_flee_and_drones_do_not() -> void:
	var data: BattleData = _data()
	assert_true(data.enemy("signals_grunt").has("flee_at_hp_pct"), "the grunt waves a white flag")
	assert_true(data.enemy("whistle_blower").has("flee_at_hp_pct"), "so does its variant")
	assert_false(data.enemy("signals_drone").has("flee_at_hp_pct"))


func test_statuses_cover_the_slice_list() -> void:
	var data: BattleData = _data()
	for status_id: String in REQUIRED_STATUSES:
		assert_true(data.statuses.has(status_id), status_id)
	assert_true(data.statuses.has("stunned"), "Heave-Ho needs a one-turn skip")
	assert_eq(int(data.status("stunned")["duration_turns"]), 1)
	assert_true(bool(data.status("noise_ticket")["blocks_skills"]))
	assert_gt(float(data.status("wobbly")["random_target_chance"]), 0.0)
	assert_gt(float(data.status("burnt_toast")["hp_loss_pct"]), 0.0)
	assert_true(bool(data.status("down_for_the_count")["down"]))


func test_encounters_cover_one_to_four_enemies_and_one_cannot_be_run_from() -> void:
	var data: BattleData = _data()
	assert_ge(data.encounters.size(), 5)
	var sizes: Dictionary = {}
	var no_run: int = 0
	for encounter_id: String in data.encounters:
		var encounter: Dictionary = data.encounter(encounter_id)
		sizes[(encounter["enemies"] as Array).size()] = true
		if not bool(encounter["can_run"]):
			no_run += 1
	assert_true(sizes.has(1) and sizes.has(4), "from a solo fight to a four-enemy fight")
	assert_ge(no_run, 1, "a tougher fight with can_run false")


func test_timing_windows_match_the_design() -> void:
	var data: BattleData = _data()
	var standard: Dictionary = data.window("standard")
	assert_almost_eq(float(standard["nice_ms"]) * 2.0, 250.0, 25.0, "Nice is about a quarter of a second wide")
	assert_almost_eq(float(standard["totally_rad_ms"]) * 2.0, 100.0, 20.0, "TOTALLY RAD is about a tenth")
	assert_eq(data.listen_before_ms(), 400)
	for key: String in ["wide_windows", "defending_block", "butterfingers", "fired_up"]:
		assert_true((data.windows_doc["modifiers"] as Dictionary).has(key), key)
	assert_gt(data.window_modifier("wide_windows"), 1.0)
	assert_lt(data.window_modifier("butterfingers"), 1.0)


func test_battle_items_cover_heal_revive_and_juice() -> void:
	var data: BattleData = _data()
	assert_true(data.battle_items.has("ration_bar"))
	assert_true(data.battle_items.has("canned_coffee"))
	assert_true(data.battle_items.has("smelling_salts"))
	assert_true((data.battle_item("ration_bar")["effect"] as Dictionary).has("heal_hp"))
	assert_true((data.battle_item("canned_coffee")["effect"] as Dictionary).has("restore_juice"))
	assert_true((data.battle_item("smelling_salts")["effect"] as Dictionary).has("revive_hp_pct"))
	var existing: Array = tree.root.get_node("DataDB").get_dict("items/items")["items"]
	for entry: Dictionary in existing:
		var in_battle: bool = (entry.get("use_in", []) as Array).has("battle")
		assert_eq(data.battle_items.has(str(entry["id"])), in_battle, "%s: battle menu follows use_in" % entry["id"])


func test_every_encounter_tier_has_feel_targets() -> void:
	var data: BattleData = _data()
	for tier: String in ["tutorial", "regular", "tough", "boss"]:
		assert_true((data.feel["fight_seconds"] as Dictionary).has(tier), tier)
	assert_eq(int(data.feel["menu_ms_per_command"]), 2000)
	assert_eq(int(data.feel["level_at_kasp"]), 6)
	assert_eq(int(data.feel["credits_at_kasp"]), 1500)
