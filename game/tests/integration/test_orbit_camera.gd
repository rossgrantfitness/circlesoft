extends TestCase
## OrbitCamera + LockOn (docs/pivot/combat_api.md 4.8): the mode toggle, mouse and stick turning,
## recentering, lock-on framing and flick switching, the wall-shortened arm, and real-time shake that
## never moves the pivot.

const DT: float = 1.0 / 60.0


class FakeEnemy extends Node3D:
	var hp: int = 10


var _cam: OrbitCamera = null
var _lock: LockOn = null
var _red: Node3D = null


func _make() -> void:
	_red = add_to_root(Node3D.new()) as Node3D
	_red.rotation.y = PI      # faces -Z, so the camera starts at yaw 0 looking along -Z
	_cam = OrbitCamera.new()
	_cam.read_engine_input = false
	add_to_root(_cam)
	_lock = LockOn.new()
	_lock.read_engine_input = false
	add_to_root(_lock)
	_cam.set_lock_on(_lock)
	_cam.follow(_red)
	_cam.snap()


func _enemy(pos: Vector3) -> FakeEnemy:
	var enemy: FakeEnemy = FakeEnemy.new()
	add_to_root(enemy)
	enemy.global_position = pos
	return enemy


func _run(frames: int) -> void:
	for i: int in frames:
		_cam.tick(DT)
		_lock.tick(DT)


func _look_dir() -> Vector3:
	return -_cam.get_camera().global_basis.z


func test_reads_camera_json() -> void:
	_make()
	var db: Node = tree.root.get_node("DataDB")
	var distance: float = float(db.call("get_value", "combat/camera", "orbit.distance_m"))
	var cam_pos: Vector3 = _cam.get_camera().global_position
	assert_almost_eq(cam_pos.distance_to(_cam.get_focus()), distance, 0.05, "arm length is the data distance")
	assert_gt(_cam.get_camera().global_position.y, _cam.get_focus().y - 0.001, "the start pitch looks slightly down on her")


func test_toggle_switches_modes_and_announces_it() -> void:
	_make()
	var seen: Array[int] = []
	_cam.mode_changed.connect(func(mode: int) -> void: seen.append(mode))
	assert_eq(_cam.get_mode(), OrbitCamera.Mode.ORBIT)
	assert_eq(_cam.toggle_mode(), OrbitCamera.Mode.DIORAMA)
	assert_eq(_cam.get_mode(), OrbitCamera.Mode.DIORAMA)
	assert_eq(_cam.toggle_mode(), OrbitCamera.Mode.ORBIT)
	assert_eq(seen, [OrbitCamera.Mode.DIORAMA, OrbitCamera.Mode.ORBIT])


func test_diorama_is_high_and_never_rotates() -> void:
	_make()
	_cam.toggle_mode()
	_run(400)
	var start_basis: Basis = _cam.get_camera().global_basis
	var db: Node = tree.root.get_node("DataDB")
	var pitch: float = deg_to_rad(float(db.call("get_value", "combat/camera", "diorama.pitch_deg")))
	assert_lt(_look_dir().y, -0.4, "looking well down on the arena")
	assert_almost_eq(asin(-_look_dir().y), -pitch, 0.02, "the data pitch")
	# Run Red around a square and spin the look input: the view must not rotate.
	_cam.set_look_stick(Vector2(1, 0.5))
	for waypoint: Vector3 in [Vector3(8, 0, 0), Vector3(8, 0, 8), Vector3(-6, 0, 8), Vector3(0, 0, 0)]:
		for i: int in 80:
			_red.global_position = _red.global_position.move_toward(waypoint, 6.0 * DT)
			_cam.tick(DT)
	var end_basis: Basis = _cam.get_camera().global_basis
	assert_true(start_basis.x.is_equal_approx(end_basis.x) and start_basis.y.is_equal_approx(end_basis.y)
			and start_basis.z.is_equal_approx(end_basis.z), "diorama camera keeps its rotation while following")
	assert_lt(_cam.get_focus().distance_to(_red.global_position + Vector3.UP * 0.5), 3.0, "and still follows her")


