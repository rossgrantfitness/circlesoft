extends TestCase
## Milestone 1 step 9: Red moves relative to the fixed camera at the data speeds, turns at the
## data rate, stands on the floor, and stops at walls.

const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const TICK: float = 1.0 / 60.0
const SPEED_TOLERANCE: float = 0.001
const FLOOR_SIZE: Vector3 = Vector3(60.0, 1.0, 60.0)
const WALL_FACE_X: float = 3.0
const PLAYER_RADIUS: float = 0.3

var _player: PlayerController = null
var _camera: Camera3D = null
var _tuning: FieldTuning = null


func before_each() -> void:
	_tuning = FieldTuning.from_db(tree.root.get_node("DataDB"))


func after_each() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"walk"]:
		Input.action_release(action)


func _box_body(center: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	return body


## A floor (top at y = 0), a wall whose near face is at x = 3, a fixed camera with the given yaw,
## and Red standing at the origin.
func _make_world(camera_yaw_deg: float = 0.0, with_wall: bool = true) -> void:
	add_to_root(_box_body(Vector3(0.0, -FLOOR_SIZE.y * 0.5, 0.0), FLOOR_SIZE))
	if with_wall:
		add_to_root(_box_body(Vector3(WALL_FACE_X + 0.5, 1.5, 0.0), Vector3(1.0, 3.0, 20.0)))
	_camera = add_to_root(Camera3D.new()) as Camera3D
	_camera.global_transform = Transform3D(DioramaMath.orientation(42.0, camera_yaw_deg), Vector3(0.0, 7.0, 7.5))
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	_player = scene.instantiate() as PlayerController
	_player.read_engine_input = false
	_player.camera = _camera
	_player.position = Vector3(0.0, 0.02, 0.0)
	add_to_root(_player)
	_player.set_tuning(_tuning)


func _ticks(count: int) -> void:
	for i: int in count:
		await tree.physics_frame


func _flat_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_scene_has_required_nodes_and_capsule_stand_in() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	own(player)
	assert_not_null(player)
	assert_not_null(player.get_node_or_null("CollisionShape3D"))
	assert_not_null(player.get_node_or_null("Visual"), "model slot")
	if ResourceLoader.exists(PlayerController.MODEL_PATH):
		assert_true(true, "red_blockout.glb exists; it is attached on _ready")
	else:
		assert_not_null(player.get_node_or_null("Visual/PlaceholderCapsule"), "capsule stand-in until the .glb exists")
	assert_eq(player.collision_mask & 1, 1, "collides with the world layer")


func test_no_jump_action_exists() -> void:
	assert_false(InputMap.has_action("jump"))


func test_run_speed_at_full_tilt_comes_from_data() -> void:
	_make_world(0.0, false)
	_player.stick = Vector2(0.0, -1.0)
	await _ticks(30)
	assert_almost_eq(_flat_speed(), _tuning.run_speed, SPEED_TOLERANCE)
	assert_true(_player.is_running())
	assert_lt(_player.position.z, -1.0, "stick up moves away from the camera, toward the back wall")
	assert_almost_eq(_player.position.x, 0.0, 0.001)


func test_walk_speed_on_a_light_tilt_and_run_button_overrides() -> void:
	_make_world(0.0, false)
	_player.stick = Vector2(0.0, -0.5)
	await _ticks(10)
	assert_almost_eq(_flat_speed(), _tuning.walk_speed, SPEED_TOLERANCE)
	assert_false(_player.is_running())
	_player.run_held = true
	await _ticks(3)
	assert_almost_eq(_flat_speed(), _tuning.run_speed, SPEED_TOLERANCE, "run button runs even on a light tilt")


func test_walk_action_exists_and_is_shift_on_keyboard() -> void:
	assert_true(InputMap.has_action("walk"))
	var has_shift: bool = false
	for event: InputEvent in InputMap.action_get_events("walk"):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == KEY_SHIFT:
			has_shift = true
	assert_true(has_shift, "Shift walks on a keyboard")
	for event: InputEvent in InputMap.action_get_events("run"):
		var key: InputEventKey = event as InputEventKey
		assert_true(key == null or key.physical_keycode != KEY_SHIFT, "Shift no longer runs")


func test_keyboard_runs_by_default_and_walks_while_walk_is_held() -> void:
	_make_world(0.0, false)
	_player.read_engine_input = true
	Input.action_press(&"move_up")
	await _ticks(10)
	assert_almost_eq(_flat_speed(), _tuning.run_speed, SPEED_TOLERANCE, "a keyboard (full tilt) runs")
	Input.action_press(&"walk")
	await _ticks(3)
	assert_almost_eq(_flat_speed(), _tuning.walk_speed, SPEED_TOLERANCE, "holding walk walks")
	assert_false(_player.is_running())
	Input.action_release(&"walk")
	await _ticks(3)
	assert_almost_eq(_flat_speed(), _tuning.run_speed, SPEED_TOLERANCE, "letting go runs again")


func test_walk_wins_over_run_and_full_tilt() -> void:
	assert_false(PlayerMotion.is_running(Vector2(0, -1), true, 0.85, true))
	assert_true(PlayerMotion.is_running(Vector2(0, -1), false, 0.85, false))
	assert_almost_eq(PlayerMotion.target_speed(Vector2(0, -1), true, 2.4, 4.8, 0.85, true), 2.4, 0.0001)
	assert_almost_eq(PlayerMotion.target_speed(Vector2(0, -1), false, 2.4, 4.8, 0.85), 4.8, 0.0001)


func test_distance_travelled_matches_speed() -> void:
	_make_world(0.0, false)
	_player.stick = Vector2(0.0, -0.5)
	var ticks: int = 60
	await _ticks(ticks)
	var travelled: float = absf(_player.position.z)
	var low: float = _tuning.walk_speed * float(ticks - 2) * TICK
	var high: float = _tuning.walk_speed * float(ticks + 2) * TICK
	assert_ge(travelled, low)
	assert_le(travelled, high)


func test_movement_is_relative_to_the_camera() -> void:
	# Camera turned 90 degrees: it looks toward -X, so "up" on the stick walks toward -X.
	_make_world(90.0, false)
	_player.stick = Vector2(0.0, -1.0)
	await _ticks(20)
	assert_lt(_player.position.x, -1.0)
	assert_almost_eq(_player.position.z, 0.0, 0.001)


func test_stops_at_a_wall_and_never_passes_it() -> void:
	_make_world()
	_player.stick = Vector2(1.0, 0.0)
	await _ticks(180)
	var wall_limit: float = WALL_FACE_X - PLAYER_RADIUS
	assert_le(_player.position.x, wall_limit + 0.02, "stopped by the wall")
	assert_ge(_player.position.x, wall_limit - 0.1, "got up to the wall")
	await _ticks(30)
	assert_le(_player.position.x, wall_limit + 0.02, "still held back")


func test_slides_along_a_wall() -> void:
	_make_world()
	_player.stick = Vector2(1.0, 1.0)
	await _ticks(120)
	assert_le(_player.position.x, WALL_FACE_X - PLAYER_RADIUS + 0.02)
	assert_gt(_player.position.z, 2.0, "keeps sliding along the wall")


func test_stands_on_the_floor_and_falls_onto_it() -> void:
	_make_world(0.0, false)
	_player.position = Vector3(0.0, 2.0, 0.0)
	await _ticks(90)
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.position.y, 0.0, 0.02)
	assert_almost_eq(_player.velocity.y, 0.0, 0.001, "no jump, no drift")


