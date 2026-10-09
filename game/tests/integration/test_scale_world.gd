extends TestCase
## CS-21: what changes around Red when she changes size: the camera's look and its blend, the shake cap, the lock-on reach, the
## fog, the shadow range, the sound's pitch, and a fighter's standing speed. The pieces that live in other roles' files get a
## small test each, so a later change there cannot quietly break the robot test.

const DT: float = 1.0 / 60.0


class FakeEnemy extends Node3D:
	var hp: int = 10


func _camera() -> OrbitCamera:
	var red: Node3D = add_to_root(Node3D.new()) as Node3D
	red.rotation.y = PI
	var cam: OrbitCamera = OrbitCamera.new()
	cam.read_engine_input = false
	add_to_root(cam)
	cam.follow(red)
	cam.snap()
	return cam


func _run(cam: OrbitCamera, seconds: float) -> void:
	for i: int in int(seconds / DT):
		cam.tick(DT)


func _view(id: StringName) -> Dictionary:
	return ScaleProfile.camera_view(ScaleProfile.camera_block(id), ScaleProfile.camera_block(&"red"))


func _arm(cam: OrbitCamera) -> float:
	return cam.get_camera().position.z


func test_the_camera_without_a_scale_view_is_exactly_as_before() -> void:
	var cam: OrbitCamera = _camera()
	_run(cam, 0.5)
	assert_false(cam.has_scale_view())
	assert_almost_eq(_arm(cam), DataDB.get_value("combat/camera", "orbit.distance_m"), 0.05)
	assert_almost_eq(cam.get_camera().fov, float(DataDB.get_value("combat/camera", "orbit.fov_deg")), 0.05)
	assert_almost_eq(cam.get_camera().far, float(DataDB.get_value("combat/camera", "orbit.far")), 0.001)


func test_a_scale_view_pulls_the_camera_back_over_its_blend_not_in_one_frame() -> void:
	var cam: OrbitCamera = _camera()
	var start: float = _arm(cam)
	cam.set_scale_view(_view(&"small"), 1.3)
	assert_true(cam.is_scale_view_blending())
	cam.tick(DT)
	assert_lt(_arm(cam), start + 1.0, "after one frame it has barely moved: a pull-back, not a cut")
	_run(cam, 0.65)
	var half: float = _arm(cam)
	assert_gt(half, start + 2.0, "halfway: well on its way")
	assert_lt(half, 14.0 - 2.0, "but not there yet")
	_run(cam, 0.8)
	assert_false(cam.is_scale_view_blending())
	assert_almost_eq(_arm(cam), 14.0, 0.2, "the loader's 14 m")
	assert_almost_eq(cam.get_camera().fov, 60.0, 0.5)


func test_the_huge_view_is_75_metres_back_with_a_matching_draw_distance() -> void:
	var cam: OrbitCamera = _camera()
	cam.set_scale_view(_view(&"huge"), 1.5)
	_run(cam, 1.7)
	assert_almost_eq(_arm(cam), 75.0, 0.5)
	assert_almost_eq(cam.get_camera().fov, 56.0, 0.5)
	assert_almost_eq(cam.get_camera().far, 5000.0, 1.0, "the far plane grew with the body")
	assert_almost_eq(cam.get_camera().near, 2.0, 0.01)
	assert_almost_eq(cam.get_focus().y, 26.0, 0.1, "looking at the robot's chest, 26 m up")
	assert_gt(cam.get_camera().far, 10.0 * _arm(cam))


func test_the_feel_panels_camera_distance_still_counts_in_a_robot() -> void:
	var cam: OrbitCamera = _camera()
	var knobs: FeelKnobs = FeelKnobs.load_defaults()
	cam.knobs = knobs
	knobs.set_value("cam_distance_m", 6.0)
	cam.set_scale_view(_view(&"small"), 0.0)
	_run(cam, 0.5)
	assert_almost_eq(_arm(cam), 6.0 * 14.0 / 4.5, 0.2, "twice Red's panel distance, scaled by the form")


func test_the_scale_view_can_go_back_to_red_exactly() -> void:
	var cam: OrbitCamera = _camera()
	cam.set_scale_view(_view(&"huge"), 0.0)
	_run(cam, 0.3)
	cam.set_scale_view(_view(&"red"), 1.0)
	_run(cam, 1.2)
	assert_almost_eq(_arm(cam), 4.5, 0.1)
	assert_almost_eq(cam.get_camera().fov, 62.0, 0.1)
	assert_almost_eq(cam.get_focus().y, 0.8, 0.05)


func test_the_shake_cap_follows_the_view_so_a_far_camera_still_shakes() -> void:
	var cam: OrbitCamera = _camera()
	cam.set_scale_view(_view(&"red"), 0.0)
	cam.shake(&"step_huge", 6.0, false)
	cam.tick(DT)
	var red_offset: float = cam.get_shake_offset().length()
	assert_lt(red_offset, 0.25, "Red's camera never moves more than 0.25 m")
	var far: OrbitCamera = _camera()
	far.set_scale_view(_view(&"huge"), 0.0)
	far.shake(&"step_huge", 6.0, false)
	var peak: float = 0.0
	for i: int in 20:
		far.tick(DT)
		peak = maxf(peak, far.get_shake_offset().length())
	assert_gt(peak, 0.3, "a 6x step at 75 m moves the camera well past Red's 0.25 m cap")
	assert_le(peak, 3.0 + 0.001, "but never past the huge form's own cap")


