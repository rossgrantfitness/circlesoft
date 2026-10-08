extends TestCase
## DashRun and ActionMotion (pure): the dash covers its distance at any frame rate, its i-frames last
## their time, and the jump / fall / acceleration numbers behave.

func _distance_at_fps(fps: int, distance: float, time_ms: float, decay: float) -> float:
	var run: DashRun = DashRun.create(Vector3.RIGHT, distance, time_ms, 150.0, decay)
	var moved: Vector3 = Vector3.ZERO
	var step: float = 1.0 / float(fps)
	var frames: int = 0
	while not run.is_done() and frames < 1000:
		moved += run.advance(step) * step
		frames += 1
	return moved.x


func test_distance_is_exact_at_any_frame_rate() -> void:
	for fps: int in [30, 60, 90, 144, 240]:
		for decay: float in [0.0, 0.45, 0.9]:
			assert_almost_eq(_distance_at_fps(fps, 4.0, 180.0, decay), 4.0, 0.0001, "fps %d decay %s" % [fps, decay])


func test_a_long_frame_cannot_overshoot_the_end() -> void:
	var run: DashRun = DashRun.create(Vector3.FORWARD, 4.0, 180.0, 150.0, 0.45)
	var moved: Vector3 = run.advance(1.0)
	assert_almost_eq(moved.length() * 1.0, 4.0, 0.0001, "one huge step reports an average that adds up to the distance")
	assert_true(run.is_done())
	assert_eq(run.advance(0.016), Vector3.ZERO)


func test_the_dash_starts_fast_and_eases_off() -> void:
	var run: DashRun = DashRun.create(Vector3.RIGHT, 4.0, 180.0, 150.0, 0.5)
	var first: float = run.advance(0.01).length()
	run.advance(0.15)
	var last: float = run.advance(0.01).length()
	assert_gt(first, last * 1.5)
	var flat: DashRun = DashRun.create(Vector3.RIGHT, 4.0, 180.0, 150.0, 0.0)
	assert_almost_eq(flat.advance(0.01).length(), 4.0 / 0.18, 0.001, "no decay: constant speed")


func test_iframes_last_their_time_then_stop() -> void:
	var run: DashRun = DashRun.create(Vector3.RIGHT, 4.0, 180.0, 150.0, 0.45)
	assert_true(run.invulnerable(), "from the first instant")
	var frames: int = 0
	while run.invulnerable() and frames < 100:
		run.advance(1.0 / 60.0)
		frames += 1
	assert_almost_eq(float(frames) * 1000.0 / 60.0, 150.0, 17.0, "i-frames ran 150 ms (within a frame)")
	assert_false(run.invulnerable())
	var none: DashRun = DashRun.create(Vector3.RIGHT, 4.0, 180.0, 0.0, 0.0)
	assert_false(none.invulnerable())


func test_iframes_never_outlast_the_dash() -> void:
	var run: DashRun = DashRun.create(Vector3.RIGHT, 4.0, 100.0, 400.0, 0.0)
	run.advance(1.0)
	assert_false(run.invulnerable())


func test_direction_is_flat_and_falls_back() -> void:
	assert_eq(DashRun.create(Vector3(0, 5, 2), 1.0, 100.0, 0.0, 0.0).direction, Vector3(0, 0, 1))
	assert_eq(DashRun.create(Vector3.ZERO, 1.0, 100.0, 0.0, 0.0).direction, Vector3.FORWARD)


func test_dash_direction_rules() -> void:
	var stick: Vector3 = Vector3(1, 0, 0)
	var facing: Vector3 = Vector3(0, 0, 1)
	assert_eq(ActionMotion.dash_direction(stick, facing, "facing"), stick)
	assert_eq(ActionMotion.dash_direction(Vector3.ZERO, facing, "facing"), facing)
	assert_eq(ActionMotion.dash_direction(Vector3.ZERO, facing, "back"), -facing)


func test_jump_reaches_the_data_height() -> void:
	for scale: float in [0.6, 1.0, 1.8]:
		var g: float = ActionMotion.gravity_for(1.6, 0.36, scale)
		var vy: float = ActionMotion.launch_speed(1.6, g)
		var y: float = 0.0
		var peak: float = 0.0
		for i: int in 600:
			var step: Dictionary = ActionMotion.vertical_step(vy, g, 1.35, 50.0, 1.0 / 120.0, true, 0.0)
			y += float(step["avg"]) / 120.0
			vy = float(step["vy"])
			peak = maxf(peak, y)
		assert_almost_eq(peak, 1.6, 0.02, "gravity scale %s still jumps 1.6 m" % scale)


func test_a_higher_gravity_knob_makes_a_snappier_jump() -> void:
	assert_gt(ActionMotion.gravity_for(1.6, 0.36, 2.0), ActionMotion.gravity_for(1.6, 0.36, 1.0) * 1.9)


func test_releasing_jump_cuts_a_rising_jump_short() -> void:
	var step: Dictionary = ActionMotion.vertical_step(8.0, 25.0, 1.35, 28.0, 1.0 / 60.0, false, 3.0)
	assert_almost_eq(float(step["vy"]), 3.0, 0.0001)
	var held: Dictionary = ActionMotion.vertical_step(8.0, 25.0, 1.35, 28.0, 1.0 / 60.0, true, 3.0)
	assert_gt(float(held["vy"]), 7.0)


func test_falling_is_heavier_and_capped() -> void:
	var rising: Dictionary = ActionMotion.vertical_step(1.0, 25.0, 1.5, 28.0, 0.1, true, 0.0)
	var falling: Dictionary = ActionMotion.vertical_step(-1.0, 25.0, 1.5, 28.0, 0.1, true, 0.0)
	assert_gt(1.0 - float(rising["vy"]), 0.0)
	assert_gt(absf(float(falling["vy"]) + 1.0), absf(float(rising["vy"]) - 1.0), "heavier on the way down")
	var capped: Dictionary = ActionMotion.vertical_step(-27.9, 25.0, 1.5, 28.0, 0.5, true, 0.0)
	assert_almost_eq(float(capped["vy"]), -28.0, 0.0001)


func test_ground_is_snappy_and_air_is_loose() -> void:
	var move: Dictionary = {"ground_accel_mps2": 100.0, "ground_decel_mps2": 80.0, "air_accel_mps2": 20.0}
	var wanted: Vector2 = Vector2(6, 0)
	var ground: Vector2 = ActionMotion.flat_velocity(Vector2.ZERO, wanted, true, move, 0.05)
	var air: Vector2 = ActionMotion.flat_velocity(Vector2.ZERO, wanted, false, move, 0.05)
	assert_almost_eq(ground.x, 5.0, 0.0001)
	assert_almost_eq(air.x, 1.0, 0.0001)
	assert_eq(ActionMotion.flat_velocity(Vector2(6, 0), Vector2.ZERO, true, move, 0.05), Vector2(2, 0))
	assert_eq(ActionMotion.flat_velocity(Vector2(0.5, 0), Vector2.ZERO, true, move, 0.05), Vector2.ZERO, "stops dead, no drifting")


func test_cooldown() -> void:
	assert_eq(ActionMotion.cooldown_left_ms(220.0, 100.0), 120.0)
	assert_eq(ActionMotion.cooldown_left_ms(220.0, 500.0), 0.0)