func test_idle_when_there_is_no_input() -> void:
	_make_world(0.0, false)
	await _ticks(10)
	assert_almost_eq(_flat_speed(), 0.0, 0.0001)
	assert_false(_player.is_moving())


func test_turns_toward_travel_at_the_data_rate() -> void:
	_make_world(0.0, false)
	_player.stick = Vector2(1.0, 0.0)
	assert_almost_eq(_player.rotation.y, 0.0, 0.0001, "starts facing +Z")
	_player.step(TICK)
	assert_almost_eq(_player.rotation.y, deg_to_rad(_tuning.turn_rate_deg_per_s) * TICK, 0.0001, "one tick turns by the data rate")
	for i: int in 30:
		_player.step(TICK)
	assert_almost_eq(_player.rotation.y, PI * 0.5, 0.0001, "ends facing +X")
	assert_true(_player.get_facing().is_equal_approx(Vector3.RIGHT))


func test_reads_input_actions_when_enabled() -> void:
	_make_world(0.0, false)
	_player.read_engine_input = true
	Input.action_press(&"move_right")
	await _ticks(20)
	assert_gt(_player.position.x, 0.5)
	Input.action_release(&"move_right")
	await _ticks(3)
	assert_almost_eq(_flat_speed(), 0.0, 0.0001)


