extends TestCase
## Red's jump: reaches the data height, lands, forgives a late or early press (coyote time and
## jump buffering), is shorter when the button is released early, lands on a 0.8-unit crate, has no
## double jump, keeps her momentum on landing, and does not bob the camera.
##
## These tests turn Red's own physics step off and call step() themselves, so every frame is exact.

const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const TICK: float = 1.0 / 60.0
const FLOOR_SIZE: Vector3 = Vector3(60.0, 1.0, 60.0)
const CRATE_HEIGHT: float = 0.8
const HEIGHT_TOLERANCE: float = 0.05
const LEDGE_EDGE_X: float = 2.0
const MAX_STEPS: int = 600

var _player: PlayerController = null
var _tuning: FieldTuning = null


func before_each() -> void:
	_tuning = FieldTuning.from_db(tree.root.get_node("DataDB"))


func after_each() -> void:
	Input.action_release(&"jump")
	Input.action_release(&"move_up")


func _box_body(center: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	return body


## Flat floor (top at y = 0) and Red standing on it at the origin, camera looking down -Z.
## `floor_x_max` cuts the floor off at that x so there is a ledge to walk off.
func _make_world(floor_x_max: float = 30.0) -> void:
	var floor_min_x: float = -30.0
	var floor_width: float = floor_x_max - floor_min_x
	add_to_root(_box_body(Vector3(floor_min_x + floor_width * 0.5, -FLOOR_SIZE.y * 0.5, 0.0),
			Vector3(floor_width, FLOOR_SIZE.y, FLOOR_SIZE.z)))
	var camera: Camera3D = add_to_root(Camera3D.new()) as Camera3D
	camera.global_transform = Transform3D(DioramaMath.orientation(42.0, 0.0), Vector3(0.0, 7.0, 7.5))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	_player.read_engine_input = false
	_player.camera = camera
	_player.position = Vector3(0.0, 0.0, 0.0)
	add_to_root(_player)
	_player.set_tuning(_tuning)
	await tree.physics_frame
	await tree.physics_frame
	_player.set_physics_process(false)
	_settle()


func _settle() -> void:
	for i: int in 10:
		_player.step(TICK)


func _steps(count: int) -> void:
	for i: int in count:
		_player.step(TICK)


## Jumps and returns the peak height. Releases the button at `release_after` steps (-1 = hold it).
func _jump_peak(release_after: int = -1) -> float:
	var peak: float = 0.0
	_player.jump_held = true
	_player.request_jump()
	var steps: int = 0
	while steps < MAX_STEPS:
		_player.step(TICK)
		steps += 1
		peak = maxf(peak, _player.position.y)
		if release_after >= 0 and steps >= release_after:
			_player.jump_held = false
		if steps > 3 and _player.is_on_floor():
			break
	_player.jump_held = false
	return peak


func test_jump_reaches_the_data_height_and_lands() -> void:
	await _make_world()
	var peak: float = _jump_peak()
	assert_almost_eq(peak, _tuning.jump_height, HEIGHT_TOLERANCE, "peak matches data jump height")
	assert_ge(peak, 1.1, "about 1.2 units")
	assert_true(_player.is_on_floor(), "lands")
	assert_almost_eq(_player.position.y, 0.0, 0.02, "back on the ground")


func test_jump_signals_and_air_state() -> void:
	await _make_world()
	var events: Array[String] = []
	_player.jumped.connect(func() -> void: events.append("jumped"))
	_player.landed.connect(func() -> void: events.append("landed"))
	assert_false(_player.is_airborne())
	_player.jump_held = true
	_player.request_jump()
	_player.step(TICK)
	assert_true(_player.is_airborne())
	_steps(60)
	assert_eq(events, ["jumped", "landed"])
	assert_false(_player.is_airborne())


func test_rise_is_snappier_than_the_fall_is_slow() -> void:
	await _make_world()
	_player.jump_held = true
	_player.request_jump()
	var rise_steps: int = 0
	var fall_steps: int = 0
	var peaked: bool = false
	for i: int in 120:
		_player.step(TICK)
		if _player.is_on_floor() and i > 3:
			break
		if not peaked and _player.velocity.y > 0.0:
			rise_steps += 1
		else:
			peaked = true
			fall_steps += 1
	assert_gt(rise_steps, 0)
	assert_lt(fall_steps, rise_steps * 1, "falling takes less time than rising (higher fall gravity)")
	assert_almost_eq(float(rise_steps) * TICK, _tuning.jump_rise_time_s, 0.05, "rise time from data")


func test_releasing_early_gives_a_lower_jump() -> void:
	await _make_world()
	var full: float = _jump_peak()
	_settle()
	var short: float = _jump_peak(3)
	assert_lt(short, full * 0.6, "released early: well under the full jump")
	assert_gt(short, 0.1, "still a hop, not nothing")
	_settle()
	var held_longer: float = _jump_peak(12)
	assert_gt(held_longer, short, "holding longer jumps higher")
	assert_le(held_longer, full + 0.001)


func test_no_jump_without_a_request() -> void:
	await _make_world()
	_player.jump_held = true
	_steps(30)
	assert_true(_player.is_on_floor(), "holding the button alone does not jump")
	assert_almost_eq(_player.position.y, 0.0, 0.02)


func test_coyote_time_lets_a_late_jump_work_after_walking_off_a_ledge() -> void:
	await _make_world(LEDGE_EDGE_X)
	_player.stick = Vector2(1.0, 0.0)
	var guard: int = 0
	while _player.is_on_floor() and guard < MAX_STEPS:
		_player.step(TICK)
		guard += 1
	_player.step(TICK)
	assert_false(_player.is_on_floor(), "walked off the ledge")
	# A jump a few frames after leaving still works.
	var late_steps: int = int(_tuning.jump_coyote_time_s / TICK * 0.5)
	_steps(late_steps)
	_player.jump_held = true
	_player.request_jump()
	_player.step(TICK)
	assert_gt(_player.velocity.y, 0.0, "coyote jump rose even though she was off the ledge")


func test_no_coyote_jump_once_the_grace_time_has_passed() -> void:
	await _make_world(LEDGE_EDGE_X)
	_player.stick = Vector2(1.0, 0.0)
	var guard: int = 0
	while _player.is_on_floor() and guard < MAX_STEPS:
		_player.step(TICK)
		guard += 1
	_steps(int(ceil(_tuning.jump_coyote_time_s / TICK)) + 3)
	var fall_speed: float = _player.velocity.y
	_player.jump_held = true
	_player.request_jump()
	_player.step(TICK)
	assert_lt(_player.velocity.y, fall_speed + 0.001, "too late: still falling, no jump")
	assert_lt(_player.velocity.y, 0.0)


func test_jump_buffer_fires_a_press_made_just_before_landing() -> void:
	await _make_world()
	_player.position.y = 0.6
	_player.velocity = Vector3.ZERO
	_player.step(TICK)
	assert_false(_player.is_on_floor())
	var jumped_events: Array[bool] = [false]
	_player.jumped.connect(func() -> void: jumped_events[0] = true)
	var pressed: bool = false
	for i: int in 120:
		if not pressed and _player.position.y < 0.1 and _player.velocity.y < 0.0:
			_player.jump_held = true
			_player.request_jump()
			pressed = true
		_player.step(TICK)
		if jumped_events[0]:
			break
	assert_true(pressed, "pressed jump while still falling")
	assert_true(jumped_events[0], "the buffered press jumped as soon as she landed")


func test_press_too_early_before_landing_is_forgotten() -> void:
	await _make_world()
	_player.position.y = 3.0
	_steps(10)
	assert_gt(_player.position.y, 1.0, "still falling")
	var jumped_events: Array[bool] = [false]
	_player.jumped.connect(func() -> void: jumped_events[0] = true)
	_player.request_jump()
	for i: int in 120:
		_player.step(TICK)
	assert_false(jumped_events[0], "a press far from the ground does not jump later")
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.position.y, 0.0, 0.02)


