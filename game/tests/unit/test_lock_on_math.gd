extends TestCase
## LockOnMath (pure): who a lock picks, flick switching, attack magnetism, and the camera yaw maths.

const PLAYER: Vector3 = Vector3.ZERO
## A camera looking down -Z (yaw 0): forward is -Z, right is +X.
const CAM_FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)
const CAM_RIGHT: Vector3 = Vector3(1.0, 0.0, 0.0)


func _at(x: float, z: float) -> Dictionary:
	return {"pos": Vector3(x, 1.0, z)}


func _list(items: Array[Dictionary]) -> Array[Dictionary]:
	return items


func test_score_prefers_the_middle_of_the_screen_and_the_near() -> void:
	var ahead: float = LockOnMath.score(_at(0, -5), CAM_FORWARD, PLAYER)
	var side: float = LockOnMath.score(_at(5, 0), CAM_FORWARD, PLAYER)
	var near: float = LockOnMath.score(_at(0, -2), CAM_FORWARD, PLAYER)
	assert_gt(ahead, side, "straight ahead beats off to the side at the same distance")
	assert_gt(near, ahead, "closer beats farther at the same angle")


func test_out_of_range_or_behind_is_not_eligible() -> void:
	assert_eq(LockOnMath.score(_at(0, -40), CAM_FORWARD, PLAYER), LockOnMath.NOT_ELIGIBLE)
	assert_eq(LockOnMath.score(_at(0, 5), CAM_FORWARD, PLAYER), LockOnMath.NOT_ELIGIBLE, "directly behind the camera")
	assert_gt(LockOnMath.score(_at(0, -15), CAM_FORWARD, PLAYER), LockOnMath.NOT_ELIGIBLE, "inside the default range")


func test_best_picks_the_highest_score_and_minus_one_for_nobody() -> void:
	var list: Array[Dictionary] = _list([_at(6, -2), _at(0.5, -6), _at(-9, 0)])
	assert_eq(LockOnMath.best(list, CAM_FORWARD, PLAYER), 1)
	assert_eq(LockOnMath.best(_list([_at(0, -80)]), CAM_FORWARD, PLAYER), -1)
	assert_eq(LockOnMath.best(_list([]), CAM_FORWARD, PLAYER), -1)


func test_params_change_the_range() -> void:
	var list: Array[Dictionary] = _list([_at(0, -10)])
	assert_eq(LockOnMath.best(list, CAM_FORWARD, PLAYER, {"max_range_m": 6.0}), -1)
	assert_eq(LockOnMath.best(list, CAM_FORWARD, PLAYER, {"max_range_m": 12.0}), 0)


func test_switch_steps_left_and_right_across_the_screen() -> void:
	var list: Array[Dictionary] = _list([_at(-6, -5), _at(0, -5), _at(5, -5), _at(9, -5)])
	assert_eq(LockOnMath.switch_index(list, 1, Vector2(1, 0), CAM_RIGHT, PLAYER), 2, "flick right: the next one to the right")
	assert_eq(LockOnMath.switch_index(list, 2, Vector2(1, 0), CAM_RIGHT, PLAYER), 3)
	assert_eq(LockOnMath.switch_index(list, 1, Vector2(-1, 0), CAM_RIGHT, PLAYER), 0, "flick left")
	assert_eq(LockOnMath.switch_index(list, 3, Vector2(1, 0), CAM_RIGHT, PLAYER), 3, "nothing further right: stay")
	assert_eq(LockOnMath.switch_index(list, 0, Vector2(-1, 0), CAM_RIGHT, PLAYER), 0, "nothing further left: stay")


func test_switch_uses_the_camera_side_not_the_world_side() -> void:
	# Camera turned to look down +X: its right is +Z (flat_right of that view).
	var list: Array[Dictionary] = _list([_at(5, -3), _at(5, 3)])
	var cam_right: Vector3 = Vector3(0.0, 0.0, 1.0)
	assert_eq(LockOnMath.switch_index(list, 0, Vector2(1, 0), cam_right, PLAYER), 1)
	assert_eq(LockOnMath.switch_index(list, 1, Vector2(-1, 0), cam_right, PLAYER), 0)


func test_switch_edge_cases() -> void:
	assert_eq(LockOnMath.switch_index(_list([]), 0, Vector2(1, 0)), -1)
	assert_eq(LockOnMath.switch_index(_list([_at(0, -3)]), 0, Vector2(1, 0), CAM_RIGHT, PLAYER), 0, "a lone target stays")
	assert_eq(LockOnMath.switch_index(_list([_at(0, -3), _at(2, -3)]), 0, Vector2.ZERO, CAM_RIGHT, PLAYER), 0, "no flick, no change")
	var two: Array[Dictionary] = _list([_at(0, -3), _at(2, -3)])
	assert_eq(LockOnMath.switch_index(two, 0, Vector2(0.1, 1.0), CAM_RIGHT, PLAYER), 1, "a mostly-down flick steps right")


