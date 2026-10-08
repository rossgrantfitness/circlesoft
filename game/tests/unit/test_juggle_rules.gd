extends TestCase
## JuggleRules: lift shrinks with each air hit, low gravity right after a hit, the juggle cap.

const CFG: Dictionary = {"lift_falloff": 0.8, "min_lift_mps": 3.0, "air_hit_lift_mps": 4.0, "max_hits": 5,
	"float_ms": 400, "float_gravity_scale": 0.2, "float_ramp_ms": 200}


func test_lift_shrinks_with_every_air_hit() -> void:
	var previous: float = JuggleRules.lift_for(10.0, 0, CFG)
	assert_almost_eq(previous, 10.0, 0.0001, "the first hit gets the full launch")
	for count: int in range(1, 5):
		var lift: float = JuggleRules.lift_for(10.0, count, CFG)
		assert_lt(lift, previous, "hit %d lifts less" % count)
		previous = lift
	assert_almost_eq(JuggleRules.lift_for(10.0, 2, CFG), 6.4, 0.0001)


func test_lift_never_falls_below_the_floor_and_zero_stays_zero() -> void:
	assert_almost_eq(JuggleRules.lift_for(10.0, 30, CFG), 3.0, 0.0001)
	assert_almost_eq(JuggleRules.lift_for(2.0, 30, CFG), 2.0, 0.0001, "the floor never exceeds the launch itself")
	assert_almost_eq(JuggleRules.lift_for(0.0, 0, CFG), 0.0)
	assert_almost_eq(JuggleRules.lift_for(-5.0, 0, CFG), 0.0)


func test_air_hits_lift_a_little_and_a_little_less_each_time() -> void:
	assert_almost_eq(JuggleRules.air_lift_for(0, CFG), 4.0, 0.0001)
	assert_lt(JuggleRules.air_lift_for(3, CFG), JuggleRules.air_lift_for(1, CFG))
	assert_ge(JuggleRules.air_lift_for(50, CFG), 3.0 - 0.0001)


func test_gravity_is_low_right_after_a_hit_then_returns() -> void:
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(0.0, 1.0, CFG), 0.2, 0.0001)
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(400.0, 1.0, CFG), 0.2, 0.0001, "still low at the end of the float")
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(500.0, 1.0, CFG), 0.6, 0.0001, "halfway through the ramp")
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(600.0, 1.0, CFG), 1.0, 0.0001)
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(5000.0, 1.0, CFG), 1.0, 0.0001)


func test_juggle_float_knob_stretches_or_removes_the_float() -> void:
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(600.0, 2.0, CFG), 0.2, 0.0001, "double float: still low at 600 ms")
	assert_almost_eq(JuggleRules.gravity_scale_after_hit(100.0, 0.0, CFG), 1.0, 0.0001, "knob at zero: no float")
	assert_gt(JuggleRules.gravity_scale_after_hit(300.0, 0.5, CFG), 0.2, "half float is already ramping at 300 ms")


func test_the_juggle_cap() -> void:
	assert_true(JuggleRules.can_juggle(0, CFG))
	assert_true(JuggleRules.can_juggle(4, CFG))
	assert_false(JuggleRules.can_juggle(5, CFG))
	assert_false(JuggleRules.can_juggle(9, CFG))


func test_the_real_numbers_let_a_launcher_plus_four_air_hits_stay_up() -> void:
	# The launcher, then four air hits, each keeping the target in the air (contract: bot test 1).
	assert_true(JuggleRules.can_juggle(5))
	assert_gt(JuggleRules.air_lift_for(4), 0.0)
	assert_gt(JuggleRules.lift_for(11.0, 0), JuggleRules.air_lift_for(0))
