extends TestCase
## ActionPlayer (docs/pivot/combat_api.md 4.2 and section 7): camera-relative run, coyote time and the
## jump buffer, the dash (distance, i-frames, one air-dash per jump, through enemies), attacks and cancels
## on her own clock, hit-stop, the parry, and getting hit. Driven by hand with the bot API:
## press() / release() / set_move_input() and tick().

const SCENE: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

var _player: ActionPlayer = null
var _floor: StaticBody3D = null
var _director: CombatDirector = null


func _arena(with_director: bool = false) -> void:
	_floor = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80, 2, 80)
	shape.shape = box
	_floor.add_child(shape)
	_floor.collision_layer = 1
	add_to_root(_floor)
	_floor.global_position = Vector3(0, -1, 0)
	if with_director:
		_director = CombatDirector.new()
		_director.sync_to_wall_clock = false
		add_to_root(_director)
		_director.set_physics_process(false)
	_player = (load(SCENE) as PackedScene).instantiate() as ActionPlayer
	_player.read_engine_input = false
	add_to_root(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0.02, 0)
	await tree.physics_frame
	await tree.physics_frame
	_step(10)


func _step(frames: int) -> void:
	for i: int in frames:
		if _director != null:
			_director.tick(DT)
		_player.tick(DT)


func _step_until(condition: Callable, max_frames: int = 240) -> int:
	var frames: int = 0
	while not bool(condition.call()) and frames < max_frames:
		_step(1)
		frames += 1
	return frames


## Presses dash and runs until that dash is over.
func _dash_through() -> void:
	_player.press(&"dash")
	_step(1)
	_step_until(func() -> bool: return _player.get_dash() == null)


func _enemy(pos: Vector3) -> CombatActor:
	var enemy: CombatActor = CombatActor.new()
	enemy.actor_id = &"dummy_%d" % int(pos.x * 10.0 + pos.z)
	enemy.team = &"enemy"
	enemy.move_set_id = &"grunt"
	enemy.hp = 500
	enemy.hp_max = 500
	add_to_root(enemy)
	enemy.global_position = pos
	return enemy


func test_it_stands_on_the_floor_and_idles() -> void:
	await _arena()
	assert_true(_player.is_on_floor())
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)
	assert_false(_player.is_airborne())


func test_her_layers_are_player_body_and_she_collides_with_world_and_enemy_bodies() -> void:
	await _arena()
	assert_eq(_player.collision_layer, 1 << 9, "layer 10: player_body")
	assert_eq(_player.collision_mask, (1 << 0) | (1 << 10), "mask: world and enemy_body")


func test_stick_up_runs_toward_the_top_of_the_screen_whatever_way_the_camera_faces() -> void:
	await _arena()
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	cam.global_basis = Basis.IDENTITY                 # looks along -Z
	_player.set_move_input(Vector2(0, -1))
	_step(30)
	assert_lt(_player.global_position.z, -2.0, "up on the stick: away from the camera (-Z)")
	assert_almost_eq(_player.global_position.x, 0.0, 0.05)
	assert_gt(_player.get_facing().dot(Vector3(0, 0, -1)), 0.95, "and she turned to face where she runs")
	# Camera turns to look along +X: now up on the stick runs along +X.
	_player.set_move_input(Vector2.ZERO)
	_step(30)
	cam.global_basis = Basis.from_euler(Vector3(0, -PI * 0.5, 0))
	var before: Vector3 = _player.global_position
	_player.set_move_input(Vector2(0, -1))
	_step(30)
	assert_gt(_player.global_position.x - before.x, 2.0, "camera-relative: no tank controls")
	_player.set_move_input(Vector2(1, 0))
	_step(30)
	assert_gt(_player.global_position.z - before.z, 2.0, "stick right with that camera runs toward +Z")


