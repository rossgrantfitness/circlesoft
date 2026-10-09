extends TestCase
## The flying Signals drone and the wall turret (VS-18; docs/slice/enemy_roster.md): the drone hovers, dives and sinks, EMP
## drops it and one Zap kills it; the turret never moves, shows a laser, locks its aim and fires three bolts down one line
## that one step sideways beats; both can be hijacked; EMP stuns by tag and Zap does the bonus by tag.

var _kit: HackKit = null


func _setup(attack_enemies: bool = false) -> void:
	_kit = HackKit.new(self)
	await _kit.arena(attack_enemies)
	_kit.director.feel.set_value("enemy_damage_scale", 1.0)
	_kit.director.feel.set_value("enemy_windup_scale", 1.0)


func _centre_height(drone: ActionEnemy) -> float:
	return drone.global_position.y + drone.height_m * 0.5


# ---- data and tags ----

func test_the_designers_tags_are_on_the_four_enemies() -> void:
	var all: Dictionary = (CombatData.enemies()["enemies"] as Dictionary)
	assert_has(all["signals_drone"]["tags"], "drone")
	assert_has(all["wall_turret"]["tags"], "turret")
	assert_has(all["grunt"]["tags"], "cop")
	assert_has(all["brute"]["tags"], "heavy")
	assert_does_not_have(all["grunt"]["tags"], "drone", "cops get no machine tags, so EMP only shoves them")


func test_the_enemies_carry_their_tags_and_are_hijackable() -> void:
	await _setup()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 6))
	var turret: ActionEnemy = _kit.spawn(HackKit.TURRET_SCENE, Vector3(5, 0, 8), PI)
	assert_true(drone is SignalsDrone)
	assert_true(turret is WallTurret)
	assert_has(drone.tags, "drone")
	assert_has(turret.tags, "turret")
	assert_not_null(drone.hijackable)
	assert_not_null(turret.hijackable)
	assert_eq(drone.hp_max, 22)
	assert_eq(turret.hp_max, 80)


# ---- the drone ----

func test_the_drone_hovers_with_its_body_centre_at_the_data_height() -> void:
	await _setup()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 8))
	await _kit.settle()
	await _kit.frames(40)
	assert_almost_eq(_centre_height(drone), 1.7, 0.25, "hover_height_m")
	assert_false(drone.is_airborne(), "hovering is not 'in the air' for juggles")


func test_one_zap_kills_a_drone() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 6))
	await _kit.settle()
	await _kit.frames(30)
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return drone.dead, 120)
	assert_true(drone.dead, "12 doubled by the drone tag is 24 against 22 health")


func test_the_same_zap_does_not_kill_an_untagged_cop() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	var cop: ActionEnemy = _kit.grunt(Vector3(0, 0, 6))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return cop.hp < cop.hp_max, 120)
	assert_eq(cop.hp, cop.hp_max - 12)


func test_emp_drops_a_drone_to_the_floor_for_three_seconds() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 3))
	await _kit.settle()
	await _kit.frames(40)
	assert_gt(_centre_height(drone), 1.3, "up in the air")
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_eq(drone.body_state, ActionEnemy.ST_STAGGER, "knocked out")
	assert_lt(_centre_height(drone), 0.7, "and fallen to the floor")
	await _kit.frames(60 * 2)
	assert_eq(drone.body_state, ActionEnemy.ST_STAGGER, "still out after 3 s in all")
	await _kit.frames(60 * 2)
	assert_eq(drone.body_state, ActionEnemy.ST_FREE)
	await _kit.frames(60)
	assert_gt(_centre_height(drone), 1.3, "and it climbs back up")