func test_diorama_blend_is_smooth_not_a_cut() -> void:
	_make()
	var before: Vector3 = _cam.get_camera().global_position
	_cam.toggle_mode()
	_cam.tick(DT)
	var after_one: Vector3 = _cam.get_camera().global_position
	assert_lt(before.distance_to(after_one), 1.5, "one frame after the toggle the camera has only started to move")
	_run(120)
	assert_gt(_cam.get_camera().global_position.distance_to(before), 4.0, "two seconds later it is up in the high spot")


func test_mouse_and_stick_turn_the_orbit() -> void:
	_make()
	var yaw0: float = _cam.get_view_yaw()
	_cam.add_mouse_motion(Vector2(100, 0))
	_run(30)
	assert_lt(_cam.get_view_yaw(), yaw0 - 0.1, "mouse right turns the view right (yaw falls)")
	var yaw1: float = _cam.get_view_yaw()
	_cam.set_look_stick(Vector2(-1, 0))
	_run(30)
	assert_gt(_cam.get_view_yaw(), yaw1 + 0.5, "stick left turns left")
	_cam.set_look_stick(Vector2.ZERO)
	var pitch0: float = _cam.get_pitch()
	_cam.add_mouse_motion(Vector2(0, 80))
	_run(2)
	assert_lt(_cam.get_pitch(), pitch0, "mouse down looks down")


func test_pitch_stays_inside_the_data_limits() -> void:
	_make()
	var db: Node = tree.root.get_node("DataDB")
	var low: float = deg_to_rad(float(db.call("get_value", "combat/camera", "orbit.pitch_min_deg")))
	var high: float = deg_to_rad(float(db.call("get_value", "combat/camera", "orbit.pitch_max_deg")))
	_cam.add_mouse_motion(Vector2(0, 100000))
	_run(1)
	assert_almost_eq(_cam.get_pitch(), low, 0.0001)
	_cam.add_mouse_motion(Vector2(0, -400000))
	_run(1)
	assert_almost_eq(_cam.get_pitch(), high, 0.0001)


func test_sensitivity_knob_scales_the_turn() -> void:
	_make()
	var knobs: FakeKnobs = FakeKnobs.new()
	knobs.values = {"cam_sensitivity": 2.0, "cam_distance_m": 6.0}
	_cam.knobs = knobs
	var start: float = _cam.get_yaw()
	_cam.add_mouse_motion(Vector2(100, 0))
	_cam.tick(DT)
	var fast: float = start - _cam.get_yaw()
	knobs.values["cam_sensitivity"] = 1.0
	start = _cam.get_yaw()
	_cam.add_mouse_motion(Vector2(100, 0))
	_cam.tick(DT)
	var slow: float = start - _cam.get_yaw()
	assert_almost_eq(fast, slow * 2.0, 0.0001)
	_run(120)
	assert_almost_eq(_cam.get_camera().global_position.distance_to(_cam.get_focus()), 6.0, 0.1, "the distance knob moves the camera out")


class FakeKnobs extends RefCounted:
	var values: Dictionary = {}

	func get_f(id: String) -> float:
		return float(values.get(id, 1.0))


func test_it_eases_back_behind_red_while_she_runs_and_the_look_input_is_idle() -> void:
	_make()
	# Red runs along +X; the camera starts looking along -Z, so it should swing round to look along +X.
	var start_dot: float = _look_dir().dot(Vector3.RIGHT)
	for i: int in 600:
		_red.global_position += Vector3(6.0 * DT, 0, 0)
		_cam.tick(DT)
	assert_gt(_look_dir().dot(Vector3.RIGHT), start_dot + 0.5, "the camera has come round behind her")


