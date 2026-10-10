extends TestCase
## ParryJudge: one-sided, first press only, windows scale, and the attacker's clock decides.

const WINDOW: Dictionary = {"nice_ms": 220.0, "rad_ms": 130.0, "totally_rad_ms": 70.0}
const IMPACT: int = 2000000
const LISTEN: int = 400


func _judge(presses: Array[int], mult: float = 1.0, offset: int = 0) -> Dictionary:
	return ParryJudge.judge(presses, IMPACT, WINDOW, mult, offset, LISTEN)


func _early(ms: float) -> Array[int]:
	return [IMPACT - int(ms * 1000.0)]


func test_inclusive_boundaries_early_side() -> void:
	assert_eq(_judge(_early(0.0))["rating"], "totally_rad", "right on contact")
	assert_eq(_judge(_early(70.0))["rating"], "totally_rad")
	assert_eq(_judge(_early(70.1))["rating"], "rad")
	assert_eq(_judge(_early(130.0))["rating"], "rad")
	assert_eq(_judge(_early(130.1))["rating"], "nice")
	assert_eq(_judge(_early(220.0))["rating"], "nice")
	assert_eq(_judge(_early(220.1))["rating"], "miss")


func test_a_press_after_contact_is_a_miss() -> void:
	var late: Dictionary = _judge([IMPACT + 1000] as Array[int])
	assert_eq(late["rating"], "miss")
	assert_false(late["pressed"])
	assert_eq(_judge([IMPACT + 20000] as Array[int])["rating"], "miss", "even 20 ms late: the hit has landed")


func test_a_press_at_the_listening_edge_counts_and_one_just_before_does_not() -> void:
	var edge: Dictionary = _judge(_early(400.0))
	assert_true(edge["pressed"])
	assert_eq(edge["rating"], "miss", "heard, but 400 ms early is outside Nice")
	var before: Dictionary = _judge(_early(401.0))
	assert_false(before["pressed"], "not even listened to")


func test_only_the_first_press_counts() -> void:
	# A too-early press followed by a perfect one: mashing earns nothing.
	var mash: Dictionary = _judge([IMPACT - 350000, IMPACT - 10000] as Array[int])
	assert_eq(mash["rating"], "miss")
	assert_almost_eq(float(mash["delta_ms"]), -350.0)
	# A good first press, then more mashing: the first one is the rating.
	var good: Dictionary = _judge([IMPACT - 30000, IMPACT - 10000, IMPACT - 5000] as Array[int])
	assert_eq(good["rating"], "totally_rad")


func test_presses_may_arrive_in_any_order() -> void:
	var result: Dictionary = _judge([IMPACT - 10000, IMPACT - 150000] as Array[int])
	assert_eq(result["rating"], "nice", "the earlier press (150 ms before) is the first")


func test_no_press_is_a_miss() -> void:
	var result: Dictionary = _judge([] as Array[int])
	assert_eq(result["rating"], "miss")
	assert_false(result["pressed"])


func test_wide_windows_and_the_knob_widen_every_boundary() -> void:
	var mods: Dictionary = {"wide_windows": 1.5, "defending_block": 1.25, "butterfingers": 0.75, "fired_up": 1.25}
	var mult: float = ParryJudge.window_mult(mods, true, 1.0)
	assert_almost_eq(mult, 1.5)
	assert_eq(_judge(_early(100.0), mult)["rating"], "totally_rad", "70 x 1.5 = 105")
	assert_eq(_judge(_early(105.0), mult)["rating"], "totally_rad")
	assert_eq(_judge(_early(105.1), mult)["rating"], "rad")
	assert_eq(_judge(_early(330.0), mult)["rating"], "nice")
	assert_eq(_judge(_early(330.1), mult)["rating"], "miss")
	assert_almost_eq(ParryJudge.window_mult(mods, false, 2.0), 2.0, 0.0001, "the parry_window_scale knob")
	assert_almost_eq(ParryJudge.window_mult(mods, true, 2.0), 3.0, 0.0001, "and they stack")
	assert_eq(_judge(_early(60.0), 0.5)["rating"], "rad", "a narrower window (35 ms) turns 60 ms into Rad")


func test_the_timing_offset_moves_the_cue() -> void:
	# +50 ms offset: the cue is 50 ms after contact, so a press 50 ms before contact is 100 ms early.
	var shifted: Dictionary = _judge(_early(50.0), 1.0, 50)
	assert_almost_eq(float(shifted["delta_ms"]), -100.0)
	assert_eq(shifted["rating"], "rad")
	# -50 ms offset: the cue is 50 ms before contact, a press there is dead on.
	var other: Dictionary = _judge(_early(50.0), 1.0, -50)
	assert_almost_eq(float(other["delta_ms"]), 0.0)
	assert_eq(other["rating"], "totally_rad")
	assert_eq(_judge([IMPACT + 10000] as Array[int], 1.0, 50)["rating"], "miss", "a press after contact stays a miss whatever the offset")


func test_judging_on_a_frozen_or_slowed_attacker_clock_does_not_move_the_window() -> void:
	# Real timeline (usec): enemy winds up, Red presses at real 1.00 s, a hit-stop freezes the enemy for
	# 200 ms, then it hits at real 1.30 s. On the enemy's own clock the press is 100 ms of ITS time early.
	var clock: CombatClock = CombatClock.new(0)
	clock.step(900000, 1.0)       # enemy time 0.9 s
	clock.step(100000, 1.0)       # real 1.0 s: Red presses here
	var press_real: int = 1000000
	clock.step(200000, 0.0)       # frozen
	clock.step(100000, 1.0)       # real 1.3 s: contact
	var press_local: int = clock.local_at_real(press_real)
	var impact_local: int = clock.now_usec()
	assert_eq(impact_local - press_local, 100000, "a 200 ms freeze took nothing off the window")
	var result: Dictionary = ParryJudge.judge([press_local] as Array[int], impact_local, WINDOW, 1.0, 0, LISTEN)
	assert_eq(result["rating"], "rad")
	# And in slow motion: the enemy runs at 25%, so 400 real ms between press and contact are 100 ms of enemy time.
	var slow: CombatClock = CombatClock.new(0)
	slow.step(100000, 0.25)
	var slow_press: int = slow.local_at_real(100000)
	slow.step(400000, 0.25)
	var verdict: Dictionary = ParryJudge.judge([slow_press] as Array[int], slow.now_usec(), WINDOW, 1.0, 0, LISTEN)
	assert_almost_eq(float(verdict["delta_ms"]), -100.0, 0.01)
	assert_eq(verdict["rating"], "rad")


func test_the_real_timing_file_has_a_parry_entry() -> void:
	var window: Dictionary = CombatData.parry_window()
	assert_lt(float(window["totally_rad_ms"]), float(window["rad_ms"]))
	assert_lt(float(window["rad_ms"]), float(window["nice_ms"]))
	assert_gt(CombatData.parry_listen_ms(), int(window["nice_ms"]))