func test_the_drone_dives_at_red_then_sinks_low() -> void:
	await _setup(true)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 5))
	await _kit.settle()
	var lowest_dive: float = 9.0
	var low_in_recovery: float = 9.0
	var dived: bool = false
	for i: int in range(60 * 14):
		await _kit.frames(1)
		if drone.runner.is_busy() and drone.runner.current_move() == &"dive":
			dived = true
			if drone.runner.phase() == MoveRunner.PHASE_ACTIVE:
				lowest_dive = minf(lowest_dive, _centre_height(drone))
			elif drone.runner.phase() == MoveRunner.PHASE_RECOVERY:
				low_in_recovery = minf(low_in_recovery, _centre_height(drone))
		if dived and low_in_recovery < 0.8 and _kit.hits_from("sword").size() + _kit.hits.size() > 0:
			break
	assert_true(dived, "it dived")
	assert_lt(lowest_dive, 1.0, "it came down to Red's height for the dive")
	assert_lt(low_in_recovery, 0.8, "and sat low for the recovery: free hits")


func test_a_dive_hurts_for_seven_and_a_sidestep_beats_it() -> void:
	await _setup(true)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 5))
	await _kit.settle()
	await _kit.until(func() -> bool: return not _kit.hits.is_empty(), 60 * 16)
	if _kit.hits.is_empty():
		fail("the drone never connected in 16 s")
		return
	assert_eq(_kit.hits[0]["attacker"], drone.actor_id)
	assert_true([7, 5].has(int(_kit.hits[0]["damage"])), "7 for the dive, 5 for the shock ring")
	assert_eq(_kit.red.hp, 120 - int(_kit.hits[0]["damage"]))