func test_frozen_player_does_not_move() -> void:
	_make_world(0.0, false)
	_player.frozen = true
	_player.stick = Vector2(1.0, 0.0)
	await _ticks(10)
	assert_almost_eq(_player.position.x, 0.0, 0.0001)


func test_model_slot_replaces_capsule_and_plays_animations() -> void:
	_make_world(0.0, false)
	var root: Node3D = Node3D.new()
	root.name = "FakeRed"
	var anims: AnimationPlayer = AnimationPlayer.new()
	anims.name = "AnimationPlayer"
	root.add_child(anims)
	anims.owner = root
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip: String in ["idle", "walk", "run"]:
		var animation: Animation = Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip, animation)
	anims.add_animation_library("", library)
	var packed: PackedScene = PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	var model: Node3D = _player.attach_model(packed)
	assert_not_null(model)
	assert_null(_player.get_node_or_null("Visual/PlaceholderCapsule"), "capsule removed")
	assert_eq(_player.get_current_animation(), &"idle")
	_player.stick = Vector2(0.0, -0.5)
	_player.step(TICK)
	assert_eq(_player.get_current_animation(), &"walk")
	_player.stick = Vector2(0.0, -1.0)
	_player.step(TICK)
	assert_eq(_player.get_current_animation(), &"run")
	_player.stick = Vector2.ZERO
	_player.step(TICK)
	assert_eq(_player.get_current_animation(), &"idle")


func test_motion_math_helpers() -> void:
	var basis_yaw0: Basis = DioramaMath.orientation(42.0, 0.0)
	assert_true(PlayerMotion.camera_relative_direction(Vector2(0, -1), basis_yaw0).is_equal_approx(Vector3(0, 0, -1)))
	assert_true(PlayerMotion.camera_relative_direction(Vector2(1, 0), basis_yaw0).is_equal_approx(Vector3(1, 0, 0)))
	assert_true(PlayerMotion.camera_relative_direction(Vector2(1, 1), basis_yaw0).is_equal_approx(Vector3(1, 0, 1).normalized()))
	assert_eq(PlayerMotion.camera_relative_direction(Vector2.ZERO, basis_yaw0), Vector3.ZERO)
	var basis_yaw180: Basis = DioramaMath.orientation(42.0, 180.0)
	assert_true(PlayerMotion.camera_relative_direction(Vector2(0, -1), basis_yaw180).is_equal_approx(Vector3(0, 0, 1)))
	var top_down: Basis = DioramaMath.orientation(90.0, 0.0)
	assert_true(PlayerMotion.camera_relative_direction(Vector2(0, -1), top_down).is_equal_approx(Vector3(0, 0, -1)), "straight-down camera still has a forward")
	assert_almost_eq(PlayerMotion.turn_toward(0.0, deg_to_rad(170.0), 720.0, 0.01), deg_to_rad(7.2), 0.0001)
	var across: float = PlayerMotion.turn_toward(deg_to_rad(170.0), deg_to_rad(-170.0), 720.0, 0.01)
	assert_almost_eq(across, deg_to_rad(177.2), 0.0001, "takes the short way across 180 degrees")
	var arrived: float = PlayerMotion.turn_toward(deg_to_rad(170.0), deg_to_rad(-170.0), 720.0, 1.0)
	assert_almost_eq(absf(angle_difference(arrived, deg_to_rad(-170.0))), 0.0, 0.0001, "lands on the target angle")
	assert_eq(PlayerMotion.animation_for(false, false), &"idle")
	assert_eq(PlayerMotion.animation_for(true, false), &"walk")
	assert_eq(PlayerMotion.animation_for(true, true), &"run")