func test_run_speed_follows_the_knob_live_and_the_stick_is_analog() -> void:
	await _arena()
	_player.set_move_input(Vector2(0, -1))
	_step(40)
	var full: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(full, _player.knobs.get_f("run_speed_mps"), 0.05)
	_player.knobs.set_value("run_speed_mps", 9.0)
	_step(20)
	assert_almost_eq(Vector2(_player.velocity.x, _player.velocity.z).length(), 9.0, 0.05, "a knob change works straight away")
	_player.set_move_input(Vector2(0, -0.5))
	_step(30)
	assert_almost_eq(Vector2(_player.velocity.x, _player.velocity.z).length(), 4.5, 0.1, "half a stick is half speed")
	_player.set_move_input(Vector2.ZERO)
	_step(15)
	assert_almost_eq(Vector2(_player.velocity.x, _player.velocity.z).length(), 0.0, 0.01, "stops dead")


func test_jump_reaches_the_knob_height() -> void:
	await _arena()
	var peak: float = 0.0
	_player.press(&"jump")
	for i: int in 120:
		_step(1)
		peak = maxf(peak, _player.global_position.y)
	assert_almost_eq(peak, _player.knobs.get_f("jump_height_m"), 0.08)
	assert_true(_player.is_on_floor(), "and she comes back down")


func test_letting_go_of_jump_early_makes_a_short_hop() -> void:
	await _arena()
	_player.press(&"jump")
	_step(2)
	_player.release(&"jump")
	var peak: float = 0.0
	for i: int in 120:
		_step(1)
		peak = maxf(peak, _player.global_position.y)
	assert_lt(peak, _player.knobs.get_f("jump_height_m") * 0.7)
	assert_gt(peak, 0.1)


func test_jumped_and_landed_signals() -> void:
	await _arena()
	var log: Array[String] = []
	_player.jumped.connect(func(air: bool) -> void: log.append("jumped:%s" % air))
	_player.landed.connect(func() -> void: log.append("landed"))
	_player.press(&"jump")
	_step(120)
	assert_eq(log, ["jumped:false", "landed"])


func test_coyote_time_lets_her_jump_just_after_running_off_a_ledge() -> void:
	await _arena()
	# Walk her off the edge of a small platform: build one at x in [-2, 0], top at y=1, and start on it.
	var platform: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 1, 4)
	shape.shape = box
	platform.add_child(shape)
	platform.collision_layer = 1
	add_to_root(platform)
	platform.global_position = Vector3(-10, 0.5, 0)       # top at y = 1, x from -12 to -8
	await tree.physics_frame
	_player.global_position = Vector3(-8.6, 1.02, 0)
	_step(5)
	assert_true(_player.is_on_floor())
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	_player.set_move_input(Vector2(1, 0))                  # right = +X, off the edge at x = -8
	var frames: int = _step_until(func() -> bool: return not _player.is_on_floor())
	assert_lt(frames, 60, "she ran off the ledge")
	# A few frames later (inside the 100 ms coyote window) a jump press still jumps.
	_step(2)
	var y_before: float = _player.global_position.y
	_player.press(&"jump")
	_step(3)
	assert_gt(_player.global_position.y, y_before - 0.05, "the jump came out of the air")
	var rising: bool = false
	for i: int in 6:
		_step(1)
		rising = rising or _player.velocity.y > 0.5
	assert_true(rising, "coyote jump rises")


func test_no_coyote_jump_long_after_leaving_the_ground() -> void:
	await _arena()
	_player.global_position = Vector3(0, 6, 0)
	_step(30)
	assert_true(_player.is_airborne())
	var y: float = _player.global_position.y
	_player.press(&"jump")
	_step(3)
	assert_lt(_player.global_position.y, y, "no air jump")


func test_a_jump_pressed_just_before_landing_still_jumps() -> void:
	await _arena()
	_player.global_position = Vector3(0, 1.2, 0)
	var landed_frame: int = _step_until(func() -> bool: return _player.global_position.y < 0.5, 90)
	assert_lt(landed_frame, 90)
	_player.press(&"jump")                                 # a few frames before touching down
	var peak: float = 0.0
	for i: int in 90:
		_step(1)
		peak = maxf(peak, _player.global_position.y)
	assert_gt(peak, 1.0, "the buffered press fired on landing")