func test_a_hijacked_drone_dives_at_the_other_enemy() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(2)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 4))
	var victim: ActionEnemy = (load(HackKit.GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	victim.position = Vector3(4, 0, 6)
	add_to_root(victim)
	victim.set_physics_process(false)
	await _kit.settle()
	await _kit.frames(30)
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return drone.hijacked_by != null, 60)
	assert_not_null(drone.hijacked_by, "Overclock took the drone")
	await _kit.until(func() -> bool: return victim.hp < victim.hp_max, 60 * 9)
	assert_lt(victim.hp, victim.hp_max, "and it dived at the cop for Red")


# ---- the turret ----

func _turret_facing_red(distance: float = 10.0) -> ActionEnemy:
	return _kit.spawn(HackKit.TURRET_SCENE, Vector3(0, 0, distance), PI)


func test_a_turret_never_moves_even_when_hit() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	var turret: ActionEnemy = _turret_facing_red(6.0)
	await _kit.settle()
	var home: Vector3 = turret.global_position
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_lt(turret.hp, turret.hp_max, "the zap hit it (x1.5 for the turret tag = 18)")
	assert_eq(turret.hp, turret.hp_max - 18)
	assert_almost_eq(turret.global_position.distance_to(home), 0.0, 0.01)


func test_a_burst_shows_a_laser_locks_its_aim_and_fires_three_bolts() -> void:
	await _setup(true)
	var turret: WallTurret = _turret_facing_red(10.0) as WallTurret
	await _kit.settle()
	var seen_laser: bool = false
	var locked_at: float = -1.0
	var first_bolt_at: float = -1.0
	var laser_before_lock: bool = false
	for i: int in range(60 * 12):
		await _kit.frames(1)
		if turret.runner.is_busy() and turret.runner.current_move() == &"burst":
			var ms: float = turret.runner.elapsed_ms()
			if turret.laser_visible():
				seen_laser = true
				if ms < 600.0 and not turret.aim_locked():
					laser_before_lock = true
			if turret.aim_locked() and locked_at < 0.0:
				locked_at = ms
		if first_bolt_at < 0.0 and not _kit.hits.is_empty():
			first_bolt_at = turret.runner.elapsed_ms()
		if _kit.hits.size() >= 3 and not turret.runner.is_busy():
			break
	assert_true(seen_laser, "the laser showed")
	assert_true(laser_before_lock, "from the first frames of the wind-up, before the aim locked")
	assert_gt(locked_at, 300.0)
	assert_lt(locked_at, 1000.0, "the aim locked before the first bolt (1000 ms)")
	assert_eq(_kit.hits.size(), 3, "three bolts down one line")
	for info: Dictionary in _kit.hits:
		assert_eq(info["attacker"], turret.actor_id)
		assert_eq(int(info["damage"]), 7)
	assert_eq(_kit.red.hp, 120 - 21, "21 if she stands in the line for all three")


func test_one_step_sideways_after_the_lock_beats_all_three_bolts() -> void:
	await _setup(true)
	var turret: WallTurret = _turret_facing_red(10.0) as WallTurret
	await _kit.settle()
	await _kit.until(func() -> bool: return turret.aim_locked(), 60 * 12)
	assert_true(turret.aim_locked(), "it locked")
	_kit.red.global_position += Vector3(3.0, 0, 0)
	await _kit.frames(60 * 3)
	assert_eq(_kit.hits.size(), 0, "the bolts went down the old line")
	assert_eq(_kit.red.hp, 120)


func test_the_turret_stays_inside_its_arc() -> void:
	await _setup(true)
	var turret: ActionEnemy = _turret_facing_red(10.0)
	await _kit.settle()
	_kit.red.global_position = Vector3(0, 0.02, 20.0)          # behind the mount
	await _kit.frames(120)
	var off: float = absf(wrapf(turret.rotation.y - turret.spawn_yaw, -PI, PI))
	assert_le(rad_to_deg(off), 80.5, "160 degrees of arc, 80 each side")


func test_emp_switches_a_turret_off_for_four_seconds() -> void:
	await _setup(true)
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var turret: ActionEnemy = _turret_facing_red(3.5)
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(60 * 3)
	assert_eq(turret.body_state, ActionEnemy.ST_STAGGER, "off")
	assert_eq(_kit.hits_from("sword").size() + _kit.hits.size() - _kit.hits_from("hack").size(), 0, "and it fired nothing")
	await _kit.frames(60 * 2)
	assert_eq(turret.body_state, ActionEnemy.ST_FREE, "back on after 4 s")


func test_two_zaps_break_a_turrets_poise_and_stun_it() -> void:
	await _setup()
	_kit.battery().reset_full()
	var turret: ActionEnemy = _turret_facing_red(6.0)
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(50)
	assert_ne(turret.body_state, ActionEnemy.ST_STAGGER, "one zap is not enough")
	await _kit.tap_hack()
	await _kit.frames(50)
	assert_eq(turret.body_state, ActionEnemy.ST_STAGGER, "the second breaks its poise")


func test_a_hijacked_turret_fires_for_red_about_every_second_and_a_half() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(2)
	var turret: ActionEnemy = _turret_facing_red(9.0)
	var victim: ActionEnemy = (load(HackKit.GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	victim.position = Vector3(2.0, 0, 3.0)         # in front of the turret, inside its arc
	victim.hp = 400
	victim.hp_max = 400
	add_to_root(victim)
	victim.set_physics_process(false)
	await _kit.settle()
	_kit.red.rotation.y = 0.0
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return turret.hijacked_by != null, 60)
	assert_not_null(turret.hijacked_by)
	await _kit.frames(60 * 6)
	var ally_hits: Array[Dictionary] = _kit.hits_from("hijacked")
	print("      [drone/turret] a hijacked turret landed %d bolts in 6 s" % ally_hits.size())
	assert_ge(float(ally_hits.size()), 6.0, "two or more bursts of three in six seconds")
	assert_lt(victim.hp, 400 - 6 * 7 + 1)
	assert_eq(_kit.red.hp, 120, "and none at Red")


func test_a_hijacked_turret_prefers_the_priority_tag() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(2)
	_kit.director.hijack_priority_tags = ["relay"] as Array[String]
	var turret: ActionEnemy = _turret_facing_red(5.0)
	var near: ActionEnemy = _kit.grunt(Vector3(3, 0, 6))
	var relay: ActionEnemy = _kit.grunt(Vector3(-9, 0, 12), ["relay"])
	near.set_physics_process(false)
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return turret.hijacked_by != null, 60)
	assert_eq(turret._target(), relay, "the relay, though the other cop is nearer")
	_kit.director.hijack_priority_tags = [] as Array[String]
	assert_eq(turret._target(), near, "without the priority it is just the nearest")