func test_no_double_jump() -> void:
	await _make_world()
	_player.jump_held = true
	_player.request_jump()
	_steps(8)
	var speed_before: float = _player.velocity.y
	assert_gt(speed_before, 0.0, "still rising")
	_player.request_jump()
	_steps(1)
	assert_lt(_player.velocity.y, speed_before, "a second press in the air does not re-launch")
	var peak: float = _player.position.y
	for i: int in 120:
		_steps(1)
		peak = maxf(peak, _player.position.y)
		_player.jump_held = true
		if _player.is_on_floor():
			break
	assert_lt(peak, _tuning.jump_height + HEIGHT_TOLERANCE, "never higher than one jump")


func test_lands_on_top_of_a_crate_and_stays_there() -> void:
	await _make_world()
	var crate_face_x: float = 2.0
	add_to_root(_box_body(Vector3(crate_face_x + 2.0, CRATE_HEIGHT * 0.5, 0.0), Vector3(4.0, CRATE_HEIGHT, 3.0)))
	await tree.physics_frame
	await tree.physics_frame
	_player.stick = Vector2(1.0, 0.0)
	_player.run_held = true
	_steps(5)
	_player.position.x = 0.9
	_player.jump_held = true
	_player.request_jump()
	for i: int in 120:
		_player.step(TICK)
		if i > 3 and _player.is_on_floor():
			break
	assert_true(_player.is_on_floor(), "landed")
	assert_almost_eq(_player.position.y, CRATE_HEIGHT, 0.03, "on top of the 0.8 crate")
	assert_gt(_player.position.x, crate_face_x - 0.01, "over the crate, not beside it")
	_player.stick = Vector2.ZERO
	_steps(30)
	assert_almost_eq(_player.position.y, CRATE_HEIGHT, 0.03, "stays on top")


