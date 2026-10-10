extends TestCase
## TapAlong: the maths of the Config screen's tap-along test (pairing taps with beats, and turning
## the lateness of the taps into a suggested timing offset).

const PARAMS: Dictionary = {"ignore_first": 1, "min_taps": 4, "outlier_ms": 100.0, "steady_ms": 60.0, "bias_ms": 0.0}


func _suggest(deltas: Array, step: int = 10, min_ms: int = -200, max_ms: int = 200) -> Dictionary:
	return TapAlong.suggest(deltas, PARAMS, step, min_ms, max_ms)


func test_steady_late_taps_suggest_that_lag() -> void:
	var result: Dictionary = _suggest([52.0, 48.0, 50.0, 47.0, 53.0, 49.0, 51.0, 50.0])
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], 50)
	assert_true(result["steady"])
	assert_eq(result["used"], 7, "the first tap is skipped as warm-up")


func test_early_taps_suggest_a_negative_offset() -> void:
	var result: Dictionary = _suggest([-31.0, -28.0, -33.0, -30.0, -29.0, -32.0])
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], -30)


func test_the_answer_snaps_to_the_config_step() -> void:
	assert_eq(_suggest([100.0, 47.0, 47.0, 47.0, 47.0])["offset_ms"], 50, "47 rounds to 50")
	assert_eq(_suggest([100.0, 43.0, 43.0, 43.0, 43.0])["offset_ms"], 40, "43 rounds to 40")
	assert_eq(_suggest([100.0, -23.0, -23.0, -23.0, -23.0])["offset_ms"], -20)
	assert_eq(_suggest([100.0, 47.0, 47.0, 47.0, 47.0], 5)["offset_ms"], 45, "a finer step gives a finer answer")


func test_the_answer_is_kept_inside_the_allowed_range() -> void:
	var late: Dictionary = _suggest([0.0, 400.0, 405.0, 395.0, 400.0], 10, -200, 200)
	assert_true(late["ok"])
	assert_eq(late["offset_ms"], 200)
	var early: Dictionary = _suggest([0.0, -400.0, -405.0, -395.0, -400.0], 10, -200, 200)
	assert_eq(early["offset_ms"], -200)


func test_wild_outliers_are_thrown_away() -> void:
	# One accidental double-tap (+280) and one miss (-160) should not drag the answer.
	var result: Dictionary = _suggest([40.0, 41.0, 280.0, 39.0, 40.0, -160.0, 42.0, 38.0])
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], 40)
	assert_eq(result["used"], 5)


func test_too_few_taps_give_no_suggestion() -> void:
	var result: Dictionary = _suggest([50.0, 50.0, 50.0])
	assert_false(result["ok"])
	assert_eq(result["reason"], TapAlong.REASON_TOO_FEW)
	assert_false(_suggest([])["ok"])


func test_when_skipping_the_warm_up_leaves_too_few_it_uses_every_tap() -> void:
	var result: Dictionary = _suggest([50.0, 50.0, 50.0, 50.0])
	assert_true(result["ok"], "four taps are enough once the skip is waived")
	assert_eq(result["offset_ms"], 50)


func test_all_over_the_place_taps_are_reported_as_unsteady() -> void:
	var result: Dictionary = _suggest([0.0, -200.0, 250.0, -150.0, 300.0, -250.0, 180.0])
	assert_false(result["ok"])
	assert_eq(result["reason"], TapAlong.REASON_UNSTEADY)


func test_jittery_but_usable_taps_work_but_are_not_called_steady() -> void:
	var result: Dictionary = _suggest([0.0, 0.0, 100.0, -40.0, 110.0, -40.0, 100.0])
	assert_true(result["ok"])
	assert_false(result["steady"])


func test_bias_is_taken_off_the_average() -> void:
	var biased: Dictionary = TapAlong.suggest([0.0, 30.0, 30.0, 30.0, 30.0], {"bias_ms": -20.0}, 10, -200, 200)
	assert_eq(biased["offset_ms"], 50, "a -20 ms bias adds 20 to the suggestion")


func test_median_handles_odd_even_and_empty_lists() -> void:
	assert_almost_eq(TapAlong.median([3.0, 1.0, 2.0]), 2.0)
	assert_almost_eq(TapAlong.median([4.0, 1.0, 2.0, 3.0]), 2.5)
	assert_almost_eq(TapAlong.median([]), 0.0)


func test_each_beat_is_paired_with_its_nearest_tap() -> void:
	var beats: Array = [1000.0, 1750.0, 2500.0]
	var taps: Array = [1055.0, 1810.0, 2490.0]
	var deltas: Array[float] = TapAlong.match_taps(beats, taps, 370.0)
	assert_eq(deltas, [55.0, 60.0, -10.0] as Array[float])


func test_a_tap_is_used_once_and_far_taps_are_ignored() -> void:
	var beats: Array = [1000.0, 1750.0]
	var taps: Array = [1040.0, 5000.0]
	var deltas: Array[float] = TapAlong.match_taps(beats, taps, 370.0)
	assert_eq(deltas, [40.0] as Array[float], "the second beat finds no tap near it")
	var doubled: Array[float] = TapAlong.match_taps([1000.0], [1030.0, 1050.0], 370.0)
	assert_eq(doubled.size(), 1, "two taps for one beat count once")
	assert_eq(doubled[0], 30.0, "the nearer one wins")


func test_beats_nobody_tapped_are_skipped_without_shifting_the_rest() -> void:
	var deltas: Array[float] = TapAlong.match_taps([1000.0, 1750.0, 2500.0], [1020.0, 2530.0], 370.0)
	assert_eq(deltas, [20.0, 30.0] as Array[float])


func test_a_whole_simulated_run_recovers_the_players_lag() -> void:
	# A player whose setup runs 70 ms late, with a little human wobble.
	var wobble: Array[float] = [4.0, -6.0, 8.0, -3.0, 5.0, -7.0, 2.0, 0.0]
	var beats: Array = []
	var taps: Array = []
	for i: int in 8:
		var beat: float = 1500.0 + float(i) * 750.0
		beats.append(beat)
		taps.append(beat + 70.0 + wobble[i])
	var result: Dictionary = _suggest(TapAlong.match_taps(beats, taps, 370.0))
	assert_true(result["ok"])
	assert_eq(result["offset_ms"], 70)