func test_it_does_not_recenter_while_the_player_is_still_looking_around() -> void:
	_make()
	var yaw0: float = _cam.get_yaw()
	_cam.set_look_stick(Vector2(0.0, 0.3))
	for i: int in 300:
		_red.global_position += Vector3(6.0 * DT, 0, 0)
		_cam.tick(DT)
	assert_almost_eq(_cam.get_yaw(), yaw0, 0.0001, "look input held: no automatic turning")


func test_recenter_swings_behind_the_way_she_faces() -> void:
	_make()
	_red.rotation.y = PI * 0.5      # faces +X
	_cam.recenter()
	_run(60)
	assert_gt(_look_dir().dot(Vector3.RIGHT), 0.95)


func test_lock_on_picks_the_best_target_and_frames_both() -> void:
	_make()
	var near: FakeEnemy = _enemy(Vector3(0.5, 0, -4))
	var far: FakeEnemy = _enemy(Vector3(9, 0, 3))
	_lock.candidate_provider = func() -> Array: return [near, far]
	var seen: Array = []
	_lock.target_changed.connect(func(t: Node3D) -> void: seen.append(t))
	assert_eq(_lock.toggle(), near, "the one in front wins")
	assert_eq(seen, [near])
	# Move the enemy somewhere new and let the camera settle: Red, the target and the view line up.
	near.global_position = Vector3(6, 0, 0)
	_run(120)
	var to_target: Vector3 = (near.global_position - _red.global_position)
	to_target.y = 0.0
	var flat_look: Vector3 = Vector3(_look_dir().x, 0, _look_dir().z).normalized()
	assert_gt(flat_look.dot(to_target.normalized()), 0.97, "the camera looks along Red toward the target")
	var cam_to_red: float = _cam.get_camera().global_position.distance_to(_red.global_position)
	assert_gt(cam_to_red, 4.0, "and sits farther back to keep both in frame")


func test_lock_on_toggle_releases_and_with_nobody_asks_for_a_recenter() -> void:
	_make()
	var recenters: Array[int] = []
	_lock.recenter_requested.connect(func() -> void: recenters.append(1))
	_lock.candidate_provider = func() -> Array: return []
	assert_null(_lock.toggle())
	assert_eq(recenters.size(), 1, "no target in range: recenter")
	var enemy: FakeEnemy = _enemy(Vector3(0, 0, -3))
	_lock.candidate_provider = func() -> Array: return [enemy]
	assert_eq(_lock.toggle(), enemy)
	assert_null(_lock.toggle(), "a second press lets go")
	assert_false(_lock.has_target())


func test_flick_switches_targets_only_while_locked() -> void:
	_make()
	var left: FakeEnemy = _enemy(Vector3(-4, 0, -5))
	var middle: FakeEnemy = _enemy(Vector3(0.2, 0, -5))
	var right: FakeEnemy = _enemy(Vector3(4, 0, -5))
	_lock.candidate_provider = func() -> Array: return [left, middle, right]
	assert_null(_lock.switch(Vector2(1, 0)), "nothing locked: nothing happens")
	_lock.toggle()
	assert_eq(_lock.get_target(), middle)
	# The camera stick flicks right, through OrbitCamera, while locked.
	_cam.set_look_stick(Vector2(1, 0))
	_run(1)
	assert_eq(_lock.get_target(), right)
	_cam.set_look_stick(Vector2.ZERO)
	_run(30)
	_cam.set_look_stick(Vector2(-1, 0))
	_run(1)
	assert_eq(_lock.get_target(), middle, "flick left steps back")


func test_a_held_stick_switches_once_not_every_frame() -> void:
	_make()
	var a: FakeEnemy = _enemy(Vector3(-2, 0, -5))
	var b: FakeEnemy = _enemy(Vector3(0.1, 0, -5))
	var c: FakeEnemy = _enemy(Vector3(2, 0, -5))
	_lock.candidate_provider = func() -> Array: return [a, b, c]
	_lock.toggle()
	_cam.set_look_stick(Vector2(1, 0))
	_run(60)
	assert_eq(_lock.get_target(), c, "one flick moved one step; holding it didn't run on to nowhere")


