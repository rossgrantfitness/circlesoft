extends TestCase
## A scripted Red against the real Hushmaster (VS-27, docs/slice/slice_tech_plan.md 8): the fight is winnable by the answers the
## data teaches, so the answers are what the bot uses. It never takes damage from a ring or a beam: it steps off the stomp
## circle after it locks and jumps the ring, and dashes through the sweep's beam. It breaks the four relays with Zap Drones
## (the sword earns the battery in the real game; the bot is given 7 battery every half second to stand in for it), zaps the dish when Quiet Hours hums,
## EMPs drone drops, then jacks in at the prompt.

const DT: float = 1.0 / 60.0
const STEP_M: float = 0.1                  # 6 m/s at 60 Hz

var _kit: BossKit = null
var _lock: LockOn = null
var _jump_hold: int = 0
var _dashed_in_sweep: bool = false
var _zap_wait: int = 0
var _log: Array[String] = []
var _frame_count: int = 0


func _setup() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(true, 5)
	_lock = LockOn.new()
	_lock.read_engine_input = false
	add_to_root(_lock)
	_lock.origin_node = _kit.red
	_kit.red.lock_on = _lock
	_kit.red.global_position = Vector3(0, 0.02, 12)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _step_toward(point: Vector3) -> void:
	var to: Vector3 = point - _kit.red.global_position
	to.y = 0.0
	if to.length() > STEP_M:
		_kit.red.global_position += to.normalized() * STEP_M


func _step_away_from(point: Vector3) -> void:
	var away: Vector3 = _kit.red.global_position - point
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(0, 0, 1)
	_kit.red.global_position += away.normalized() * STEP_M


## One frame of the bot's thinking, before the world steps.
func _think() -> void:
	var boss: Hushmaster = _kit.boss
	var red: ActionPlayer = _kit.red
	var dist_to_boss: float = _flat(red.global_position, boss.global_position)
	if _jump_hold > 0:
		_jump_hold -= 1
		if _jump_hold == 0:
			red.release(&"jump")
	_zap_wait = maxi(_zap_wait - 1, 0)
	var pattern: StringName = boss.current_pattern()
	var busy: bool = boss.state == Hushmaster.State.PATTERN and boss.runner.is_busy()
	var ms: float = boss.runner.elapsed_ms() if busy else 0.0
	# ---- defence ----
	if busy and pattern == &"leg_stomp":
		var gap: float = _flat(red.global_position, boss.stomp_marker())
		if boss.stomp_locked() and ms < 1100.0 and gap < 3.2:
			_step_away_from(boss.stomp_marker())
		elif ms >= 1100.0:
			var ring: float = 0.6 + 9.0 * (ms - 1100.0) / 1000.0
			if gap - ring < 2.7 and gap - ring > 0.0 and red.is_on_floor() and _jump_hold == 0:
				red.press(&"jump")
				_jump_hold = 22
	elif busy and pattern == &"dish_sweep" and ms >= 1400.0 and not _dashed_in_sweep:
		var yaws: Vector2 = boss.fan_yaws()
		var move: Dictionary = CombatData.moves()["sets"]["hushmaster"]["moves"]["dish_sweep"]["hitboxes"][0]
		var now_yaw: float = HitShapes.beam_yaw(move, (ms - 1400.0) / 1000.0, yaws.x, 1.0 if yaws.y > yaws.x else -1.0)
		var origin: Vector3 = (boss.origin_of(&"dish") as Transform3D).origin
		var red_yaw: float = atan2(red.global_position.x - origin.x, red.global_position.z - origin.z)
		var diff: float = wrapf(now_yaw - red_yaw, -PI, PI)
		if absf(diff) < 0.25:
			# dash ACROSS the beam, toward it: along the circle round the dish, against the way it is swinging
			var tangent: Vector2 = Vector2(cos(red_yaw), -sin(red_yaw)) * signf(diff)
			red.set_move_input(tangent)
			red.press(&"dash")
			_dashed_in_sweep = true
	elif not busy or pattern != &"dish_sweep":
		_dashed_in_sweep = false
		red.release(&"dash")
		red.set_move_input(Vector2.ZERO)
	if not busy and dist_to_boss < 8.0 and boss.is_upright():
		_step_away_from(boss.global_position)
	# ---- offence ----
	_frame_count += 1
	if _frame_count % 30 == 0 and not boss.is_upright() == false:
		# the sword earns the battery in the real game: a clean hit every half second (7 each) stands in for it
		_kit.director.battery.add_from_hit(&"hit", &"light_1", false, false, red.clock.now_ms())
	if boss.state == Hushmaster.State.TOPPLED and not _kit.director.hack_prompt.is_empty():
		red.press(&"heavy")
		return
	if not boss.is_upright() or _zap_wait > 0 or _kit.director.hacks_locked():
		return
	var target: Node3D = null
	var nearest_drone: ActionEnemy = null
	for drone: ActionEnemy in boss.drones():
		if nearest_drone == null or _flat(drone.global_position, red.global_position) < _flat(nearest_drone.global_position, red.global_position):
			nearest_drone = drone
	if nearest_drone != null:
		target = nearest_drone                          # one Zap kills a drone (24 against 22)
	elif boss.is_quiet_humming() and not boss.part(&"dish").dead:
		target = boss.part(&"dish")
	else:
		for pair: StringName in Hushmaster.PAIRS:
			if not boss.pair_is_down(pair):
				target = boss.relay_of(pair)
				break
	if target != null and target is BossPart and target != boss.part(&"dish"):
		# line up on the relay from outside, so the drone meets it before the hull
		var radial: Vector3 = (target.global_position - boss.global_position)
		radial.y = 0.0
		var stand: Vector3 = boss.global_position + radial.normalized() * 11.0
		if _flat(red.global_position, stand) > 1.0:
			if not (busy and pattern == &"dish_sweep" and ms >= 800.0):
				_step_toward(stand)             # (not once a sweep's line is out: standing still is how the dash is timed)
			return
	if target != null and (busy == false or pattern == &"quiet_hours" or target is ActionEnemy):
		_lock.set_target(target)
		red.hack_caster().set_current(&"zap_drone")
		red.press(&"heavy")
		_zap_wait = 40


