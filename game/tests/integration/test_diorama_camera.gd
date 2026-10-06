extends TestCase
## Milestone 1 step 7: the diorama camera never rotates, keeps its target in the safe frame,
## clamps to the room bounds, and switches between perspective and orthographic.

const ASPECT: float = 384.0 / 216.0
const DT: float = 1.0 / 60.0
const ROTATION_TOLERANCE: float = 0.000001

var _rig: DioramaCamera = null
var _target: Node3D = null


func _make_rig() -> void:
	_target = add_to_root(Node3D.new()) as Node3D
	_rig = DioramaCamera.new()
	_rig.aspect_override = ASPECT
	_rig.auto_update = false
	_rig.target = _target
	add_to_root(_rig)
	_rig.snap_to_target()


func _basis_matches(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)


func test_reads_tuning_from_data() -> void:
	_make_rig()
	var db: Node = tree.root.get_node("DataDB")
	var tuning: FieldTuning = FieldTuning.from_db(db)
	assert_almost_eq(tuning.camera_smoothing, float(db.get_value("world/field_tuning", "camera.smoothing")))
	assert_gt(tuning.camera_smoothing, 0.0)
	assert_gt(tuning.camera_safe_frame_margin, 0.0)
	# The rig loaded the same values: one small step moves it by the smoothing fraction.
	_target.global_position = Vector3(1.0, 0.0, 0.0)
	_rig.update_camera(DT)
	var expected: float = 1.0 - exp(-tuning.camera_smoothing * DT)
	assert_almost_eq(_rig.get_focus().x, expected, 0.0001)


func test_focus_point_is_screen_center_and_smoothing_lags() -> void:
	_make_rig()
	var center: Vector2 = _rig.world_to_screen(_rig.get_focus())
	assert_almost_eq(center.x, 0.5, 0.0001)
	assert_almost_eq(center.y, 0.5, 0.0001)
	_target.global_position = Vector3(1.5, 0.0, 0.0)
	_rig.update_camera(DT)
	assert_gt(_rig.get_focus().x, 0.0, "camera moves toward the target")
	assert_lt(_rig.get_focus().x, 1.5, "camera lags behind (smoothing)")


func test_never_rotates_while_following() -> void:
	_make_rig()
	var start_rig: Basis = _rig.global_basis
	var start_cam: Basis = _rig.get_camera().global_basis
	var path: Array[Vector3] = [Vector3(8, 0, 0), Vector3(8, 0, 9), Vector3(-12, 0, 9), Vector3(-12, 0, -15), Vector3(0, 0, 0)]
	for waypoint: Vector3 in path:
		for frame: int in 90:
			_target.global_position = _target.global_position.move_toward(waypoint, 4.8 * DT)
			_rig.update_camera(DT)
			assert_true(_basis_matches(_rig.global_basis, start_rig), "rig rotated at %s" % _target.global_position)
			assert_true(_basis_matches(_rig.get_camera().global_basis, start_cam), "camera rotated")
	assert_true(_basis_matches(_rig.get_fixed_basis(), start_rig))
	# Following also survives a rotated parent: the rig positions itself in world space.
	var spinner: Node3D = add_to_root(Node3D.new()) as Node3D
	spinner.rotation.y = 1.0
	_rig.reparent(spinner, false)
	_target.global_position = Vector3(20, 0, 20)
	_rig.update_camera(DT)
	assert_true(_basis_matches(_rig.global_basis, start_rig), "rotated parent must not turn the camera")


func test_keeps_target_in_safe_frame_at_the_edges() -> void:
	_make_rig()
	# A teleport far away, then runs to far corners.
	var corners: Array[Vector3] = [Vector3(40, 0, 30), Vector3(-40, 0, 30), Vector3(-40, 0, -30), Vector3(40, 0, -30)]
	_target.global_position = corners[0]
	_rig.update_camera(DT)
	assert_true(_rig.is_target_in_safe_frame(), "after a teleport the target is still in the safe frame")
	for corner: Vector3 in corners:
		for frame: int in 600:
			_target.global_position = _target.global_position.move_toward(corner, 4.8 * 4.0 * DT)
			_rig.update_camera(DT)
			if not _rig.is_target_in_safe_frame():
				fail("target left the safe frame at %s (screen %s)" % [_target.global_position, _rig.world_to_screen(_target.global_position + Vector3.UP * 0.5)])
				return
	assert_true(true)


func test_target_stays_in_frame_in_orthographic_too() -> void:
	_make_rig()
	_rig.set_projection_mode(DioramaCamera.ProjectionMode.ORTHOGRAPHIC)
	for corner: Vector3 in [Vector3(30, 0, 22), Vector3(-30, 0, -22)]:
		for frame: int in 400:
			_target.global_position = _target.global_position.move_toward(corner, 20.0 * DT)
			_rig.update_camera(DT)
			if not _rig.is_target_in_safe_frame():
				fail("ortho: target left the safe frame at %s" % _target.global_position)
				return
	assert_true(true)