func test_dash_distance_matches_the_knob_within_5_percent() -> void:
	await _arena()
	_player.rotation.y = PI                                 # faces -Z
	var start: Vector3 = _player.global_position
	var dashes: Array[bool] = []
	_player.dashed.connect(func(air: bool) -> void: dashes.append(air))
	_player.press(&"dash")
	_step(1)
	assert_eq(_player.get_state(), ActionPlayer.State.DASH)
	assert_eq(dashes, [false])
	_step_until(func() -> bool: return _player.get_dash() == null)
	var travelled: float = start.distance_to(_player.global_position)
	# Measure at the dash's own end: the carried run-out afterwards adds a little, so compare the run itself.
	assert_almost_eq(travelled, _player.knobs.get_f("dash_distance_m"), _player.knobs.get_f("dash_distance_m") * 0.05)


func test_dash_distance_follows_the_knob() -> void:
	await _arena()
	_player.knobs.set_value("dash_distance_m", 6.0)
	_player.rotation.y = PI
	var start: Vector3 = _player.global_position
	_dash_through()
	assert_almost_eq(start.distance_to(_player.global_position), 6.0, 0.3)


func test_dash_goes_the_way_the_stick_points_else_the_way_she_faces() -> void:
	await _arena()
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	_player.set_move_input(Vector2(1, 0))
	_player.press(&"dash")
	_step(3)
	assert_gt(_player.get_dash().direction.dot(Vector3.RIGHT), 0.99)
	_step(60)
	_player.set_move_input(Vector2.ZERO)
	_step(20)
	_player.rotation.y = PI * 0.5                           # faces +X
	_player.press(&"dash")
	_step(2)
	assert_gt(_player.get_dash().direction.dot(Vector3.RIGHT), 0.99, "no stick: along her facing")


func test_iframes_last_dash_iframes_ms() -> void:
	await _arena()
	_player.knobs.set_value("dash_time_ms", 180)
	_player.knobs.set_value("dash_iframes_ms", 150)    # fixed here so a retune of the studio numbers can't break this check
	_player.press(&"dash")
	var frames: int = 0
	_step(1)
	while _player.is_invulnerable() and frames < 100:
		_step(1)
		frames += 1
	var measured_ms: float = float(frames + 1) * DT * 1000.0
	assert_almost_eq(measured_ms, _player.knobs.get_f("dash_iframes_ms"), 20.0, "i-frames last about 150 ms")
	assert_false(_player.is_invulnerable())
	assert_not_null(_player.get_dash(), "the dash is still going after the i-frames end")


func test_i_frames_follow_the_knob() -> void:
	await _arena()
	_player.knobs.set_value("dash_iframes_ms", 300)
	_player.knobs.set_value("dash_time_ms", 400)
	_player.press(&"dash")
	_step(1)
	var frames: int = 0
	while _player.is_invulnerable() and frames < 100:
		_step(1)
		frames += 1
	assert_almost_eq(float(frames + 1) * DT * 1000.0, 300.0, 20.0)


func test_she_dashes_through_enemies() -> void:
	await _arena()
	assert_ne(_player.collision_mask & (1 << 10), 0, "enemy bodies block her normally")
	_player.press(&"dash")
	_step(2)
	assert_eq(_player.collision_mask & (1 << 10), 0, "enemy_body is off in her mask while dashing")
	assert_ne(_player.collision_mask & 1, 0, "walls still stop her")
	_step_until(func() -> bool: return _player.get_dash() == null)
	assert_ne(_player.collision_mask & (1 << 10), 0, "and it comes back")


func test_dash_cooldown_blocks_an_instant_second_dash() -> void:
	await _arena()
	var count: Array[int] = [0]
	_player.dashed.connect(func(_air: bool) -> void: count[0] += 1)
	_dash_through()
	assert_eq(count[0], 1)
	assert_gt(_player.get_dash_cooldown_ms(), 0.0, "the cooldown is running")
	_player.press(&"dash")
	_step(3)
	assert_eq(count[0], 1, "a dash pressed the instant the last one ends is held back")
	_step(40)
	_player.press(&"dash")
	_step(2)
	assert_eq(count[0], 2, "after the cooldown it works again")


