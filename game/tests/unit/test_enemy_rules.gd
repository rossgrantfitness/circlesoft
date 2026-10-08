extends TestCase
## EnemyRules: the angle round Red, the rear arc, the guard arc, the wind-up floors and Red's move classes.

const RULES: Dictionary = {"min_windup_ms": 500, "rear_min_windup_ms": 650, "min_aim_lock_before_impact_ms": 150, "rear_arc_deg": 120}


func test_angle_round_red_is_zero_in_front_and_180_behind() -> void:
	var red: Vector3 = Vector3(2, 0, 3)
	var fwd: Vector3 = Vector3.BACK         # +Z
	assert_almost_eq(EnemyRules.relative_angle_deg(red, fwd, red + Vector3(0, 0, 4)), 0.0, 0.01)
	assert_almost_eq(absf(EnemyRules.relative_angle_deg(red, fwd, red + Vector3(0, 0, -4))), 180.0, 0.01)
	assert_almost_eq(absf(EnemyRules.relative_angle_deg(red, fwd, red + Vector3(4, 0, 0))), 90.0, 0.01)
	var turned: Vector3 = Vector3.RIGHT
	assert_almost_eq(EnemyRules.relative_angle_deg(red, turned, red + Vector3(4, 0, 0)), 0.0, 0.01, "in front of a turned Red")


func test_positive_sideways_input_raises_the_angle() -> void:
	# The brain's move_dir.x is "sideways round the player": the body turns it into dir_to x UP. It must raise the angle,
	# or the flanker would run the long way round.
	var red: Vector3 = Vector3.ZERO
	var fwd: Vector3 = Vector3.BACK
	for spot: Vector3 in [Vector3(0, 0, 4), Vector3(3, 0, 3), Vector3(-3, 0, 2), Vector3(2, 0, -3), Vector3(-1, 0, -4)]:
		var dir_to: Vector3 = (red - spot).normalized()
		var side: Vector3 = dir_to.cross(Vector3.UP)
		var before: float = EnemyRules.relative_angle_deg(red, fwd, spot)
		var after: float = EnemyRules.relative_angle_deg(red, fwd, spot + side * 0.05)
		assert_gt(wrapf(after - before, -180.0, 180.0), 0.0, "moving along +x raises the angle at %s" % spot)


func test_the_rear_arc_is_the_120_degrees_behind_her() -> void:
	assert_true(EnemyRules.in_rear_arc(180.0, 120.0))
	assert_true(EnemyRules.in_rear_arc(-125.0, 120.0))
	assert_true(EnemyRules.in_rear_arc(120.0, 120.0))
	assert_false(EnemyRules.in_rear_arc(119.0, 120.0))
	assert_false(EnemyRules.in_rear_arc(0.0, 120.0))


func test_the_guard_covers_only_the_front_arc() -> void:
	var pos: Vector3 = Vector3.ZERO
	var fwd: Vector3 = Vector3.BACK
	assert_true(EnemyRules.in_front_arc(pos, fwd, Vector3(0, 0, 2), 150.0))
	assert_true(EnemyRules.in_front_arc(pos, fwd, Vector3(2, 0, 0.6), 150.0), "inside +-75 degrees")
	assert_false(EnemyRules.in_front_arc(pos, fwd, Vector3(2, 0, -0.6), 150.0), "outside +-75 degrees: the side/back is open")
	assert_false(EnemyRules.in_front_arc(pos, fwd, Vector3(0, 0, -2), 140.0))


func test_the_windup_floors() -> void:
	assert_almost_eq(EnemyRules.min_windup_ms(RULES, false), 500.0)
	assert_almost_eq(EnemyRules.min_windup_ms(RULES, true), 650.0)
	# a knob below the floor is lifted to it; above the floor it stays
	assert_almost_eq(EnemyRules.windup_scale(0.8, 560.0, 500.0), 500.0 / 560.0, 0.0001)
	assert_almost_eq(EnemyRules.windup_scale(0.8, 900.0, 500.0), 0.8, 0.0001)
	assert_almost_eq(EnemyRules.windup_scale(2.0, 560.0, 500.0), 2.0, 0.0001)
	assert_ge(560.0 * EnemyRules.windup_scale(0.8, 560.0, 500.0), 500.0 - 0.001)
	assert_ge(710.0 * EnemyRules.windup_scale(0.8, 710.0, 650.0), 650.0 - 0.001, "from behind the floor is 650")


func test_windup_ok_reads_a_move() -> void:
	assert_true(EnemyRules.windup_ok({"telegraph_ms": 0, "impact_ms": 560}, RULES, false))
	assert_false(EnemyRules.windup_ok({"telegraph_ms": 0, "impact_ms": 480}, RULES, false))
	assert_false(EnemyRules.windup_ok({"telegraph_ms": 0, "impact_ms": 560}, RULES, true), "560 is too short from behind")
	assert_true(EnemyRules.windup_ok({"telegraph_ms": 100, "impact_ms": 650}, RULES, false), "telegraph to impact, not move start")


func test_the_aim_locks_150_ms_before_impact_at_the_latest() -> void:
	assert_almost_eq(EnemyRules.aim_lock_ms(380.0, 560.0, RULES), 380.0)
	assert_almost_eq(EnemyRules.aim_lock_ms(500.0, 560.0, RULES), 410.0, 0.001, "a late lock is pulled back")
	assert_almost_eq(EnemyRules.aim_lock_ms(900.0, 600.0, RULES), 450.0, 0.001)
	assert_almost_eq(EnemyRules.aim_lock_ms(10.0, 100.0, RULES), 0.0, 0.001)


func test_red_s_moves_are_read_as_light_heavy_launcher_air() -> void:
	var moves: MoveSet = MoveSet.load_default()
	var table: Dictionary = CombatData.enemies().get("player_read", {}).get("move_class", {})
	for pair: Array in [["light_1", &"light"], ["light_3", &"light"], ["heavy", &"heavy"], ["launcher", &"launcher"], ["air_1", &"air"], ["air_3", &"air"], ["parry", &""]]:
		var id: StringName = StringName(pair[0])
		assert_eq(EnemyRules.move_class(id, moves.get_move(&"red", id), table), pair[1], str(id))
	# without the table the class is worked out from the move itself
	for pair: Array in [["light_2", &"light"], ["heavy", &"heavy"], ["launcher", &"launcher"], ["air_2", &"air"], ["parry", &""]]:
		var id2: StringName = StringName(pair[0])
		assert_eq(EnemyRules.move_class(id2, moves.get_move(&"red", id2), {}), pair[1], "derived: " + str(id2))
