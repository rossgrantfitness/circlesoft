extends TestCase
## HitShapes: the ring (jump it) and the beam (dash through it, stand outside the fan, run with it).

const STOMP_RING: Dictionary = {"shape": "ring", "inner_start_m": 0.6, "width_m": 1.1, "expand_mps": 9.0, "max_radius_m": 7.0, "clear_height_m": 0.6}
const SWEEP: Dictionary = {"shape": "beam", "length_m": 38.0, "width_m": 1.6, "height_m": 1.4, "sweep_deg": 80.0, "sweep_deg_per_s": 55.0}


func _ring_box() -> Dictionary:
	var moves: Dictionary = CombatData.moves()
	for box: Variant in (moves["sets"]["hushmaster"]["moves"]["leg_stomp"]["hitboxes"] as Array):
		if str((box as Dictionary).get("shape", "")) == "ring":
			return box as Dictionary
	return {}


func test_the_stomp_ring_in_the_data_is_the_one_these_tests_use() -> void:
	var box: Dictionary = _ring_box()
	for key: String in ["inner_start_m", "width_m", "expand_mps", "max_radius_m", "clear_height_m"]:
		assert_eq(float(box[key]), float(STOMP_RING[key]), key)


func test_the_ring_spreads_at_the_data_speed() -> void:
	assert_almost_eq(HitShapes.ring_radius(STOMP_RING, 0.0), 0.6)
	assert_almost_eq(HitShapes.ring_radius(STOMP_RING, 0.5), 5.1)


func test_the_ring_hits_a_runner_standing_where_its_band_is() -> void:
	# After 0.3 s the band is 1.7 m to 2.7 m out (outer = 0.6 + 2.7 = 3.3, inner = 2.2)
	assert_true(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(3.0, 0, 0), 0.3))
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(6.0, 0, 0), 0.3), "not out there yet")
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(0.3, 0, 0), 0.3), "and already past the middle")


func test_jumping_clears_the_ring() -> void:
	assert_true(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(3.0, 0.5, 0), 0.3), "0.5 m up is still inside its height")
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(3.0, 0.6, 0), 0.3), "feet at 0.6 m clear it")
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.3, Vector3(3.0, 1.4, 0), 0.3))


func test_the_ring_is_measured_from_the_floor_it_stands_on() -> void:
	assert_false(HitShapes.ring_hits(Vector3(0, 3, 0), STOMP_RING, 0.3, Vector3(3.0, 3.8, 0), 0.3), "a 3 m plateau: 0.8 m up is clear")
	assert_true(HitShapes.ring_hits(Vector3(0, 3, 0), STOMP_RING, 0.3, Vector3(3.0, 3.1, 0), 0.3))


func test_the_ring_stops_at_its_maximum_radius() -> void:
	assert_false(HitShapes.ring_finished(STOMP_RING, 0.5))
	assert_true(HitShapes.ring_finished(STOMP_RING, 0.75), "0.6 + 9 x 0.75 = 7.35 m: spent")
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 5.0, Vector3(9.0, 0, 0), 0.3), "nothing out beyond the maximum")
	assert_false(HitShapes.ring_hits(Vector3.ZERO, STOMP_RING, 0.8, Vector3(6.5, 0, 0), 0.3), "and a spent ring does not park at 7 m and hit late")


func test_the_beam_hits_what_is_along_its_line() -> void:
	assert_true(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(0, 0, 10), 0.3, 0.95))
	assert_false(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(3, 0, 10), 0.3, 0.95), "3 m to the side")
	assert_false(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(0, 0, 40), 0.3, 0.95), "beyond 38 m")
	assert_false(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(0, 0, -5), 0.3, 0.95), "behind the dish")


func test_the_beam_follows_its_yaw() -> void:
	var quarter: float = PI * 0.5
	assert_true(HitShapes.beam_hits(Vector3.ZERO, quarter, SWEEP, Vector3(10, 0, 0), 0.3, 0.95), "yaw 90 points to +X")
	assert_false(HitShapes.beam_hits(Vector3.ZERO, quarter, SWEEP, Vector3(0, 0, 10), 0.3, 0.95))


func test_the_beam_is_a_slab_so_a_jump_above_it_clears() -> void:
	assert_true(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(0, 0.5, 10), 0.3, 0.95))
	assert_false(HitShapes.beam_hits(Vector3.ZERO, 0.0, SWEEP, Vector3(0, 1.5, 10), 0.3, 0.95), "feet above 1.4 m")


func test_the_beam_swings_at_the_data_rate_and_stops_at_the_fan_edge() -> void:
	assert_almost_eq(HitShapes.beam_yaw(SWEEP, 0.0, 1.0, 1.0), 1.0)
	assert_almost_eq(rad_to_deg(HitShapes.beam_yaw(SWEEP, 1.0, 0.0, 1.0)), 55.0, 0.01)
	assert_almost_eq(rad_to_deg(HitShapes.beam_yaw(SWEEP, 1.0, 0.0, -1.0)), -55.0, 0.01, "the other way")
	assert_almost_eq(rad_to_deg(HitShapes.beam_yaw(SWEEP, 3.0, 0.0, 1.0)), 80.0, 0.01, "never past the fan")


func test_the_fan_edges_are_where_the_floor_line_is_drawn() -> void:
	var edges: Vector2 = HitShapes.fan_edges(SWEEP, 0.0, 1.0)
	assert_almost_eq(edges.x, 0.0)
	assert_almost_eq(rad_to_deg(edges.y), 80.0, 0.01)


func test_a_runner_going_with_the_beam_is_hit_only_if_it_catches_her() -> void:
	# She starts 10 m out at the beam's start line and runs round at 4 m/s (0.4 rad/s); the beam swings 0.96 rad/s: it catches her.
	var caught: bool = false
	for step_index: int in range(150):
		var age: float = float(step_index) / 100.0
		var around: float = 0.0 + 0.4 * age
		var pos: Vector3 = Vector3(sin(around) * 10.0, 0, cos(around) * 10.0)
		if HitShapes.beam_hits(Vector3.ZERO, HitShapes.beam_yaw(SWEEP, age, -0.4, 1.0), SWEEP, pos, 0.3, 0.95):
			caught = true
	assert_true(caught)