func test_one_air_dash_per_jump_and_the_ground_resets_it() -> void:
	await _arena()
	var air_dashes: Array[int] = [0]
	_player.dashed.connect(func(air: bool) -> void: air_dashes[0] += 1 if air else 0)
	_player.press(&"jump")
	_step(12)
	assert_true(_player.is_airborne())
	_dash_through()
	assert_eq(air_dashes[0], 1)
	assert_eq(_player.get_air_dashes_left(), 0)
	_step(20)
	_player.press(&"dash")
	_step(30)
	assert_eq(air_dashes[0], 1, "the second air-dash of the same jump does nothing")
	_step_until(func() -> bool: return _player.is_on_floor(), 300)
	_step(10)
	assert_eq(_player.get_air_dashes_left(), 1, "landing gives it back")
	_player.press(&"jump")
	_step(12)
	_player.press(&"dash")
	_step(4)
	assert_eq(air_dashes[0], 2, "a new jump, a new air-dash")


func test_air_dash_count_knob() -> void:
	await _arena()
	_player.knobs.set_value("air_dash_count", 2)
	var air_dashes: Array[int] = [0]
	_player.dashed.connect(func(air: bool) -> void: air_dashes[0] += 1 if air else 0)
	_player.press(&"jump")
	_step(10)
	_dash_through()
	_step(14)
	_player.press(&"dash")
	_step(6)
	assert_eq(air_dashes[0], 2)


func test_an_air_dash_hangs_level() -> void:
	await _arena()
	_player.press(&"jump")
	_step(10)
	var height: float = _player.global_position.y
	_player.press(&"dash")
	_step(5)
	assert_almost_eq(_player.global_position.y, height, 0.05, "no rise or fall while air-dashing")


func test_light_starts_light_one_and_the_string_follows_the_links() -> void:
	await _arena()
	var started: Array[StringName] = []
	_player.move_started.connect(func(id: StringName) -> void: started.append(id))
	_player.press(&"light")
	_step(1)
	assert_eq(_player.get_state(), ActionPlayer.State.ATTACK)
	assert_eq(started, [&"light_1"])
	# Mash light a bit early each time: each press waits in the buffer and fires at the chain window.
	for i: int in 2:
		_step_until(func() -> bool: return _player.get_runner().chain_window_open(_player.clock.now_usec()) or not _player.get_runner().is_busy(), 60)
		_player.press(&"light")
		_step(8)
	assert_eq(started, [&"light_1", &"light_2", &"light_3"])


func test_a_press_made_early_fires_exactly_at_the_chain_window() -> void:
	await _arena()
	_player.press(&"light")
	_step(2)
	var runner: MoveRunner = _player.get_runner()
	assert_eq(runner.current_move(), &"light_1")
	_player.press(&"light")                                  # at about 17 ms: well before chain[0] = 130 ms
	var frames: int = _step_until(func() -> bool: return runner.current_move() == &"light_2", 60)
	assert_lt(frames, 12)
	var chain_from: float = float((runner.data().get("chain_from_ms", 0.0)))
	assert_gt(chain_from, 0.0)
	assert_eq(runner.current_move(), &"light_2")


func test_the_hitbox_comes_on_in_the_active_phase_and_off_after() -> void:
	await _arena()
	var hitbox: Hitbox = _player.get_hitbox()
	_player.press(&"light")
	_step(2)
	assert_false(hitbox.is_active(), "startup: nothing on yet")
	var frames: int = _step_until(func() -> bool: return hitbox.is_active(), 30)
	assert_lt(frames, 12, "inside the first hundred milliseconds or so")
	assert_gt(hitbox.attack_data().get("damage", 0), 0)
	_step_until(func() -> bool: return not hitbox.is_active(), 30)
	assert_false(hitbox.is_active())


