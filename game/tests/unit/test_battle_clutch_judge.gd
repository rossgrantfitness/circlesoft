extends TestCase
## M2-3: ClutchJudge is a pure function of timestamps, windows and modifiers. Boundaries for every
## rating and modifier, the timing offset, press types, and "the first press counts".

const WINDOW: Dictionary = {"nice_ms": 125.0, "rad_ms": 80.0, "totally_rad_ms": 50.0}
const CUE: int = 1000000
const LISTEN_MS: int = 400


func _rating(delta_ms: float, mult: float = 1.0) -> String:
	return ClutchJudge.rating_for_delta(delta_ms, WINDOW, mult)


func _tap_slot(mult: float = 1.0) -> Dictionary:
	return ClutchJudge.make_slot(ClutchJudge.TYPE_TAP, CUE, ClutchJudge.NO_PRESS, LISTEN_MS, WINDOW, mult)


func _hold_slot(hold_by_ms: int = 700) -> Dictionary:
	var hold_by: int = CUE - (1200 - hold_by_ms) * 1000
	return ClutchJudge.make_slot(ClutchJudge.TYPE_HOLD, CUE, hold_by, LISTEN_MS, WINDOW, 1.0)


func _downs(list: Array[int]) -> Array[int]:
	return list


# ---- ratings and boundaries ----

func test_rating_boundaries_are_inclusive() -> void:
	assert_eq(_rating(0.0), "totally_rad")
	assert_eq(_rating(50.0), "totally_rad")
	assert_eq(_rating(-50.0), "totally_rad")
	assert_eq(_rating(50.1), "rad")
	assert_eq(_rating(80.0), "rad")
	assert_eq(_rating(-80.0), "rad")
	assert_eq(_rating(80.1), "nice")
	assert_eq(_rating(125.0), "nice")
	assert_eq(_rating(-125.0), "nice")
	assert_eq(_rating(125.1), "miss")
	assert_eq(_rating(-400.0), "miss")
	assert_eq(_rating(5000.0), "miss")


func test_early_and_late_are_judged_the_same_way() -> void:
	for d: float in [10.0, 60.0, 100.0, 124.0, 126.0]:
		assert_eq(_rating(d), _rating(-d), "delta %s" % d)


func test_modifier_values_scale_every_boundary() -> void:
	var mods: Dictionary = {"wide_windows": 1.5, "defending_block": 1.25, "butterfingers": 0.75, "fired_up": 1.25}
	assert_almost_eq(ClutchJudge.window_multiplier(mods, false, false), 1.0)
	assert_almost_eq(ClutchJudge.window_multiplier(mods, true, false), 1.5)
	assert_almost_eq(ClutchJudge.window_multiplier(mods, false, true), 1.25)
	assert_almost_eq(ClutchJudge.window_multiplier(mods, false, false, true, false), 0.75)
	assert_almost_eq(ClutchJudge.window_multiplier(mods, false, false, false, true), 1.25)
	assert_almost_eq(ClutchJudge.window_multiplier(mods, true, true), 1.875, 0.0001, "wide and defending stack")
	assert_almost_eq(ClutchJudge.window_multiplier(mods, true, false, true, false), 1.125, 0.0001)


func test_wide_windows_widen_each_rating_by_the_modifier() -> void:
	assert_eq(_rating(75.0, 1.5), "totally_rad", "50 * 1.5 = 75")
	assert_eq(_rating(75.1, 1.5), "rad")
	assert_eq(_rating(120.0, 1.5), "rad", "80 * 1.5 = 120")
	assert_eq(_rating(120.1, 1.5), "nice")
	assert_eq(_rating(187.5, 1.5), "nice", "125 * 1.5")
	assert_eq(_rating(187.6, 1.5), "miss")


func test_defending_block_modifier_widens_block_windows() -> void:
	assert_eq(_rating(62.5, 1.25), "totally_rad", "50 * 1.25")
	assert_eq(_rating(62.6, 1.25), "rad")
	assert_eq(_rating(60.0), "rad", "without Defend 60 ms is only Rad")
	assert_eq(_rating(60.0, 1.25), "totally_rad", "with Defend 60 ms is perfect")


func test_butterfingers_shrinks_and_fired_up_grows() -> void:
	assert_eq(_rating(40.0, 0.75), "rad", "50 * 0.75 = 37.5")
	assert_eq(_rating(37.5, 0.75), "totally_rad")
	assert_eq(_rating(60.0, 1.25), "totally_rad")


