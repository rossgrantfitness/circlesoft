extends TestCase
## Milestone 1 wiring: the test room spawns Red at PlayerSpawn, the diorama camera follows her inside
## the CameraBounds, the fader hides the pillar when it blocks her, and she can walk the whole room.

const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const RED_MODEL: String = "res://art/placeholder/characters/red/red_blockout.glb"
const ARRIVE_DISTANCE: float = 0.3
const MAX_TICKS_PER_LEG: int = 600
const SETTLE_TICKS: int = 45
const PILLAR_SHADOW_SPOT: Vector3 = Vector3(1.3, 0.0, -0.3)
const TOP_RIGHT_WING: Vector3 = Vector3(12.5, 0.0, -3.5)

var _room: FieldRoom = null


func after_each() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"jump"]:
		Input.action_release(action)


func _load_room() -> FieldRoom:
	_room = (load(ROOM_PATH) as PackedScene).instantiate() as FieldRoom
	add_to_root(_room)
	_room.camera_rig.auto_update = true
	_room.player.read_engine_input = false
	return _room


func _ticks(count: int) -> void:
	for i: int in count:
		await tree.physics_frame


## Steers Red toward a point on the floor using the same stick input a player would give.
func _walk_to(goal: Vector3) -> void:
	var cam_basis: Basis = _room.camera_rig.get_camera().global_basis
	for tick: int in MAX_TICKS_PER_LEG:
		var offset: Vector3 = goal - _room.player.global_position
		offset.y = 0.0
		if offset.length() < ARRIVE_DISTANCE:
			break
		var direction: Vector3 = offset.normalized()
		_room.player.stick = Vector2(direction.dot(PlayerMotion.flat_right(cam_basis)),
				-direction.dot(PlayerMotion.flat_forward(cam_basis)))
		await tree.physics_frame
	_room.player.stick = Vector2.ZERO


func _fade_value(prop_name: String) -> float:
	var pillar: MeshInstance3D = _room.get_node(prop_name) as MeshInstance3D
	var value: Variant = pillar.get_instance_shader_parameter(PropFader.FADE_PARAM)
	return 1.0 if value == null else float(value)


func test_room_spawns_red_at_the_marker_with_camera_bounds_and_fader() -> void:
	_load_room()
	var spawn: Marker3D = _room.get_node("PlayerSpawn") as Marker3D
	assert_not_null(_room.player)
	assert_true(_room.player.global_position.is_equal_approx(spawn.global_position), "Red starts on PlayerSpawn")
	assert_eq(_room.camera_rig.target, _room.player, "camera follows Red")
	assert_eq(_room.player.camera, _room.camera_rig.get_camera(), "Red moves relative to the room camera")
	assert_true(_room.camera_rig.has_bounds())
	assert_eq(_room.camera_rig.get_bounds(), (_room.get_node("CameraBounds") as CameraBounds).get_world_aabb())
	assert_eq(_room.prop_fader.target, _room.player)
	assert_eq(_room.prop_fader.camera, _room.camera_rig.get_camera())
	assert_true(_room.camera_rig.is_target_in_safe_frame(), "Red is framed on load")
	assert_eq(_room.get_node("CameraRig/Camera3D"), _room.camera_rig.get_camera(), "one camera in the room")


func test_camera_keeps_the_room_look_and_the_ta_framing() -> void:
	_load_room()
	assert_almost_eq(_room.camera_rig.pitch_deg, 42.0, 0.001)
	assert_almost_eq(_room.camera_rig.fov_deg, 30.0, 0.001)
	assert_true(_room.camera_rig.is_perspective())


func test_red_uses_the_placeholder_model_when_it_exists() -> void:
	_load_room()
	if ResourceLoader.exists(RED_MODEL):
		assert_not_null(_room.player.get_node_or_null("Visual/Model"), "the .glb is attached")
		assert_null(_room.player.get_node_or_null("Visual/PlaceholderCapsule"), "capsule removed")
	else:
		assert_not_null(_room.player.get_node_or_null("Visual/PlaceholderCapsule"))