func test_lock_drops_a_dead_or_far_target() -> void:
	_make()
	var enemy: FakeEnemy = _enemy(Vector3(0, 0, -4))
	_lock.candidate_provider = func() -> Array: return [enemy]
	_lock.toggle()
	enemy.hp = 0
	_lock.tick(DT)
	assert_false(_lock.has_target(), "dead target released")
	enemy.hp = 5
	_lock.toggle()
	enemy.global_position = Vector3(0, 0, -60)
	_lock.tick(DT)
	assert_false(_lock.has_target(), "out of break range released")
	assert_null(_lock.get_target())


func test_magnet_prefers_the_hard_lock_else_the_cone() -> void:
	_make()
	var in_front: FakeEnemy = _enemy(Vector3(0, 0, -2.5))
	var behind: FakeEnemy = _enemy(Vector3(0, 0, 4))
	_lock.candidate_provider = func() -> Array: return [in_front, behind]
	var facing: Vector3 = Vector3(0, 0, -1)
	assert_eq(_lock.magnet_target(Vector3.ZERO, facing, 3.5, 70.0), in_front, "soft: the one she faces")
	assert_null(_lock.soft_target(Vector3(0, 0, 1), facing, 3.5, 70.0), "the one behind is out of reach")
	assert_eq(_lock.soft_target(Vector3(0, 0, 1), facing, 5.0, 70.0), behind, "pushing back finds the one behind")
	_lock.set_target(behind)
	assert_eq(_lock.magnet_target(Vector3.ZERO, facing, 3.5, 70.0), behind, "the hard lock wins")


func test_a_wall_pulls_the_camera_in() -> void:
	_make()
	var open_distance: float = _cam.get_camera().global_position.distance_to(_cam.get_focus())
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 10, 0.5)
	shape.shape = box
	wall.add_child(shape)
	add_to_root(wall)
	wall.collision_layer = 1
	# Behind Red. The camera starts looking along -Z (Red faces +Z default => yaw 0 here), so it sits on +Z.
	wall.global_position = Vector3(0, 1, 2.0)
	await tree.physics_frame
	await tree.physics_frame
	_run(5)
	var pulled: float = _cam.get_camera().global_position.distance_to(_cam.get_focus())
	assert_lt(pulled, open_distance - 1.0, "the arm shortened to stay in front of the wall")
	assert_lt(_cam.get_camera().global_position.z, 2.0, "and the camera is on Red's side of it")


func test_shake_decays_to_zero_in_real_time_and_never_moves_the_pivot() -> void:
	_make()
	_run(5)
	var pivot_before: Vector3 = _cam.global_position
	var rest_cam: Vector3 = _cam.get_camera().global_position
	_cam.shake(&"heavy")
	assert_true(_cam.is_shaking())
	var peak: float = 0.0
	for i: int in 6:
		_cam.tick(DT)
		peak = maxf(peak, _cam.get_shake_offset().length())
		assert_true(_cam.global_position.is_equal_approx(pivot_before), "the pivot never moves")
	assert_gt(peak, 0.005, "the camera visibly shakes")
	# heavy lasts 0.2 s of real time: after 0.5 s of ticks it is still and back at rest.
	for i: int in 30:
		_cam.tick(DT)
	assert_false(_cam.is_shaking())
	assert_eq(_cam.get_shake_offset(), Vector3.ZERO)
	assert_true(_cam.get_camera().global_position.is_equal_approx(rest_cam))


func test_a_stronger_shake_is_not_cut_short_by_a_weaker_one() -> void:
	_make()
	_cam.shake(&"slam")
	_cam.tick(DT)
	var before: float = _cam.get_shake_offset().length()
	_cam.shake(&"light")
	assert_true(_cam.is_shaking())
	assert_ge(before, 0.0)
	var left_ms: int = 0
	while _cam.is_shaking() and left_ms < 1000:
		_cam.tick(DT)
		left_ms += 17
	assert_gt(left_ms, 250, "the slam still plays out its own length")
