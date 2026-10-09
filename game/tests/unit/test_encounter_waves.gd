extends TestCase
## EncounterWaves: which wave of an encounter starts when (data/slice/encounters.json), with no nodes.

const RULES: Dictionary = {"wave_gap_ms": 2500, "wave_warning_ms": 900}


func _spawned(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		if event["type"] == "spawn":
			out.append(str(event["wave"]))
	return out


func test_nothing_happens_before_the_trigger() -> void:
	var plan: EncounterWaves = EncounterWaves.from_defs([{"id": "w1", "start": "on_trigger"}], RULES)
	assert_eq(plan.tick(5.0, {}, 0.0).size(), 0)
	assert_false(plan.is_begun())


func test_an_on_trigger_wave_starts_the_moment_it_fires() -> void:
	var plan: EncounterWaves = EncounterWaves.from_defs([{"id": "w1", "start": "on_trigger"}], RULES)
	plan.begin(10.0)
	assert_eq(_spawned(plan.tick(10.0, {}, 0.0)), ["w1"] as Array[String])
	assert_true(plan.has_started("w1"))
	assert_true(plan.all_started())
	assert_eq(plan.tick(11.0, {}, 0.0).size(), 0, "a wave spawns once")


func test_the_next_wave_waits_for_the_last_to_thin_out_or_for_its_timer() -> void:
	var waves: Array = [{"id": "w1", "start": "on_trigger"},
			{"id": "w2", "start": {"after_wave": "w1", "alive_at_most": 1, "or_after_s": 14.0}}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	plan.tick(0.0, {}, 0.0)
	assert_eq(_spawned(plan.tick(5.0, {"w1": 3}, 0.0)).size(), 0, "three still alive")
	assert_eq(_spawned(plan.tick(6.0, {"w1": 1}, 0.0)), ["w2"] as Array[String], "one left: the next wave comes")


func test_the_timer_starts_a_wave_even_if_the_last_is_still_alive() -> void:
	var waves: Array = [{"id": "w1", "start": "on_trigger"},
			{"id": "w2", "start": {"after_wave": "w1", "alive_at_most": 0, "or_after_s": 14.0}}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	plan.tick(0.0, {}, 0.0)
	assert_eq(_spawned(plan.tick(13.0, {"w1": 2}, 0.0)).size(), 0)
	assert_eq(_spawned(plan.tick(14.0, {"w1": 2}, 0.0)), ["w2"] as Array[String])


func test_a_wave_never_starts_inside_the_gap_after_the_previous_one() -> void:
	var waves: Array = [{"id": "w1", "start": "on_trigger"}, {"id": "w2", "start": {"after_wave": "w1", "alive_at_most": 9}}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	plan.tick(0.0, {}, 0.0)
	assert_eq(_spawned(plan.tick(1.0, {"w1": 0}, 0.0)).size(), 0, "2.5 s have not passed")
	assert_eq(_spawned(plan.tick(2.5, {"w1": 0}, 0.0)), ["w2"] as Array[String])


func test_a_warning_goes_out_before_the_wave() -> void:
	var waves: Array = [{"id": "w1", "start": "on_trigger"},
			{"id": "w2", "start": {"after_wave": "w1", "alive_at_most": 9}, "warning": "bark_j2_overclock"}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	plan.tick(0.0, {}, 0.0)
	var first: Array[Dictionary] = plan.tick(3.0, {"w1": 0}, 0.0)
	assert_eq(first.size(), 1)
	assert_eq(first[0]["type"], "warn")
	assert_eq(first[0]["bark"], "bark_j2_overclock")
	assert_eq(plan.tick(3.5, {"w1": 0}, 0.0).size(), 0, "still inside the 0.9 s notice")
	assert_eq(_spawned(plan.tick(4.0, {"w1": 0}, 0.0)), ["w2"] as Array[String])


func test_a_wave_can_wait_for_red_to_walk_east() -> void:
	var waves: Array = [{"id": "w1", "start": "on_trigger"}, {"id": "w2", "start": {"red_x_at_least": 80.0}}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	plan.tick(0.0, {}, 10.0)
	assert_eq(_spawned(plan.tick(20.0, {}, 79.0)).size(), 0)
	assert_eq(_spawned(plan.tick(21.0, {}, 80.5)), ["w2"] as Array[String])


func test_waves_go_in_order() -> void:
	var waves: Array = [{"id": "w1", "start": {"red_x_at_least": 50.0}}, {"id": "w2", "start": "on_trigger"}]
	var plan: EncounterWaves = EncounterWaves.from_defs(waves, RULES)
	plan.begin(0.0)
	assert_eq(_spawned(plan.tick(10.0, {}, 0.0)).size(), 0, "w2 does not jump the queue")


func test_the_real_data_parses_into_plans() -> void:
	var doc: Dictionary = DataDB.get_dict("slice/encounters")
	assert_gt((doc["encounters"] as Dictionary).size(), 5)
	for id: String in doc["encounters"]:
		var plan: EncounterWaves = EncounterWaves.from_defs((doc["encounters"][id] as Dictionary).get("waves", []), doc["rules"])
		for wave_id: String in plan.wave_ids():
			assert_ne(wave_id, "", "%s: every wave has an id" % id)