func test_red_plays_idle_then_walk_then_run_from_the_model() -> void:
	_load_room()
	if not ResourceLoader.exists(RED_MODEL):
		assert_true(true)
		return
	assert_eq(_room.player.get_current_animation(), &"idle")
	_room.player.stick = Vector2(0.0, -0.5)
	await _ticks(3)
	assert_eq(_room.player.get_current_animation(), &"walk")
	_room.player.stick = Vector2(0.0, -1.0)
	_room.player.run_held = true
	await _ticks(3)
	assert_eq(_room.player.get_current_animation(), &"run")


func test_pillar_fades_when_it_blocks_red_and_returns_when_she_steps_out() -> void:
	_load_room()
	assert_almost_eq(_fade_value("Pillar"), 1.0, 0.001, "solid at the start")
	_room.player.global_position = PILLAR_SHADOW_SPOT + Vector3(0.0, 0.05, 0.0)
	await _ticks(60)
	assert_lt(_fade_value("Pillar"), 0.5, "pillar is dithered out while it hides Red")
	assert_gt(_fade_value("Pillar"), 0.0, "but a few dots remain")
	_room.player.global_position = Vector3(-3.0, 0.05, 2.0)
	await _ticks(120)
	assert_almost_eq(_fade_value("Pillar"), 1.0, 0.001, "pillar returns when clear")


func test_red_can_walk_the_whole_room_including_the_wing_and_the_camera_slides() -> void:
	_load_room()
	var start_focus: Vector3 = _room.camera_rig.get_focus()
	var start_basis: Basis = _room.camera_rig.global_basis
	var legs: Array[Vector3] = [Vector3(-1.0, 0.0, -1.5), TOP_RIGHT_WING, Vector3(12.5, 0.0, 3.5),
			Vector3(-4.5, 0.0, 3.5), Vector3(-4.5, 0.0, -3.5)]
	for goal: Vector3 in legs:
		await _walk_to(goal)
		var gap: float = Vector2(_room.player.global_position.x - goal.x, _room.player.global_position.z - goal.z).length()
		assert_lt(gap, ARRIVE_DISTANCE + 0.1, "reached %s (at %s)" % [goal, _room.player.global_position])
		await _ticks(SETTLE_TICKS)
		var screen: Vector2 = _room.camera_rig.world_to_screen(_room.player.global_position + Vector3.UP * 0.5)
		assert_true(screen.x > 0.05 and screen.x < 0.95 and screen.y > 0.05 and screen.y < 0.95,
				"Red is on screen at %s (screen %s)" % [goal, screen])
		assert_true(_room.camera_rig.global_basis.is_equal_approx(start_basis), "camera never rotated")
		if goal == TOP_RIGHT_WING:
			assert_gt(_room.camera_rig.get_focus().x - start_focus.x, 5.0, "camera slid along into the wing")
	var bounds: AABB = _room.camera_rig.get_bounds()
	var focus: Vector3 = _room.camera_rig.get_focus()
	assert_true(focus.x >= bounds.position.x - 0.01 and focus.x <= bounds.end.x + 0.01, "focus stays inside the bounds (x)")
	assert_true(focus.z >= bounds.position.z - 0.01 and focus.z <= bounds.end.z + 0.01, "focus stays inside the bounds (z)")


func test_room_edges_hold_red_in() -> void:
	_load_room()
	# Walk straight off the open front edge and the open right edge: invisible barriers stop her.
	_room.player.global_position = Vector3(4.0, 0.05, 3.0)
	await _ticks(2)
	var toward_front: Vector3 = Vector3(0.0, 0.0, 1.0)
	var cam_basis: Basis = _room.camera_rig.get_camera().global_basis
	_room.player.stick = Vector2(toward_front.dot(PlayerMotion.flat_right(cam_basis)),
			-toward_front.dot(PlayerMotion.flat_forward(cam_basis))).normalized()
	await _ticks(120)
	assert_lt(_room.player.global_position.z, 4.0, "front edge holds")
	_room.player.global_position = Vector3(12.0, 0.05, 0.0)
	var toward_right: Vector3 = Vector3(1.0, 0.0, 0.0)
	_room.player.stick = Vector2(toward_right.dot(PlayerMotion.flat_right(cam_basis)),
			-toward_right.dot(PlayerMotion.flat_forward(cam_basis))).normalized()
	await _ticks(120)
	assert_lt(_room.player.global_position.x, 13.0, "right edge holds")
	assert_gt(_room.player.global_position.y, -0.1, "still on the floor")
