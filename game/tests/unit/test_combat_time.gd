extends TestCase
## CombatTime: hit-stop, the Lamp Flare, and who runs at what speed.

const RED: StringName = &"red"
const G1: StringName = &"grunt_1"
const G2: StringName = &"grunt_2"
const FAR: StringName = &"grunt_far"
const FRAME: float = 1.0 / 60.0


func _ids(list: Array[StringName]) -> Array[StringName]:
	return list


func _time() -> CombatTime:
	var time: CombatTime = CombatTime.new()
	time.player_id = RED
	return time


func test_hit_stop_freezes_both_sides_and_counts_down_in_real_time() -> void:
	var time: CombatTime = _time()
	time.add_hit_stop(_ids([RED, G1]), 50.0)
	assert_almost_eq(time.scale_for(RED), 0.0)
	assert_almost_eq(time.scale_for(G1), 0.0)
	assert_almost_eq(time.scale_for(G2), 1.0, 0.0001, "bystanders keep running")
	var lived_red: float = 0.0
	var real: float = 0.0
	for i: int in range(6):
		time.step(FRAME)
		real += FRAME
		lived_red += time.delta_for(RED, FRAME)
	assert_almost_eq(lived_red, real - 0.05, 0.0005, "exactly 50 ms of real time was lost")
	assert_almost_eq(time.scale_for(RED), 1.0)
	assert_false(time.is_frozen(G1))


func test_longest_hit_stop_wins_not_the_sum() -> void:
	var time: CombatTime = _time()
	time.add_hit_stop(_ids([RED]), 40.0)
	time.add_hit_stop(_ids([RED]), 90.0)
	time.add_hit_stop(_ids([RED]), 60.0)
	assert_almost_eq(time.hit_stop_left_ms(RED), 90.0, 0.001)
	time.step(0.05)
	assert_almost_eq(time.hit_stop_left_ms(RED), 40.0, 0.001)
	time.step(0.05)
	assert_false(time.is_frozen(RED))


func test_a_flare_slows_enemies_in_the_glare_but_not_red_or_the_far_ones() -> void:
	var time: CombatTime = _time()
	time.start_flare(2.5, 0.25, _ids([G1, G2]))
	assert_true(time.is_flaring())
	assert_almost_eq(time.scale_for(RED), 1.0)
	assert_almost_eq(time.scale_for(G1), 0.25)
	assert_almost_eq(time.scale_for(G2), 0.25)
	assert_almost_eq(time.scale_for(FAR), 1.0, 0.0001, "outside the glare")
	time.step(FRAME)
	assert_almost_eq(time.delta_for(G1, FRAME), FRAME * 0.25, 0.00001)
	assert_almost_eq(time.delta_for(RED, FRAME), FRAME, 0.00001)


func test_hit_stop_is_not_stretched_by_a_flare() -> void:
	var time: CombatTime = _time()
	time.start_flare(2.5, 0.25, _ids([G1]))
	time.add_hit_stop(_ids([G1]), 100.0)
	time.step(0.05)
	assert_almost_eq(time.hit_stop_left_ms(G1), 50.0, 0.001, "50 ms real passed, 50 ms left")
	time.step(0.05)
	assert_false(time.is_frozen(G1))


func test_flare_timer_runs_on_reds_clock_and_pauses_in_her_hit_stop() -> void:
	var time: CombatTime = _time()
	time.start_flare(2.0, 0.25, _ids([G1]))
	time.step(0.5)
	assert_almost_eq(time.flare_left_s(), 1.5, 0.0001)
	time.add_hit_stop(_ids([RED, G1]), 200.0)
	time.step(0.2)
	assert_almost_eq(time.flare_left_s(), 1.5, 0.0001, "Red was frozen the whole step")
	time.step(0.2)
	assert_almost_eq(time.flare_left_s(), 1.3, 0.0001)
	time.add_hit_stop(_ids([G1]), 300.0)
	time.step(0.1)
	assert_almost_eq(time.flare_left_s(), 1.2, 0.0001, "an enemy's hit-stop does not pause the flare")


func test_flare_ends_and_everyone_is_normal_again() -> void:
	var time: CombatTime = _time()
	var ended: Array[bool] = [false]
	time.flare_ended.connect(func() -> void: ended[0] = true)
	time.start_flare(0.1, 0.25, _ids([G1]))
	time.step(0.06)
	assert_true(time.is_flaring())
	time.step(0.06)
	assert_false(time.is_flaring())
	assert_true(ended[0], "flare_ended was emitted")
	assert_almost_eq(time.scale_for(G1), 1.0)
	assert_almost_eq(time.flare_left_s(), 0.0)


func test_flare_started_signal_and_restart() -> void:
	var time: CombatTime = _time()
	var started: Array[int] = [0]
	time.flare_started.connect(func() -> void: started[0] += 1)
	time.start_flare(1.0, 0.5, _ids([G1]))
	time.start_flare(2.0, 0.25, _ids([G2]))
	assert_eq(started[0], 1, "a restart is not a second start")
	assert_almost_eq(time.flare_left_s(), 2.0)
	assert_almost_eq(time.scale_for(G1), 1.0, 0.0001, "the new list replaced the old one")
	assert_almost_eq(time.scale_for(G2), 0.25)


func test_engine_time_scale_is_never_touched() -> void:
	var before: float = Engine.time_scale
	var time: CombatTime = _time()
	time.start_flare(1.0, 0.1, _ids([G1]))
	time.add_hit_stop(_ids([RED]), 100.0)
	time.step(0.016)
	assert_almost_eq(Engine.time_scale, before)