func test_hit_shakes_are_scaled_by_the_form_and_footstep_shakes_are_not_scaled_twice() -> void:
	var cam: OrbitCamera = _camera()
	cam.set_scale_view(_view(&"huge"), 0.0)
	cam.shake(&"heavy", 1.0, true)
	var scaled: float = 0.0
	for i: int in 6:
		cam.tick(DT)
		scaled = maxf(scaled, cam.get_shake_offset().length())
	var plain: OrbitCamera = _camera()
	plain.set_scale_view(_view(&"huge"), 0.0)
	plain.shake(&"heavy", 1.0, false)
	var unscaled: float = 0.0
	for i: int in 6:
		plain.tick(DT)
		unscaled = maxf(unscaled, plain.get_shake_offset().length())
	assert_gt(scaled, unscaled * 3.0, "scaled = the form's shake_mult (5x)")


func test_camera_shake_class_cap_is_per_instance() -> void:
	var shaker: CameraShake = CameraShake.new()
	shaker.add({"amplitude_m": 0.19, "duration_s": 0.5, "frequency_hz": 4.5}, 10.0)
	assert_almost_eq(shaker.amplitude_now(), CameraShake.MAX_AMPLITUDE_M, 0.0001, "default cap 0.25 m")
	var wide: CameraShake = CameraShake.new()
	wide.max_amplitude_m = 3.0
	wide.add({"amplitude_m": 0.19, "duration_s": 0.5, "frequency_hz": 4.5}, 10.0)
	assert_almost_eq(wide.amplitude_now(), 1.9, 0.0001, "a per-profile cap lets a huge step through")
	wide.add({"amplitude_m": 0.19, "duration_s": 0.5, "frequency_hz": 4.5}, 100.0)
	assert_almost_eq(wide.amplitude_now(), 3.0, 0.0001, "and still caps")


func test_lock_on_reach_scales_with_the_body() -> void:
	var red: Node3D = add_to_root(Node3D.new()) as Node3D
	var lock: LockOn = LockOn.new()
	lock.read_engine_input = false
	add_to_root(lock)
	lock.origin_node = red
	var far_enemy: FakeEnemy = FakeEnemy.new()
	add_to_root(far_enemy)
	far_enemy.global_position = Vector3(0, 0, -60)
	lock.candidate_provider = func() -> Array: return [far_enemy]
	assert_null(lock.best_target(), "60 m is out of Red's 16 m reach")
	lock.range_scale = 14.0
	assert_eq(lock.best_target(), far_enemy, "the colossus's reach is 14 times longer")


func test_room_look_fog_override_survives_a_look_change() -> void:
	var host: Node3D = add_to_root(Node3D.new()) as Node3D
	var look: PsxRoomLook = PsxRoomLook.new()
	host.add_child(look)
	var own: Vector2 = look.fog_distances()
	look.set_fog_distances(300.0, 1500.0)
	assert_eq(look.fog_distances(), Vector2(300.0, 1500.0))
	look.apply()
	assert_eq(look.fog_distances(), Vector2(300.0, 1500.0), "re-applying the look keeps the robot's haze")
	look.fog_override = Vector2.ZERO
	look.apply()
	assert_eq(look.fog_distances(), own, "without the override the profile's own haze is back")


func test_the_audio_manager_pitches_sounds_down_and_muffles_them_for_a_big_body() -> void:
	var audio: Node = tree.root.get_node("AudioManager")
	audio.call("set_scale_feel", 0.4, 4500.0)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 0.4, 0.0001)
	assert_almost_eq(float(audio.call("get_scale_lowpass_hz")), 4500.0, 0.0001)
	var bus: int = AudioServer.get_bus_index(&"SFX")
	var found: int = 0
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			found += 1
	assert_eq(found, 1, "one low-pass on the SFX bus")
	audio.call("set_scale_feel", 0.4, 3000.0)
	found = 0
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			found += 1
			assert_almost_eq((AudioServer.get_bus_effect(bus, i) as AudioEffectLowPassFilter).cutoff_hz, 3000.0, 0.01)
	assert_eq(found, 1, "changing it does not stack a second filter")
	audio.call("set_scale_feel", 1.0, 0.0)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 1.0, 0.0001)
	found = 0
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			found += 1
	assert_eq(found, 0, "and Red's sound is clean again")


func test_a_fighters_standing_speed_slows_it_but_hit_stop_still_freezes_it() -> void:
	var time: CombatTime = CombatTime.new()
	assert_almost_eq(time.scale_for(&"red"), 1.0, 0.0001)
	time.set_base_scale(&"red", 0.45)
	assert_almost_eq(time.scale_for(&"red"), 0.45, 0.0001)
	assert_almost_eq(time.step_scale_for(&"red", DT), 0.45, 0.0001)
	assert_almost_eq(time.scale_for(&"wolf"), 1.0, 0.0001, "only her")
	time.add_hit_stop([&"red"] as Array[StringName], 100.0)
	assert_almost_eq(time.scale_for(&"red"), 0.0, 0.0001, "hit-stop wins")
	time.set_base_scale(&"red", 1.0)
	assert_almost_eq(time.base_scale_of(&"red"), 1.0, 0.0001)