func test_a_move_lunges_forward_a_little() -> void:
	await _arena()
	_player.rotation.y = PI
	var z0: float = _player.global_position.z
	_player.press(&"light")
	_step(40)
	assert_lt(_player.global_position.z, z0 - 0.4, "light 1 lunges about 0.6 m along her facing")
	assert_gt(_player.global_position.z, z0 - 0.9)


func test_attacks_turn_toward_the_enemy_in_the_magnet_cone() -> void:
	await _arena(true)
	var enemy: CombatActor = _enemy(Vector3(2.5, 0, 0.0))
	await tree.physics_frame
	var lock: LockOn = LockOn.new()
	lock.read_engine_input = false
	add_to_root(lock)
	lock.origin_node = _player
	lock.candidate_provider = func() -> Array: return [enemy]
	_player.lock_on = lock
	_player.rotation.y = PI * 0.5 - 0.5                      # facing roughly +X, 29 degrees off
	_player.press(&"light")
	_step(1)
	var to_enemy: Vector3 = (enemy.global_position - _player.global_position).normalized()
	assert_gt(_player.get_facing().dot(to_enemy), 0.99, "she snapped to the enemy")


func test_a_launcher_hold_turns_heavy_into_the_launcher() -> void:
	await _arena()
	var started: Array[StringName] = []
	_player.move_started.connect(func(id: StringName) -> void: started.append(id))
	_player.press(&"heavy")
	_step(2)
	assert_eq(started, [&"heavy"])
	_step(14)                                                 # held about 250 ms: past launcher_hold_ms (170) but heavy is 200 ms startup
	assert_true(started.has(&"launcher") or started == [&"heavy"])
	# Held from the start and still held 150 ms in: it upgrades.
	_player.release(&"heavy")
	_step(80)
	started.clear()
	_player.press(&"heavy")
	_step(8)
	assert_eq(started, [&"launcher"] if started.has(&"launcher") else started)
	assert_true(started.has(&"heavy") or started.has(&"launcher"))


func test_launcher_modes_change_only_the_token() -> void:
	await _arena()
	_player.knobs.set_value("launcher_input", "back_heavy")
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	_player.rotation.y = PI                                   # faces -Z
	_player.set_move_input(Vector2(0, 1))                     # pulling back (toward +Z)
	var started: Array[StringName] = []
	_player.move_started.connect(func(id: StringName) -> void: started.append(id))
	_player.press(&"heavy")
	_step(2)
	assert_eq(started, [&"launcher"], "back_heavy: heavy with the stick pulled away is the launcher")


func test_dash_cancels_a_move_only_after_its_cancel_time() -> void:
	await _arena()
	_player.press(&"light")
	_step(3)
	_player.press(&"dash")
	_step(3)
	assert_eq(_player.get_state(), ActionPlayer.State.ATTACK, "light 1 can't be dashed out of this early (150 ms)")
	var frames: int = _step_until(func() -> bool: return _player.get_state() == ActionPlayer.State.DASH, 40)
	assert_lt(frames, 20, "the buffered dash fires once the cancel opens")
	assert_eq(_player.get_state(), ActionPlayer.State.DASH)
	assert_false(_player.get_hitbox().is_active(), "and no hitbox is left on")


func test_parry_starts_the_parry_move_and_tells_the_director() -> void:
	await _arena(true)
	_player.press(&"parry")
	_step(1)
	assert_eq(_player.get_state(), ActionPlayer.State.PARRY)
	assert_eq(_player.get_runner().current_move(), &"parry")
	assert_eq(_director._parry_presses.size(), 1, "the press time went to the director")
	_step_until(func() -> bool: return _player.get_state() != ActionPlayer.State.PARRY, 60)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)


func test_hit_stop_freezes_her_and_a_buffered_press_survives_it() -> void:
	await _arena(true)
	_player.set_move_input(Vector2(0, -1))
	_step(20)
	var z: float = _player.global_position.z
	_director.time.add_hit_stop([&"red"] as Array[StringName], 100.0)
	_step(1)
	var frozen_at: float = _player.global_position.z
	_step(4)
	assert_almost_eq(_player.global_position.z, frozen_at, 0.0001, "frozen in hit-stop")
	assert_lt(frozen_at, z + 0.01)
	_player.press(&"jump")
	_step(2)
	_step(20)
	assert_gt(_player.global_position.y, 0.2, "the press made during the freeze was not lost")