func test_timing_offset_moves_the_cue_not_the_window() -> void:
	var plain: int = ClutchJudge.cue_usec(CUE, 800, 0)
	var shifted: int = ClutchJudge.cue_usec(CUE, 800, 60)
	assert_eq(shifted - plain, 60000)
	var raw_press: int = plain + 60000
	assert_eq(_rating(ClutchJudge.delta_ms(raw_press, plain)), "rad", "60 ms late without an offset")
	assert_eq(_rating(ClutchJudge.delta_ms(raw_press, shifted)), "totally_rad", "with a +60 ms offset it is perfect")
	var early: int = plain - 60000
	assert_eq(_rating(ClutchJudge.delta_ms(early, ClutchJudge.cue_usec(CUE, 800, -60))), "totally_rad", "negative offsets work too")


func test_block_tiers_and_juice_ratings() -> void:
	assert_eq(ClutchJudge.block_tier("miss"), "none")
	assert_eq(ClutchJudge.block_tier("nice"), "partial")
	assert_eq(ClutchJudge.block_tier("rad"), "partial")
	assert_eq(ClutchJudge.block_tier("totally_rad"), "perfect")
	assert_false(ClutchJudge.is_rad_or_better("nice"))
	assert_true(ClutchJudge.is_rad_or_better("rad"))
	assert_true(ClutchJudge.is_rad_or_better("totally_rad"))


# ---- taps ----

func test_a_tap_on_the_cue_is_totally_rad() -> void:
	var verdict: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([CUE]), [] as Array[int], CUE)
	assert_true(verdict["decided"])
	assert_eq(verdict["rating"], "totally_rad")
	assert_almost_eq(float(verdict["delta_ms"]), 0.0)
	assert_eq(verdict["used_down"], CUE)


func test_a_tap_reports_a_signed_delta() -> void:
	var late: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([CUE + 70000]), [] as Array[int], CUE + 70000)
	assert_almost_eq(float(late["delta_ms"]), 70.0)
	assert_eq(late["rating"], "rad")
	var early: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([CUE - 100000]), [] as Array[int], CUE)
	assert_almost_eq(float(early["delta_ms"]), -100.0)
	assert_eq(early["rating"], "nice")


func test_no_press_is_a_miss_only_once_the_window_has_closed() -> void:
	var none: Array[int] = []
	assert_false(ClutchJudge.decide(_tap_slot(), none, none, CUE)["decided"], "still waiting at the cue")
	assert_false(ClutchJudge.decide(_tap_slot(), none, none, CUE + 124000)["decided"])
	var closed: Dictionary = ClutchJudge.decide(_tap_slot(), none, none, CUE + 125000)
	assert_true(closed["decided"])
	assert_eq(closed["rating"], "miss")
	assert_false(closed["pressed"])


func test_a_press_that_has_not_happened_yet_is_not_judged() -> void:
	var verdict: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([CUE + 30000]), [] as Array[int], CUE)
	assert_false(verdict["decided"], "a press stamped in the future has not happened yet")


func test_presses_before_the_listen_window_are_ignored() -> void:
	var too_early: int = CUE - LISTEN_MS * 1000 - 1
	var verdict: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([too_early]), [] as Array[int], CUE + 200000)
	assert_eq(verdict["rating"], "miss")
	assert_false(verdict["pressed"], "a press before listen_before_ms does not count at all")


func test_the_first_press_in_the_window_is_the_one_judged_so_mashing_fails() -> void:
	var mash: Array[int] = [CUE - 390000, CUE - 300000, CUE - 100000, CUE, CUE + 20000]
	var verdict: Dictionary = ClutchJudge.decide(_tap_slot(), mash, [] as Array[int], CUE + 200000)
	assert_eq(verdict["rating"], "miss", "the first press (390 ms early) is the judged one")
	assert_almost_eq(float(verdict["delta_ms"]), -390.0)
	assert_eq(verdict["used_down"], CUE - 390000)


func test_a_late_press_after_the_window_is_not_taken_by_the_slot() -> void:
	var verdict: Dictionary = ClutchJudge.decide(_tap_slot(), _downs([CUE + 200000]), [] as Array[int], CUE + 300000)
	assert_eq(verdict["rating"], "miss")
	assert_false(verdict["pressed"])
	assert_eq(verdict["used_down"], ClutchJudge.NO_PRESS, "the late press stays free for a later slot")


func test_wide_windows_let_a_late_tap_count() -> void:
	var press: int = CUE + 150000
	assert_eq(ClutchJudge.decide(_tap_slot(1.0), _downs([press]), [] as Array[int], press + 100000)["rating"], "miss")
	assert_eq(ClutchJudge.decide(_tap_slot(1.5), _downs([press]), [] as Array[int], press + 100000)["rating"], "nice")


func test_next_decision_time_points_at_the_next_press_or_the_close() -> void:
	var slot: Dictionary = _tap_slot()
	var none: Array[int] = []
	assert_eq(ClutchJudge.next_decision_usec(slot, none, none, CUE - 500000), CUE + 125000)
	assert_eq(ClutchJudge.next_decision_usec(slot, _downs([CUE + 30000]), none, CUE), CUE + 30000)


# ---- hold and release ----