func test_small_moves_inside_the_frame_do_not_force_the_camera() -> void:
	_make_rig()
	var margin: float = FieldTuning.from_db(tree.root.get_node("DataDB")).camera_safe_frame_margin
	_target.global_position = Vector3(0.5, 0.0, 0.0)
	_rig.update_camera(DT)
	var screen: Vector2 = _rig.world_to_screen(_target.global_position + Vector3.UP * 0.5)
	assert_gt(screen.x, margin)
	assert_lt(screen.x, 1.0 - margin)
	# Settles onto the target given time.
	for frame: int in 300:
		_rig.update_camera(DT)
	assert_almost_eq(_rig.get_focus().x, 0.5, 0.01)


func test_clamps_to_bounds() -> void:
	_make_rig()
	_rig.set_bounds_rect(Rect2(-3.0, -2.0, 6.0, 4.0))
	_target.global_position = Vector3(50, 0, 50)
	for frame: int in 300:
		_rig.update_camera(DT)
		var focus: Vector3 = _rig.get_focus()
		if focus.x > 3.0001 or focus.x < -3.0001 or focus.z > 2.0001 or focus.z < -2.0001:
			fail("focus left the bounds: %s" % focus)
			return
	assert_almost_eq(_rig.get_focus().x, 3.0, 0.001)
	assert_almost_eq(_rig.get_focus().z, 2.0, 0.001)
	_target.global_position = Vector3(-50, 0, -50)
	for frame: int in 300:
		_rig.update_camera(DT)
	assert_almost_eq(_rig.get_focus().x, -3.0, 0.001)
	assert_almost_eq(_rig.get_focus().z, -2.0, 0.001)
	_rig.clear_bounds()
	assert_false(_rig.has_bounds())


func test_clamps_to_aabb_bounds_and_tiny_room_pins_camera() -> void:
	_make_rig()
	_rig.set_bounds(AABB(Vector3(-1, 0, -1), Vector3(2, 3, 2)))
	_target.global_position = Vector3(9, 0, -9)
	_rig.snap_to_target()
	assert_almost_eq(_rig.get_focus().x, 1.0, 0.0001)
	assert_almost_eq(_rig.get_focus().z, -1.0, 0.0001)
	# A bounds box with no size pins the camera: a room that fits one screen.
	_rig.set_bounds(AABB(Vector3(2, 0, 3), Vector3.ZERO))
	_target.global_position = Vector3(-4, 0, 7)
	for frame: int in 60:
		_rig.update_camera(DT)
	assert_almost_eq(_rig.get_focus().x, 2.0, 0.0001)
	assert_almost_eq(_rig.get_focus().z, 3.0, 0.0001)


func test_switches_projection_at_runtime_without_changing_the_shot() -> void:
	_make_rig()
	var cam: Camera3D = _rig.get_camera()
	assert_eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "default is perspective")
	assert_almost_eq(cam.fov, 30.0, 0.0001, "default FOV is narrow")
	var rotation_before: Basis = _rig.global_basis
	var focus_screen_before: Vector2 = _rig.world_to_screen(Vector3(1, 0, 1))
	_rig.toggle_projection_mode()
	assert_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_almost_eq(cam.size, DioramaMath.matching_ortho_size(30.0, _rig.distance), 0.0001)
	assert_true(_basis_matches(_rig.global_basis, rotation_before), "mode switch must not rotate")
	assert_true(_rig.world_to_screen(_rig.get_focus()).is_equal_approx(Vector2(0.5, 0.5)), "look-at point stays centered")
	_rig.toggle_projection_mode()
	assert_eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(_rig.world_to_screen(Vector3(1, 0, 1)).is_equal_approx(focus_screen_before))
	_rig.set_fov_deg(45.0)
	assert_almost_eq(cam.fov, 45.0, 0.0001)
	assert_true(_basis_matches(_rig.global_basis, rotation_before), "FOV change must not rotate")


func test_own_projection_matches_godots_camera() -> void:
	_make_rig()
	var viewport_size: Vector2 = tree.root.get_visible_rect().size
	_rig.aspect_override = viewport_size.x / viewport_size.y
	_rig.set_room_look(40.0, 25.0, 30.0, 10.5)
	_target.global_position = Vector3(2, 0, -1)
	_rig.snap_to_target()
	var cam: Camera3D = _rig.get_camera()
	var probe: Vector3 = Vector3(3.0, 0.0, 1.0)
	var engine_screen: Vector2 = cam.unproject_position(probe) / viewport_size
	var ours: Vector2 = _rig.world_to_screen(probe)
	assert_true(engine_screen.distance_to(ours) < 0.002, "ours %s vs engine %s" % [ours, engine_screen])
	_rig.toggle_projection_mode()
	engine_screen = cam.unproject_position(probe) / viewport_size
	ours = _rig.world_to_screen(probe)
	assert_true(engine_screen.distance_to(ours) < 0.002, "ortho: ours %s vs engine %s" % [ours, engine_screen])