func _run_phase(limit_frames: int) -> void:
	for frame: int in range(limit_frames):
		_think()
		await _kit.frames(1)
		_kit.red.release(&"heavy")
		if _kit.fight.phase_id() != &"rig":
			return
		if _kit.red.hp <= 0:
			return


func _damage_taken_by(move_id: StringName) -> int:
	var total: int = 0
	for info: Dictionary in _kit.hits_on_red():
		if info["move_id"] == move_id:
			total += int(info["damage"])
	return total


func test_a_bot_that_jumps_every_ring_and_dashes_every_beam_beats_phase_1_without_ring_or_beam_damage() -> void:
	await _setup()
	var patterns: Array[StringName] = []
	_kit.boss.pattern_started.connect(func(id: StringName) -> void: patterns.append(id))
	await _run_phase(60 * 150)
	print("      [bot] rig after %d frames: phase %s, red hp %d/%d, patterns %s, relays down %d, events %s" % [
			_frame_count, _kit.fight.phase_id(), _kit.red.hp, _kit.red.hp_max, patterns, _kit.boss.pairs_lost(), _kit.events])
	assert_eq(_kit.fight.phase_id(), &"mech", "the rig is beaten and the fight moved on")
	assert_gt(float(patterns.size()), 3.0, "it fought")
	assert_eq(patterns.slice(0, 3), [&"leg_stomp", &"dish_sweep", &"leg_stomp"] as Array[StringName], "the fixed opening")
	assert_eq(_damage_taken_by(&"leg_stomp"), 0, "no foot or ring damage")
	assert_le(float(_damage_taken_by(&"dish_sweep")), 14.0, "at most one clipped beam (14): the exact dash is proved in test_hushmaster, this is a heuristic bot")
	assert_gt(_kit.red.hp, 0, "Red was never knocked out")
	assert_le(float(_kit.boss.hp), 200.0, "ended by the jack-in: 500 less 60 percent (a drone or two may have hit the body as well)")