func test_cannot_walk_onto_a_crate_without_jumping() -> void:
	await _make_world()
	add_to_root(_box_body(Vector3(2.75, CRATE_HEIGHT * 0.5, 0.0), Vector3(1.5, CRATE_HEIGHT, 3.0)))
	await tree.physics_frame
	await tree.physics_frame
	_player.stick = Vector2(1.0, 0.0)
	_steps(120)
	assert_lt(_player.position.y, 0.05, "a 0.8 crate is a wall to walking")
	assert_lt(_player.position.x, 2.0)


func test_landing_keeps_momentum() -> void:
	await _make_world()
	_player.stick = Vector2(1.0, 0.0)
	_player.run_held = true
	_steps(10)
	_player.jump_held = true
	_player.request_jump()
	var landed_at: int = -1
	for i: int in 120:
		_player.step(TICK)
		if i > 3 and _player.is_on_floor():
			landed_at = i
			break
	assert_gt(landed_at, 0)
	var x_at_landing: float = _player.position.x
	assert_almost_eq(Vector2(_player.velocity.x, _player.velocity.z).length(), _tuning.run_speed, 0.01, "still at run speed on landing")
	_steps(1)
	assert_almost_eq(_player.position.x - x_at_landing, _tuning.run_speed * TICK, 0.01, "keeps running through the landing")


func test_air_control_is_small_not_instant() -> void:
	await _make_world()
	_player.stick = Vector2(1.0, 0.0)
	_player.run_held = true
	_steps(10)
	_player.jump_held = true
	_player.request_jump()
	_steps(3)
	var before: float = _player.velocity.x
	_player.stick = Vector2(-1.0, 0.0)
	_steps(1)
	var change: float = absf(_player.velocity.x - before)
	assert_le(change, _tuning.jump_air_accel * TICK + 0.01, "turns around slowly in the air")
	assert_gt(change, 0.0, "but she does steer")
	assert_gt(_player.velocity.x, 0.0, "momentum carries her on")


func test_jump_distance_while_running_clears_a_small_gap() -> void:
	await _make_world()
	_player.stick = Vector2(1.0, 0.0)
	_player.run_held = true
	_steps(10)
	var start_x: float = _player.position.x
	_player.jump_held = true
	_player.request_jump()
	for i: int in 120:
		_player.step(TICK)
		if i > 3 and _player.is_on_floor():
			break
	assert_gt(_player.position.x - start_x, 2.5, "a running jump covers a gap of a couple of units")


func test_frozen_red_does_not_jump() -> void:
	await _make_world()
	_player.frozen = true
	_player.jump_held = true
	_player.request_jump()
	_steps(10)
	assert_almost_eq(_player.position.y, 0.0, 0.02)


func test_reads_the_jump_action_from_the_engine() -> void:
	await _make_world()
	_player.set_physics_process(true)
	_player.read_engine_input = true
	Input.action_press(&"jump")
	var peak: float = 0.0
	for i: int in 20:
		await tree.physics_frame
		peak = maxf(peak, _player.position.y)
	assert_gt(peak, 0.5, "pressing the jump action makes Red jump")
	Input.action_release(&"jump")