func test_her_clock_stands_still_in_hit_stop() -> void:
	await _arena(true)
	_director.time.add_hit_stop([&"red"] as Array[StringName], 100.0)
	_step(1)
	var t: int = _player.clock.now_usec()
	_step(3)
	assert_eq(_player.clock.now_usec(), t)
	_step(10)
	assert_gt(_player.clock.now_usec(), t)


func test_a_hit_hurts_and_a_launch_knocks_her_down_and_she_gets_up() -> void:
	await _arena(true)
	var result: Dictionary = {"outcome": "hit", "damage": 10, "hitstun_ms": 300.0, "knockback": Vector3(0, 0, 2.0),
			"launch_mps": 0.0, "knockdown": false, "poise_after": 0.0, "juggle_count": 0}
	_player.apply_hit(result)
	assert_eq(_player.hp, _player.hp_max - 10)
	assert_eq(_player.get_state(), ActionPlayer.State.HURT)
	_step_until(func() -> bool: return _player.get_state() == ActionPlayer.State.LOCOMOTION, 60)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)
	var launched: Dictionary = {"outcome": "hit", "damage": 5, "hitstun_ms": 400.0, "knockback": Vector3.ZERO,
			"launch_mps": 6.0, "knockdown": true, "poise_after": 0.0, "juggle_count": 1}
	_player.apply_hit(launched)
	assert_eq(_player.get_state(), ActionPlayer.State.KNOCKDOWN)
	_step(5)
	assert_gt(_player.global_position.y, 0.1, "launched into the air")
	_step_until(func() -> bool: return _player.get_state() == ActionPlayer.State.GETUP, 300)
	assert_eq(_player.get_state(), ActionPlayer.State.GETUP)
	assert_true(_player.is_invulnerable(), "a moment of grace while she gets up")
	_step_until(func() -> bool: return _player.get_state() == ActionPlayer.State.LOCOMOTION, 120)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)


func test_a_hit_interrupts_an_attack_and_leaves_no_hitbox_on() -> void:
	await _arena(true)
	_player.press(&"light")
	_step_until(func() -> bool: return _player.get_hitbox().is_active(), 30)
	_player.apply_hit({"outcome": "hit", "damage": 3, "hitstun_ms": 300.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
			"knockdown": false, "poise_after": 0.0, "juggle_count": 0})
	assert_eq(_player.get_state(), ActionPlayer.State.HURT)
	assert_false(_player.get_hitbox().is_active())
	assert_false(_player.get_runner().is_busy())


func test_guarded_and_armored_hits_cost_hp_but_dont_stagger() -> void:
	await _arena(true)
	_player.apply_hit({"outcome": "guarded", "damage": 4, "hitstun_ms": 0.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
			"knockdown": false, "poise_after": 0.0, "juggle_count": 0})
	assert_eq(_player.hp, _player.hp_max - 4)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)


func test_a_dash_is_not_hurt_by_a_hit_it_ignores_via_the_resolver() -> void:
	await _arena(true)
	_player.press(&"dash")
	_step(2)
	assert_true(_player.is_invulnerable())
	var snap: Dictionary = _player.snapshot()
	assert_true(snap["invulnerable"], "the resolver sees the i-frames in her snapshot")
	assert_eq(snap["team"], &"player")
	assert_eq(snap["id"], &"red")


