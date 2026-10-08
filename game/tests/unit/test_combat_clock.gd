extends TestCase
## CombatClock: a fighter's own time, and turning a real press stamp into it.

const STEP: int = 16667


func test_normal_scale_follows_real_time() -> void:
	var clock: CombatClock = CombatClock.new()
	for i: int in range(60):
		clock.step(STEP, 1.0)
	assert_eq(clock.now_usec(), 60 * STEP)
	assert_almost_eq(clock.scale(), 1.0)


func test_frozen_clock_stands_still_and_slow_clock_runs_slow() -> void:
	var clock: CombatClock = CombatClock.new()
	clock.step(100000, 0.0)
	assert_eq(clock.now_usec(), 0)
	clock.step(100000, 0.25)
	assert_eq(clock.now_usec(), 25000)
	assert_almost_eq(clock.scale(), 0.25)


func test_fractions_are_carried_not_lost() -> void:
	var clock: CombatClock = CombatClock.new()
	for i: int in range(1000):
		clock.step(1, 0.5)
	assert_eq(clock.now_usec(), 500, "1000 steps of 1 usec at half speed")


func test_negative_inputs_never_run_the_clock_backwards() -> void:
	var clock: CombatClock = CombatClock.new()
	clock.step(-500, 1.0)
	clock.step(1000, -3.0)
	assert_eq(clock.now_usec(), 0)


func test_local_at_real_through_a_freeze() -> void:
	var clock: CombatClock = CombatClock.new(1000000)
	clock.step(100000, 1.0)       # real 1.0s..1.1s runs
	clock.step(50000, 0.0)        # real 1.1s..1.15s frozen
	clock.step(100000, 1.0)       # real 1.15s..1.25s runs
	assert_eq(clock.now_usec(), 200000)
	assert_eq(clock.local_at_real(1050000), 50000, "before the freeze")
	assert_eq(clock.local_at_real(1100000), 100000, "the moment the freeze began")
	assert_eq(clock.local_at_real(1125000), 100000, "inside the freeze: no local time passed")
	assert_eq(clock.local_at_real(1200000), 150000, "after the freeze")


func test_local_at_real_through_slow_motion() -> void:
	var clock: CombatClock = CombatClock.new(0)
	clock.step(100000, 1.0)
	clock.step(100000, 0.25)
	clock.step(100000, 1.0)
	assert_eq(clock.local_at_real(150000), 100000 + 12500)
	assert_eq(clock.local_at_real(250000), 100000 + 25000 + 50000)


func test_local_at_real_for_a_press_newer_than_the_last_step_uses_the_current_scale() -> void:
	var clock: CombatClock = CombatClock.new(0)
	clock.step(100000, 0.5)
	assert_eq(clock.local_at_real(100000), 50000)
	assert_eq(clock.local_at_real(110000), 55000)
	clock.step(100000, 0.0)
	assert_eq(clock.local_at_real(230000), 50000, "a frozen clock stays put")


func test_history_is_bounded_but_recent_stamps_stay_right() -> void:
	var clock: CombatClock = CombatClock.new(0)
	for i: int in range(CombatClock.MAX_SEGMENTS + 100):
		clock.step(1000, 1.0)
	var recent: int = clock.real_now_usec() - 5000
	assert_eq(clock.local_at_real(recent), clock.now_usec() - 5000)
	assert_le(clock.local_at_real(0), clock.now_usec(), "very old stamps do not crash")


func test_anchor_real_pins_the_axis() -> void:
	var clock: CombatClock = CombatClock.new()
	clock.anchor_real(5000000)
	clock.step(1000, 1.0)
	assert_eq(clock.real_now_usec(), 5001000)
	assert_eq(clock.local_at_real(5001000), 1000)


func test_is_a_battle_clock_and_never_touches_engine_time_scale() -> void:
	var before: float = Engine.time_scale
	var clock: CombatClock = CombatClock.new()
	clock.step(1000, 0.0)
	assert_true(clock is BattleClock)
	assert_almost_eq(Engine.time_scale, before)