func test_camera_does_not_bob_while_jumping() -> void:
	await _make_world()
	var rig: DioramaCamera = DioramaCamera.new()
	rig.aspect_override = 384.0 / 216.0
	rig.auto_update = false
	rig.target = _player
	add_to_root(rig)
	rig.snap_to_target()
	var start_y: float = rig.get_focus().y
	var lowest: float = start_y
	var highest: float = start_y
	_player.jump_held = true
	_player.request_jump()
	for i: int in 60:
		_player.step(TICK)
		rig.update_camera(TICK)
		lowest = minf(lowest, rig.get_focus().y)
		highest = maxf(highest, rig.get_focus().y)
	assert_almost_eq(highest - lowest, 0.0, 0.001, "the camera's height holds steady through a jump")
	assert_true(rig.is_target_in_safe_frame(), "Red stays in frame at the top of the jump")


func test_camera_eases_up_when_red_lands_on_a_crate() -> void:
	await _make_world()
	add_to_root(_box_body(Vector3(4.0, CRATE_HEIGHT * 0.5, 0.0), Vector3(4.0, CRATE_HEIGHT, 3.0)))
	await tree.physics_frame
	await tree.physics_frame
	var rig: DioramaCamera = DioramaCamera.new()
	rig.aspect_override = 384.0 / 216.0
	rig.auto_update = false
	rig.target = _player
	add_to_root(rig)
	rig.snap_to_target()
	_player.stick = Vector2(1.0, 0.0)
	_player.run_held = true
	_steps(5)
	_player.position.x = 0.9
	_player.jump_held = true
	_player.request_jump()
	for i: int in 240:
		_player.step(TICK)
		rig.update_camera(TICK)
		if i > 3 and _player.is_on_floor():
			_player.stick = Vector2.ZERO
	assert_almost_eq(_player.position.y, CRATE_HEIGHT, 0.03)
	assert_almost_eq(rig.get_focus().y, CRATE_HEIGHT + rig.target_anchor_height, 0.05, "camera settles at the crate's height")


func test_air_animation_falls_back_without_jump_and_fall_clips_and_uses_them_when_present() -> void:
	await _make_world()
	var with_clips: bool = true
	for clips: PackedStringArray in [PackedStringArray(["idle", "walk", "run"]), PackedStringArray(["idle", "walk", "run", "jump", "fall"])]:
		_attach_fake_model(clips)
		_settle()
		_player.jump_held = true
		_player.request_jump()
		_steps(4)
		var rising: StringName = _player.get_current_animation()
		var saw_fall: StringName = &""
		for i: int in 120:
			_steps(1)
			if _player.velocity.y < -1.0 and saw_fall == &"":
				saw_fall = _player.get_current_animation()
			if _player.is_on_floor():
				break
		_steps(2)
		if with_clips == false:
			pass
		if clips.has("jump"):
			assert_eq(rising, &"jump", "rising plays jump")
			assert_eq(saw_fall, &"fall", "falling plays fall")
		else:
			assert_eq(rising, &"idle", "no jump clip: stays on idle when standing still")
			assert_eq(saw_fall, &"idle")
		assert_eq(_player.get_current_animation(), &"idle", "back to idle on the ground")
		_player.jump_held = false
		with_clips = false


func _attach_fake_model(clips: PackedStringArray) -> void:
	var root: Node3D = Node3D.new()
	var anims: AnimationPlayer = AnimationPlayer.new()
	anims.name = "AnimationPlayer"
	root.add_child(anims)
	anims.owner = root
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip: String in clips:
		var animation: Animation = Animation.new()
		animation.length = 1.0
		library.add_animation(clip, animation)
	anims.add_animation_library("", library)
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	_player.attach_model(packed)


func test_air_animation_candidates() -> void:
	assert_eq(PlayerMotion.air_animation_candidates(true, false), [&"jump", &"idle"])
	assert_eq(PlayerMotion.air_animation_candidates(false, true), [&"fall", &"run"])


func test_jump_math_matches_height_and_rise_time() -> void:
	var v: float = PlayerMotion.jump_speed(1.2, 0.4)
	var g: float = PlayerMotion.jump_gravity(1.2, 0.4)
	assert_almost_eq(v, 6.0, 0.0001)
	assert_almost_eq(g, 15.0, 0.0001)
	assert_almost_eq(v * v / (2.0 * g), 1.2, 0.0001, "v squared over 2g is the height")
	assert_almost_eq(v / g, 0.4, 0.0001, "v over g is the rise time")
