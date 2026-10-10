extends TestCase
## StyleMeter (Noise) and LightsOn: variety, rank drops, thresholds, and the Lights On stub.

const STYLE: Dictionary = {
	"max_points": 100,
	"ranks": [{"id": "quiet", "name": "", "at": 0}, {"id": "nice", "name": "Nice!", "at": 20},
		{"id": "rad", "name": "Rad!", "at": 50}, {"id": "totally_rad", "name": "TOTALLY RAD!", "at": 80}],
	"variety": {"window_ms": 4000, "repeat_mult": 0.5, "min_mult": 0.2},
	"drain": {"idle_ms": 2000, "per_s": 10.0},
	"bonuses": {"parry": 12, "perfect_parry": 20, "perfect_dodge": 15, "launch": 8, "air_hit": 3},
	"lights_on": {"duration_s": 10.0, "damage_mult": 1.5, "super_armor": true},
}


func _meter() -> StyleMeter:
	return StyleMeter.from_data(STYLE)


func test_hits_fill_the_meter() -> void:
	var meter: StyleMeter = _meter()
	assert_almost_eq(meter.points(), 0.0)
	meter.add_hit(&"light_1", 10.0, 0.0)
	assert_almost_eq(meter.points(), 10.0)
	assert_almost_eq(meter.fill(), 0.1)


func test_the_same_move_repeated_scores_less_each_time() -> void:
	var meter: StyleMeter = _meter()
	meter.add_hit(&"light_1", 10.0, 0.0)
	var after_one: float = meter.points()
	meter.add_hit(&"light_1", 10.0, 500.0)
	var second: float = meter.points() - after_one
	meter.add_hit(&"light_1", 10.0, 1000.0)
	var third: float = meter.points() - after_one - second
	assert_almost_eq(second, 5.0, 0.0001)
	assert_almost_eq(third, 2.5, 0.0001)
	assert_lt(third, second)
	assert_lt(second, 10.0)


func test_variety_scores_more_than_repeating() -> void:
	var varied: StyleMeter = _meter()
	for move: StringName in [&"light_1", &"light_2", &"heavy", &"launcher"]:
		varied.add_hit(move, 10.0, 0.0)
	var spam: StyleMeter = _meter()
	for i: int in range(4):
		spam.add_hit(&"light_1", 10.0, 0.0)
	assert_gt(varied.points(), spam.points())
	assert_almost_eq(varied.points(), 40.0)


func test_the_repeat_penalty_has_a_floor_and_expires() -> void:
	var meter: StyleMeter = _meter()
	for i: int in range(8):
		meter.add_hit(&"light_1", 10.0, float(i))
	var before: float = meter.points()
	meter.add_hit(&"light_1", 10.0, 9.0)
	assert_almost_eq(meter.points() - before, 2.0, 0.0001, "never below 20 percent")
	var later: StyleMeter = _meter()
	later.add_hit(&"light_1", 10.0, 0.0)
	later.add_hit(&"light_1", 10.0, 4500.0)
	assert_almost_eq(later.points(), 20.0, 0.0001, "past the variety window it scores in full again")


func test_bonuses_use_the_style_numbers() -> void:
	var meter: StyleMeter = _meter()
	meter.add_bonus(&"parry", 0.0)
	assert_almost_eq(meter.points(), 12.0)
	meter.add_bonus(&"perfect_dodge", 0.0)
	assert_almost_eq(meter.points(), 27.0)
	meter.add_bonus(&"nonsense", 0.0)
	assert_almost_eq(meter.points(), 27.0)


func test_rank_thresholds() -> void:
	var meter: StyleMeter = _meter()
	assert_eq(meter.rank()["id"], &"quiet")
	meter.set_points(19.9)
	assert_eq(meter.rank()["index"], 0)
	meter.set_points(20.0)
	assert_eq(meter.rank()["id"], &"nice")
	assert_eq(meter.rank()["name"], "Nice!")
	meter.set_points(50.0)
	assert_eq(meter.rank()["id"], &"rad")
	meter.set_points(79.9)
	assert_eq(meter.rank()["id"], &"rad")
	meter.set_points(80.0)
	assert_eq(meter.rank()["id"], &"totally_rad")
	assert_eq(meter.rank()["name"], "TOTALLY RAD!")


func test_taking_damage_drops_a_rank() -> void:
	var meter: StyleMeter = _meter()
	meter.set_points(85.0)
	meter.took_damage(0.0)
	assert_eq(meter.rank()["id"], &"rad", "from TOTALLY RAD to Rad")
	assert_almost_eq(meter.points(), 50.0)
	meter.took_damage(0.0)
	assert_eq(meter.rank()["id"], &"nice")
	meter.took_damage(0.0)
	assert_eq(meter.rank()["id"], &"quiet")
	assert_almost_eq(meter.points(), 0.0)
	meter.took_damage(0.0)
	assert_almost_eq(meter.points(), 0.0)