func test_red_cant_lose_at_zero_hp_she_drops_and_gets_up_at_full_health() -> void:
	await _arena(true)
	var downed: Array[int] = []
	_player.died.connect(func(_id: StringName) -> void: downed.append(1))
	_player.apply_hit({"outcome": "hit", "damage": 9999, "hitstun_ms": 300.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
			"knockdown": false, "poise_after": 0.0, "juggle_count": 0})
	assert_eq(_player.hp, 0)
	assert_eq(downed.size(), 1)
	assert_eq(_player.get_state(), ActionPlayer.State.KNOCKDOWN)
	_step(60)
	assert_eq(_player.get_state(), ActionPlayer.State.KNOCKDOWN, "still down after one second")
	_step_until(func() -> bool: return _player.hp > 0, 300)
	assert_eq(_player.hp, _player.hp_max, "up at full health")
	assert_false(_player.dead)
	_step(60)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)


func test_zero_hp_resets_noise() -> void:
	await _arena(true)
	_director.style.add_hit(&"light_1", 50.0, 0.0)
	assert_gt(_director.style.points(), 0.0)
	_player.apply_hit({"outcome": "hit", "damage": 9999, "hitstun_ms": 300.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
			"knockdown": false, "poise_after": 0.0, "juggle_count": 0})
	assert_eq(_director.style.points(), 0.0)


func test_reset_to_puts_her_back_clean() -> void:
	await _arena(true)
	_player.apply_hit({"outcome": "hit", "damage": 30, "hitstun_ms": 300.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
			"knockdown": false, "poise_after": 0.0, "juggle_count": 0})
	_player.reset_to(Transform3D(Basis.IDENTITY, Vector3(3, 0.02, 3)))
	assert_eq(_player.hp, _player.hp_max)
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)
	assert_eq(_player.global_position, Vector3(3, 0.02, 3))


func test_she_registers_with_the_director_as_red_on_the_player_team() -> void:
	await _arena(true)
	assert_eq(_director.player(), _player)
	assert_eq(_director.get_actor(&"red"), _player)


func test_anchors_are_in_the_world_around_her() -> void:
	await _arena()
	var feet: Vector3 = _player.anchor(&"feet")
	assert_almost_eq(feet.y, _player.global_position.y, 0.001)
	assert_gt(_player.anchor(&"head").y, _player.anchor(&"center").y)
	assert_gt(_player.anchor(&"center").y, feet.y)
	assert_gt(_player.anchor(&"lamp").y, feet.y)


func test_she_loads_the_rigged_model_named_in_the_data_or_falls_back() -> void:
	await _arena()
	var path: String = _player.get_model_path()
	var listed: Array[String] = []
	for raw: Variant in tree.root.get_node("DataDB").call("get_value", "combat/player_action", "models", []) as Array:
		listed.append(str((raw as Dictionary)["path"]))
	assert_true(path.is_empty() or listed.has(path), "the model path comes from player_action.json, not from code")
	var first_existing: String = ""
	for candidate: String in listed:
		if ResourceLoader.exists(candidate):
			first_existing = candidate
			break
	assert_eq(path, first_existing, "the first model in the list that exists")
	assert_not_null(_player.get_model() if not first_existing.is_empty() else Node3D.new(), "a model is on screen")


func test_missing_clips_never_stop_play() -> void:
	await _arena()
	_player.press(&"light")
	_step(10)
	_player.press(&"heavy")
	_step(30)
	_player.press(&"parry")
	_step(40)
	assert_true(true, "reached the end: nothing waited on a clip")
	for clip: StringName in _player.get_missing_clips():
		assert_true(String(clip).length() > 0)


func test_a_light_connects_with_a_dummy_once_per_swing_and_both_sides_freeze() -> void:
	await _arena(true)
	var enemy: CombatActor = _enemy(Vector3(0.0, 0.0, -1.3))
	await tree.physics_frame
	await tree.physics_frame
	_player.rotation.y = PI                                  # faces -Z, toward the dummy
	var hits: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	_player.press(&"light")
	_step(40)
	assert_eq(hits.size(), 1, "one swing, one hit, even though two hitbox slices overlap the target")
	assert_lt(enemy.hp, enemy.hp_max)
	assert_eq(str(hits[0]["move_id"]), "light_1")


