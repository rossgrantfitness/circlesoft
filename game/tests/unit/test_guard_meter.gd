extends TestCase
## GuardMeter: blocked hits drain it, a quiet moment refills it, empty means broken.

const GRUNT_GUARD: Dictionary = {"meter": 24, "meter_regen_per_s": 12, "regen_delay_ms": 800}
const BRUTE_GUARD: Dictionary = {"meter": 60, "meter_regen_per_s": 18, "regen_delay_ms": 1000}


func test_three_lights_empty_the_grunts_guard_and_seven_the_brutes() -> void:
	var grunt: GuardMeter = GuardMeter.from_data(GRUNT_GUARD)
	assert_almost_eq(grunt.meter, 24.0)
	grunt.absorb(8.0, 0.0)
	grunt.absorb(8.0, 100.0)
	assert_false(grunt.is_empty())
	grunt.absorb(8.0, 200.0)
	assert_true(grunt.is_empty(), "3 Lights break the Grunt")
	var brute: GuardMeter = GuardMeter.from_data(BRUTE_GUARD)
	for i: int in range(7):
		assert_false(brute.is_empty(), "hit %d" % i)
		brute.absorb(8.0, float(i) * 100.0)
	assert_true(brute.is_empty() or brute.meter < 8.0, "about 7 Lights")


func test_it_never_goes_below_zero() -> void:
	var meter: GuardMeter = GuardMeter.from_data(GRUNT_GUARD)
	meter.absorb(500.0, 0.0)
	assert_almost_eq(meter.meter, 0.0)
	assert_almost_eq(meter.fraction(), 0.0)


func test_it_refills_after_the_delay_at_the_regen_rate() -> void:
	var meter: GuardMeter = GuardMeter.from_data(GRUNT_GUARD)
	meter.absorb(20.0, 1000.0)
	assert_almost_eq(meter.meter, 4.0)
	meter.step(0.5, 1500.0)      # 500 ms after the hit: still inside the 800 ms delay
	assert_almost_eq(meter.meter, 4.0, 0.001, "no refill during the delay")
	meter.step(0.5, 1900.0)      # 900 ms after
	assert_almost_eq(meter.meter, 10.0, 0.001, "12 per second for half a second")
	meter.step(10.0, 3000.0)
	assert_almost_eq(meter.meter, 24.0, 0.001, "capped at the maximum")


func test_refill_resets_it() -> void:
	var meter: GuardMeter = GuardMeter.from_data(BRUTE_GUARD)
	meter.absorb(50.0, 0.0)
	meter.refill()
	assert_almost_eq(meter.fraction(), 1.0)