func test_the_meter_drains_slowly_only_when_idle() -> void:
	var meter: StyleMeter = _meter()
	meter.add_hit(&"heavy", 40.0, 0.0)
	meter.step(1000.0)
	assert_almost_eq(meter.points(), 40.0, 0.0001, "still inside idle_ms")
	meter.step(2000.0)
	meter.step(3000.0)
	assert_almost_eq(meter.points(), 20.0, 0.0001, "10 per second once idle_ms (2 s) has passed")
	meter.add_hit(&"launcher", 10.0, 3000.0)
	meter.step(4000.0)
	assert_almost_eq(meter.points(), 30.0, 0.0001, "a fresh hit pauses the drain again")
	for i: int in range(20):
		meter.step(10000.0 + 1000.0 * float(i))
	assert_almost_eq(meter.points(), 0.0, 0.0001, "never below zero")


func test_reset_and_cap() -> void:
	var meter: StyleMeter = _meter()
	meter.add_hit(&"a", 500.0, 0.0)
	assert_almost_eq(meter.points(), 100.0)
	assert_true(meter.is_full())
	meter.reset()
	assert_almost_eq(meter.points(), 0.0)
	assert_false(meter.is_full())


func test_the_real_style_file_has_the_approved_stencil_ranks() -> void:
	var meter: StyleMeter = StyleMeter.load_default()
	var names: Array[String] = []
	meter.set_points(meter.max_points())
	for points: float in [0.0, 25.0, 55.0, 85.0]:
		meter.set_points(points)
		names.append(str(meter.rank()["name"]))
	assert_eq(names, ["", "Nice!", "Rad!", "TOTALLY RAD!"] as Array[String])


# ---- Lights On ----

func test_lights_on_waits_for_a_full_meter() -> void:
	var meter: StyleMeter = _meter()
	var lights: LightsOn = LightsOn.from_data(STYLE, meter)
	assert_false(lights.can_start(meter))
	meter.set_points(99.0)
	assert_false(lights.can_start(meter))
	meter.set_points(100.0)
	assert_true(lights.can_start(meter))


func test_lights_on_lasts_its_duration_drains_the_meter_and_buffs() -> void:
	var meter: StyleMeter = _meter()
	var lights: LightsOn = LightsOn.from_data(STYLE, meter)
	meter.set_points(100.0)
	assert_almost_eq(float(lights.buffs()["damage_mult"]), 1.0, 0.0001, "no buff before it starts")
	lights.start(1000.0)
	assert_true(lights.is_active())
	assert_false(lights.can_start(meter), "cannot start twice")
	assert_almost_eq(float(lights.buffs()["damage_mult"]), 1.5)
	assert_true(lights.buffs()["super_armor"])
	lights.step(6000.0)
	assert_true(lights.is_active())
	assert_almost_eq(lights.remaining_s(), 5.0, 0.0001)
	assert_almost_eq(meter.points(), 50.0, 0.0001, "halfway through, half the meter is left")
	var ended: bool = lights.step(11000.0)
	assert_true(ended)
	assert_false(lights.is_active())
	assert_almost_eq(meter.points(), 0.0, 0.0001)
	assert_almost_eq(float(lights.buffs()["damage_mult"]), 1.0, 0.0001)
	assert_false(lights.buffs()["super_armor"])


func test_lights_on_ignores_extra_points_while_it_runs() -> void:
	var meter: StyleMeter = _meter()
	var lights: LightsOn = LightsOn.from_data(STYLE, meter)
	meter.set_points(100.0)
	lights.start(0.0)
	meter.add_hit(&"x", 50.0, 1000.0)
	lights.step(5000.0)
	assert_almost_eq(meter.points(), 50.0, 0.0001, "the drain curve is authoritative")


func test_a_varied_combo_fills_noise_from_the_real_data() -> void:
	var meter: StyleMeter = StyleMeter.load_default()
	var moves: Array[StringName] = [&"light_1", &"light_2", &"light_3", &"heavy", &"launcher", &"air_1", &"air_2", &"air_3"]
	var points: Array[float] = [10, 10, 14, 20, 15, 12, 12, 15]
	for i: int in range(moves.size()):
		meter.add_hit(moves[i], points[i], float(i) * 300.0)
		meter.add_bonus(&"air_hit", float(i) * 300.0)
	assert_gt(meter.points(), 90.0, "one varied combo gets close to Lights On")