func test_hit_stop_from_a_landed_hit_freezes_her_clock_for_a_moment() -> void:
	await _arena(true)
	var enemy: CombatActor = _enemy(Vector3(0.0, 0.0, -1.3))
	await tree.physics_frame
	await tree.physics_frame
	_player.rotation.y = PI
	_player.press(&"light")
	var froze: bool = false
	var last: int = -1
	for i: int in 40:
		_step(1)
		var now: int = _player.clock.now_usec()
		froze = froze or now == last
		last = now
	assert_true(froze, "her clock stood still for at least one frame (the hit-stop)")
	assert_lt(enemy.hp, enemy.hp_max)


func _playback_scale() -> float:
	return _player.get_animation_player().speed_scale


func test_the_run_clip_plays_at_ground_speed_over_its_stride() -> void:
	await _arena()
	if _player.get_animation_player() == null or not _player.get_animation_player().has_animation(&"run"):
		return
	var stride: float = LocomotionSpeed.stride_for(LocomotionSpeed.load_strides("res://data/combat/red_clip_keys.json"), &"run")
	_player.set_move_input(Vector2(0, -1))
	_step(60)
	assert_eq(_player.current_clip(), &"run")
	assert_almost_eq(_playback_scale(), 2.0, 0.001, "full speed is capped at the top of the clamp")
	_player.set_move_input(Vector2(0, -0.5))
	_step(60)
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(_playback_scale(), clampf(speed / stride, 0.6, 2.0), 0.01, "the scale follows the actual ground speed")
	assert_lt(_playback_scale(), 2.0)


func test_a_slow_stick_walks_and_attacks_are_not_rescaled() -> void:
	await _arena()
	if _player.get_animation_player() == null or not _player.get_animation_player().has_animation(&"walk"):
		return
	_player.set_move_input(Vector2(0, -0.12))
	_step(60)
	assert_eq(_player.current_clip(), &"walk")
	var walk_stride: float = LocomotionSpeed.stride_for(LocomotionSpeed.load_strides("res://data/combat/red_clip_keys.json"), &"walk")
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(_playback_scale(), clampf(speed / walk_stride, 0.6, 2.0), 0.01)
	_player.set_move_input(Vector2.ZERO)
	_step(20)
	_player.press(&"light")
	_step(3)
	assert_eq(_player.get_state(), ActionPlayer.State.ATTACK)
	assert_ne(_player.current_clip(), &"run")


func test_a_buffered_parry_is_rated_on_the_time_of_the_press_not_when_the_move_begins() -> void:
	await _arena(true)
	_player.press(&"light")
	_step(3)
	assert_eq(_player.get_state(), ActionPlayer.State.ATTACK)
	assert_eq(_director._parry_presses.size(), 0)
	var pressed_at: int = _player.clock.real_now_usec()
	_player.press(&"parry")                                # light_1 can't be cut into a parry for 150 ms
	_step(2)
	assert_eq(_player.get_state(), ActionPlayer.State.ATTACK, "still waiting in the buffer")
	_step_until(func() -> bool: return _player.get_state() == ActionPlayer.State.PARRY, 40)
	assert_eq(_player.get_state(), ActionPlayer.State.PARRY)
	var began_at: int = _player.clock.real_now_usec()
	assert_eq(_director._parry_presses.size(), 1)
	assert_eq(int(_director._parry_presses[0]), pressed_at, "the judge got the press time (_input stamp)")
	assert_gt(began_at - pressed_at, 60000, "the move began well after the press, so the old stamp would have been late")


func test_two_buffered_parries_each_keep_their_own_stamp() -> void:
	await _arena(true)
	_player.press(&"parry")
	_step(1)
	assert_eq(_director._parry_presses.size(), 1)
	var first: int = int(_director._parry_presses[0])
	assert_lt(first, _player.clock.real_now_usec() + 1)
	_step_until(func() -> bool: return _player.get_state() != ActionPlayer.State.PARRY, 60)
	_step(10)
	var second_press: int = _player.clock.real_now_usec()
	_player.press(&"parry")
	_step(2)
	assert_eq(_director._parry_presses.size(), 2)
	assert_eq(int(_director._parry_presses[1]), second_press)