func test_magnet_picks_inside_the_cone_and_range_only() -> void:
	var ahead: Dictionary = _at(0, -2.5)
	var side: Dictionary = _at(2.5, 0.0)
	var far: Dictionary = _at(0, -9)
	var list: Array[Dictionary] = _list([side, far, ahead])
	assert_eq(LockOnMath.magnet_pick(list, PLAYER, Vector3(0, 0, -1), 3.5, 70.0), 2)
	assert_eq(LockOnMath.magnet_pick(list, PLAYER, Vector3(0, 0, 1), 3.5, 70.0), -1, "nobody behind her")
	assert_eq(LockOnMath.magnet_pick(list, PLAYER, Vector3(1, 0, 0), 3.5, 70.0), 0, "pushing right finds the one on the right")
	assert_eq(LockOnMath.magnet_pick(_list([far]), PLAYER, Vector3(0, 0, -1), 3.5, 70.0), -1, "out of range")


func test_magnet_prefers_the_smaller_angle_then_the_closer() -> void:
	var off_axis: Dictionary = _at(1.5, -2.0)
	var on_axis: Dictionary = _at(0, -3.4)
	assert_eq(LockOnMath.magnet_pick(_list([off_axis, on_axis]), PLAYER, Vector3(0, 0, -1), 3.5, 70.0), 1)
	var near: Dictionary = _at(0, -1.0)
	var far: Dictionary = _at(0, -3.0)
	assert_eq(LockOnMath.magnet_pick(_list([far, near]), PLAYER, Vector3(0, 0, -1), 3.5, 70.0), 1, "same angle: closer wins")


func test_yaw_to_turns_a_plus_z_model_toward_the_target() -> void:
	assert_almost_eq(LockOnMath.yaw_to(PLAYER, Vector3(0, 0, 5)), 0.0, 0.0001)
	assert_almost_eq(LockOnMath.yaw_to(PLAYER, Vector3(5, 0, 0)), PI * 0.5, 0.0001)
	assert_almost_eq(absf(LockOnMath.yaw_to(PLAYER, Vector3(0, 0, -5))), PI, 0.0001)
	assert_eq(LockOnMath.yaw_to(PLAYER, PLAYER), 0.0)


func test_camera_yaw_for_puts_the_camera_behind_the_player() -> void:
	for target: Vector3 in [Vector3(0, 0, -5), Vector3(5, 0, 0), Vector3(-3, 0, 4), Vector3(2, 0, 2)]:
		var yaw: float = LockOnMath.camera_yaw_for(PLAYER, target)
		var look: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
		assert_true(look.is_equal_approx(Vector3(target.x, 0.0, target.z).normalized()), "yaw %s looks at %s" % [yaw, target])


func test_recenter_turns_toward_travel_across_the_view_only() -> void:
	# Camera looks along -Z (yaw 0). She runs toward +X (90 degrees across): the view turns to look along +X.
	var step: float = LockOnMath.recenter_step(0.0, Vector3(5, 0, 0), 90.0, 1.0 / 60.0)
	assert_lt(step, 0.0, "turns toward looking along +X (yaw goes negative)")
	assert_le(absf(step), deg_to_rad(90.0) / 60.0 + 0.0001, "no faster than the rate")
	assert_eq(LockOnMath.recenter_step(0.0, Vector3(0, 0, 5), 90.0, 1.0 / 60.0), 0.0, "running straight at the camera: no spin")
	assert_eq(LockOnMath.recenter_step(0.0, Vector3.ZERO, 90.0, 1.0 / 60.0), 0.0)
	assert_eq(LockOnMath.recenter_step(0.0, Vector3(0, 0, -5), 90.0, 1.0 / 60.0), 0.0, "already behind her: nothing to do")


func test_a_held_diagonal_never_makes_the_camera_chase_her_in_circles() -> void:
	# Running 25 degrees off the camera's forward is inside the dead zone: the camera stays put.
	var travel: Vector3 = Vector3(-sin(deg_to_rad(-25.0)), 0, -cos(deg_to_rad(-25.0)))
	assert_eq(LockOnMath.recenter_step(0.0, travel, 90.0, 1.0 / 60.0), 0.0)
	# Across the view it turns, but stops at the edge of the dead zone (35 degrees), never beyond.
	var yaw: float = 0.0
	var across: Vector3 = Vector3(5, 0, 0)
	for i: int in 2000:
		yaw += LockOnMath.recenter_step(yaw, across, 90.0, 1.0 / 60.0)
	assert_almost_eq(absf(rad_to_deg(wrapf(-PI * 0.5 - yaw, -PI, PI))), 35.0, 0.5, "the camera settles 35 degrees short of dead behind her")


func test_a_thousand_random_boards_never_pick_an_ineligible_target() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for round_index: int in 1000:
		var list: Array[Dictionary] = []
		for i: int in rng.randi_range(0, 6):
			list.append(_at(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
		var fwd: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(0, TAU))
		var pick: int = LockOnMath.best(list, fwd, PLAYER)
		if pick >= 0:
			assert_gt(LockOnMath.score(list[pick], fwd, PLAYER), LockOnMath.NOT_ELIGIBLE)
		else:
			for entry: Dictionary in list:
				if LockOnMath.score(entry, fwd, PLAYER) > LockOnMath.NOT_ELIGIBLE:
					fail("best() said nobody but someone was eligible")
	assert_true(true)
