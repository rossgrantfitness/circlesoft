extends TestCase
## HackGeometry: the pure maths under the Zap Drone's flight, the EMP ring and the automatic picker's cone.


func test_distance_to_an_upright_is_measured_to_the_nearest_point_of_its_axis() -> void:
	var base: Vector3 = Vector3(2.0, 0.0, 0.0)
	assert_almost_eq(HackGeometry.distance_to_upright(Vector3(0.0, 0.5, 0.0), base, 1.0), 2.0)
	assert_almost_eq(HackGeometry.distance_to_upright(Vector3(2.0, 3.0, 0.0), base, 1.0), 2.0, 0.0001, "above the head")
	assert_almost_eq(HackGeometry.distance_to_upright(Vector3(2.0, -1.0, 1.0), base, 1.0), sqrt(2.0), 0.0001, "below the feet")


func test_a_straight_flight_through_a_fighter_hits_it() -> void:
	assert_true(HackGeometry.segment_hits_upright(Vector3(0, 0.8, 0), Vector3(0, 0.8, 10), Vector3(0, 0, 5), 1.2, 0.5))


func test_a_flight_that_passes_wide_misses() -> void:
	assert_false(HackGeometry.segment_hits_upright(Vector3(0, 0.8, 0), Vector3(0, 0.8, 10), Vector3(2, 0, 5), 1.2, 0.5))


func test_a_flight_that_stops_short_misses() -> void:
	assert_false(HackGeometry.segment_hits_upright(Vector3(0, 0.8, 0), Vector3(0, 0.8, 3), Vector3(0, 0, 5), 1.2, 0.5))


func test_a_fast_drone_cannot_jump_over_a_fighter_in_one_step() -> void:
	# 60 m in one frame still catches a thin fighter in the way.
	assert_true(HackGeometry.segment_hits_upright(Vector3(0, 0.8, 0), Vector3(0, 0.8, 60), Vector3(0, 0, 30), 1.0, 0.1))


func test_a_flight_over_a_short_fighter_misses() -> void:
	assert_false(HackGeometry.segment_hits_upright(Vector3(0, 3.0, 0), Vector3(0, 3.0, 10), Vector3(0, 0, 5), 1.2, 0.5))


func test_flat_distance_ignores_height() -> void:
	assert_almost_eq(HackGeometry.flat_distance(Vector3(0, 0, 0), Vector3(3, 50, 4)), 5.0)


func test_the_ring_counts_a_body_by_its_edge() -> void:
	assert_true(HackGeometry.in_ring(Vector3.ZERO, Vector3(4.8, 0, 0), 0.36, 4.5), "centre 4.8 m away, edge at 4.44 m")
	assert_false(HackGeometry.in_ring(Vector3.ZERO, Vector3(5.0, 0, 0), 0.36, 4.5), "centre 5 m away, edge at 4.64 m")


func test_aim_angle_is_how_far_round_from_the_aim_a_thing_sits() -> void:
	assert_almost_eq(HackGeometry.aim_angle_deg(Vector3.ZERO, Vector3(0, 0, -5), Vector3(0, 0, -1)), 0.0, 0.01)
	assert_almost_eq(HackGeometry.aim_angle_deg(Vector3.ZERO, Vector3(5, 0, 0), Vector3(0, 0, -1)), 90.0, 0.01)
	assert_almost_eq(HackGeometry.aim_angle_deg(Vector3.ZERO, Vector3(0, 0, 5), Vector3(0, 0, -1)), 180.0, 0.01)