func test_a_hold_is_judged_on_the_release() -> void:
	var slot: Dictionary = _hold_slot()
	var down: int = CUE - 520000
	var perfect: Dictionary = ClutchJudge.decide(slot, _downs([down]), _downs([CUE + 10000]), CUE + 10000)
	assert_eq(perfect["rating"], "totally_rad")
	assert_eq(perfect["used_up"], CUE + 10000)
	var rad: Dictionary = ClutchJudge.decide(slot, _downs([down]), _downs([CUE - 70000]), CUE)
	assert_eq(rad["rating"], "rad", "released 70 ms early")


func test_a_hold_with_no_release_yet_is_still_waiting_then_a_miss() -> void:
	var slot: Dictionary = _hold_slot()
	var down: int = CUE - 520000
	var none: Array[int] = []
	assert_false(ClutchJudge.decide(slot, _downs([down]), none, CUE)["decided"])
	var closed: Dictionary = ClutchJudge.decide(slot, _downs([down]), none, CUE + 125000)
	assert_eq(closed["rating"], "miss", "held and never let go")


func test_hold_started_too_late_is_a_miss() -> void:
	var slot: Dictionary = _hold_slot(700)
	var hold_by: int = int(slot["hold_by"])
	var late_down: int = hold_by + 1000
	var verdict: Dictionary = ClutchJudge.decide(slot, _downs([late_down]), _downs([CUE]), CUE + 130000)
	assert_eq(verdict["rating"], "miss", "released perfectly but started the hold after hold_by")
	assert_false(verdict["pressed"])


func test_a_hold_that_starts_exactly_on_hold_by_counts() -> void:
	var slot: Dictionary = _hold_slot(700)
	var verdict: Dictionary = ClutchJudge.decide(slot, _downs([int(slot["hold_by"])]), _downs([CUE]), CUE)
	assert_eq(verdict["rating"], "totally_rad")


func test_hold_released_too_early_or_too_late_is_a_miss() -> void:
	var slot: Dictionary = _hold_slot()
	var down: int = CUE - 520000
	assert_eq(ClutchJudge.decide(slot, _downs([down]), _downs([CUE - 300000]), CUE)["rating"], "miss")
	assert_eq(ClutchJudge.decide(slot, _downs([down]), _downs([CUE + 200000]), CUE + 200000)["rating"], "miss")


func test_a_hold_pressed_before_its_window_does_not_count() -> void:
	var slot: Dictionary = _hold_slot(700)
	var too_early: int = int(slot["open"]) - 1
	var verdict: Dictionary = ClutchJudge.decide(slot, _downs([too_early]), _downs([CUE]), CUE + 130000)
	assert_false(verdict["pressed"], "the hold must start inside its window")


# ---- strings ----

func test_a_string_judges_every_cue_on_its_own() -> void:
	var cues: Array[int] = [CUE, CUE + 350000, CUE + 700000]
	var presses: Array[int] = [CUE + 10000, CUE + 350000 + 90000, CUE + 700000 - 20000]
	var results: Array[Dictionary] = ClutchJudge.judge_string(presses, cues, LISTEN_MS, WINDOW)
	assert_eq(results.size(), 3)
	assert_eq(results[0]["rating"], "totally_rad")
	assert_eq(results[1]["rating"], "nice", "90 ms late is only Nice")
	assert_eq(results[2]["rating"], "totally_rad")


func test_a_string_with_a_skipped_cue_misses_only_that_cue() -> void:
	var cues: Array[int] = [CUE, CUE + 350000, CUE + 700000]
	var presses: Array[int] = [CUE, CUE + 700000]
	var results: Array[Dictionary] = ClutchJudge.judge_string(presses, cues, LISTEN_MS, WINDOW)
	assert_eq(results[0]["rating"], "totally_rad")
	assert_eq(results[1]["rating"], "miss")
	assert_eq(results[2]["rating"], "totally_rad")


func test_mashing_a_string_does_not_hit_every_cue() -> void:
	var cues: Array[int] = [CUE, CUE + 300000, CUE + 600000]
	var mash: Array[int] = []
	for i: int in 12:
		mash.append(CUE - 450000 + i * 25000)
	var results: Array[Dictionary] = ClutchJudge.judge_string(mash, cues, LISTEN_MS, WINDOW)
	var good: int = 0
	for verdict: Dictionary in results:
		if verdict["rating"] != "miss":
			good += 1
	assert_lt(float(good), 3.0, "mashing cannot land all three cues")


func test_each_press_serves_only_one_cue() -> void:
	var cues: Array[int] = [CUE, CUE + 100000]
	var results: Array[Dictionary] = ClutchJudge.judge_string([CUE + 50000] as Array[int], cues, LISTEN_MS, WINDOW)
	var landed: int = 0
	for verdict: Dictionary in results:
		if verdict["pressed"]:
			landed += 1
	assert_eq(landed, 1, "one press cannot be spent twice")
