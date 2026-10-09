extends TestCase
## The Hushmaster, phase 1 of Kasp's fight (VS-27; docs/slice/boss_design.md): it walks, runs the four patterns from the data
## with the readable tells and fair answers (jump the ring, leave or dash the beam), is taken apart with hacks (relays on the
## leg pairs, the dish), topples, and ends with the jack-in. Built in a flat arena with the named markers.

var _kit: BossKit = null


func _setup(start_fight: bool = true, rng_seed: int = 3) -> void:
	_kit = BossKit.new(self)
	await _kit.arena(start_fight, rng_seed)


# ---- the fight starts ----

func test_the_fight_builds_the_hushmaster_its_parts_and_the_three_turrets() -> void:
	await _setup()
	assert_not_null(_kit.boss, "the Hushmaster")
	assert_eq(_kit.boss.hp_max, 500)
	assert_eq(_kit.boss.parts().size(), 5, "four relays and the dish")
	for pair: StringName in Hushmaster.PAIRS:
		assert_not_null(_kit.boss.relay_of(pair), "relay_%s" % pair)
	assert_not_null(_kit.boss.part(&"dish"))
	assert_eq(_kit.fight.turrets.size(), 3)
	assert_eq(_kit.fight.phase_id(), &"rig")
	assert_has(_kit.boss.tags(), "boss")


func test_a_new_fight_tops_the_battery_up_to_60_and_sets_the_phase_1_retry_point() -> void:
	await _setup(false)
	_kit.director.battery.set_charge(10.0)
	await _kit.begin()
	assert_eq(_kit.director.battery.charge(), 60.0, "the first relay is a few Zaps away")
	assert_eq(_kit.room.checkpoints.size(), 1)
	assert_eq(_kit.room.checkpoints[0], {"spawn": "retry_phase1", "form": &"red", "full_health": false})


func test_a_fuller_battery_is_left_alone() -> void:
	await _setup(false)
	_kit.director.battery.set_charge(90.0)
	await _kit.begin()
	assert_eq(_kit.director.battery.charge(), 90.0)


func test_a_retry_resumes_the_rig_without_the_intro_bark() -> void:
	await _setup(false)
	await _kit.begin(3, "retry_phase1")
	assert_does_not_have(_kit.events, &"kasp_rig_intro")
	assert_eq(_kit.fight.phase_id(), &"rig")
	var fresh: BossKit = BossKit.new(self)
	await fresh.arena(true)
	assert_has(fresh.events, &"kasp_rig_intro")


func test_the_boss_bar_is_announced_with_both_fighting_phases() -> void:
	await _setup(false)
	var shown: Array[Dictionary] = []
	_kit.director.boss_bar_shown.connect(func(info: Dictionary) -> void: shown.append(info))
	await _kit.begin()
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["hp_max"], 500.0)
	assert_eq(shown[0]["phases"].size(), 2, "the rig and the Heap; the transition has no bar")
	assert_eq(shown[0]["phase"], 0)


func test_the_boss_bar_follows_the_bodys_health() -> void:
	await _setup()
	var seen: Array[float] = []
	_kit.fight.boss_hp_changed.connect(func(hp: float, _max: float) -> void: seen.append(hp))
	_kit.boss.apply_hit({"damage": 100, "source": "hack", "outcome": &"hit"})
	_kit.director.hp_changed.emit(_kit.boss.actor_id, _kit.boss.hp, _kit.boss.hp_max)
	assert_eq(seen, [400.0] as Array[float])


# ---- the sword and the body ----

func test_the_sword_does_thirty_percent_to_the_standing_walker_but_still_hits() -> void:
	await _setup()
	var result: Dictionary = {"damage": 10, "source": "sword", "outcome": &"hit"}
	_kit.boss.apply_hit(result)
	assert_eq(result["damage"], 3)
	assert_eq(_kit.boss.hp, 497)


func test_a_hack_hit_on_the_body_is_not_reduced() -> void:
	await _setup()
	var result: Dictionary = {"damage": 12, "source": "hack", "outcome": &"hit"}
	_kit.boss.apply_hit(result)
	assert_eq(result["damage"], 12)


func test_the_sword_only_clinks_off_a_relay() -> void:
	await _setup()
	var relay: BossPart = _kit.boss.relay_of(&"fl")
	var clinks: Array[String] = []
	relay.clinked.connect(func(_id: StringName, source: String) -> void: clinks.append(source))
	var result: Dictionary = {"damage": 8, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	relay.apply_hit(result)
	assert_eq(result["damage"], 0)
	assert_eq(relay.hp, 72)
	assert_eq(clinks, ["sword"])


func test_a_zap_hurts_a_relay_triple_and_two_break_it() -> void:
	await _setup()
	_kit.director.battery.set_charge(100.0)
	_kit.red.global_position = Vector3(0, 0.02, 14)
	var relay: BossPart = _kit.boss.relay_of(&"fl")
	var lock: LockOn = LockOn.new()
	lock.read_engine_input = false
	add_child_to_test(lock)
	lock.origin_node = _kit.red
	_kit.red.lock_on = lock
	lock.set_target(relay)
	_kit.red.rotation.y = PI
	for shot: int in range(2):
		_kit.red.press(&"heavy")
		await _kit.frames(1)
		_kit.red.release(&"heavy")
		await _kit.until(func() -> bool: return relay.hp < 72 - shot * 36 or relay.dead, 200)
		await _kit.frames(40)
	assert_true(relay.dead, "two Zaps of 12 x3 = 72")
	assert_true(_kit.boss.pair_is_down(&"fl"))


func add_child_to_test(node: Node) -> void:
	add_to_root(node)


# ---- legs ----

func test_a_broken_relay_folds_its_pair_and_the_next_attack_waits() -> void:
	await _setup()
	var dropped: Array[StringName] = []
	_kit.boss.pair_dropped.connect(func(pair: StringName, _lost: int) -> void: dropped.append(pair))
	await _kit.frames(30)
	_kit.break_pair(&"fr")
	assert_eq(dropped, [&"fr"] as Array[StringName])
	assert_eq(_kit.boss.pairs_lost(), 1)
	assert_eq(_kit.boss.pairs_standing(), 3)
	assert_eq(_kit.boss.state, Hushmaster.State.REACT, "no attack can start for 1.4 s")
	assert_gt(_kit.boss.brain.next_ok_ms(), _kit.boss.clock.now_ms() + 1300.0)
	assert_has(_kit.events, &"kasp_rig_relay_1")


func test_leg_stomp_never_uses_a_fallen_leg() -> void:
	await _setup()
	_kit.break_pair(&"fl")
	_kit.break_pair(&"bl")
	_kit.break_pair(&"br")
	for i: int in range(6):
		var leg: Dictionary = _kit.boss._nearest_standing_leg(Vector3(5, 0, 5))
		assert_eq(leg["pair"], &"fr", "only the front right pair still stands")


func test_the_pairs_lost_barks_fire_at_two_and_three() -> void:
	await _setup()
	_kit.break_pair(&"fl")
	_kit.break_pair(&"fr")
	assert_has(_kit.events, &"kasp_rig_pairs_2")
	_kit.break_pair(&"bl")
	assert_has(_kit.events, &"kasp_rig_pairs_3")


# ---- Leg Stomp ----

func _run_stomp(red_at: Vector3) -> void:
	_kit.place_red(red_at)
	assert_true(_kit.boss.force_pattern(&"leg_stomp"))


func test_the_stomp_circle_follows_red_then_locks_and_the_foot_hurts_inside_it() -> void:
	await _setup()
	_run_stomp(Vector3(0, 0.02, 4))
	await _kit.frames(20)
	var first: Vector3 = _kit.boss.stomp_marker()
	assert_almost_eq(first.z, 4.0, 0.2, "the circle is on Red")
	assert_false(_kit.boss.stomp_locked())
	_kit.place_red(Vector3(3, 0.02, 4))
	await _kit.frames(10)
	assert_almost_eq(_kit.boss.stomp_marker().x, 3.0, 0.3, "and follows her")
	await _kit.until(func() -> bool: return _kit.boss.stomp_locked(), 120)
	var locked_at: Vector3 = _kit.boss.stomp_marker()
	assert_true(_kit.boss.runner.elapsed_ms() >= 670.0 and _kit.boss.runner.elapsed_ms() < 720.0, "it locks 420 ms before the 1100 ms impact")
	await _kit.frames(30)
	assert_eq(_kit.boss.stomp_marker(), locked_at, "and stays where it locked")
	await _kit.until(func() -> bool: return not _kit.hits_on_red().is_empty(), 120)
	assert_eq(_kit.hits_on_red().size(), 1, "standing in the circle: one hit")
	assert_eq(int(_kit.hits_on_red()[0]["damage"]), 17, "the foot: 14 x 1.2")


func test_stepping_out_of_the_circle_after_the_lock_beats_the_foot_but_the_ring_follows() -> void:
	await _setup()
	_run_stomp(Vector3(0, 0.02, 6))
	await _kit.until(func() -> bool: return _kit.boss.stomp_locked(), 120)
	_kit.place_red(Vector3(0, 0.02, 10.0))                      # 4 m from the foot, on the floor
	await _kit.frames(90)
	assert_eq(_kit.hits_on_red().size(), 1, "the ring got her, the foot did not")
	assert_eq(int(_kit.hits_on_red()[0]["damage"]), 12, "the ring: 14 x 0.85")


func test_a_jump_clears_the_ring() -> void:
	await _setup()
	_run_stomp(Vector3(0, 0.02, 5))
	await _kit.until(func() -> bool: return _kit.boss.stomp_locked(), 120)
	_kit.place_red(Vector3(0, 0.02, 11.0))                      # 6 m from the foot: the ring takes 0.6 s to arrive
	await _kit.until(func() -> bool: return _kit.boss.runner.elapsed_ms() >= 1400.0, 120)
	_kit.red.press(&"jump")
	await _kit.frames(1)
	_kit.red.release(&"jump")
	await _kit.frames(100)
	assert_eq(_kit.hits_on_red().size(), 0, "she was in the air when the ring went by")


func test_the_stomp_chains_a_second_leg_once_two_pairs_are_down() -> void:
	await _setup()
	_kit.break_pair(&"fl")
	_kit.break_pair(&"bl")
	await _kit.frames(120)
	_run_stomp(Vector3(0, 0.02, 4))
	await _kit.until(func() -> bool: return _kit.boss.state == Hushmaster.State.CHAIN_WAIT, 400)
	assert_eq(_kit.boss.state, Hushmaster.State.CHAIN_WAIT, "between the two stomps")
	await _kit.until(func() -> bool: return _kit.boss.state == Hushmaster.State.PATTERN, 120)
	assert_eq(_kit.boss.state, Hushmaster.State.PATTERN, "and the second one starts")


func test_breaking_the_stomping_legs_relay_before_it_lands_cancels_the_stomp() -> void:
	await _setup()
	_run_stomp(Vector3(0, 0.02, 4))
	await _kit.frames(20)
	var pair: StringName = _kit.boss._stomp_pair
	_kit.break_pair(pair)
	await _kit.frames(5)
	assert_ne(_kit.boss.state, Hushmaster.State.PATTERN, "the leg folded under it")
	await _kit.frames(120)
	assert_eq(_kit.hits_on_red().size(), 0)


# ---- Dish Sweep ----

func test_the_sweep_draws_its_fan_and_hits_someone_standing_in_it() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 12))
	assert_true(_kit.boss.force_pattern(&"dish_sweep"))
	await _kit.frames(30)
	var yaws: Vector2 = _kit.boss.fan_yaws()
	assert_almost_eq(absf(yaws.y - yaws.x), deg_to_rad(80.0), 0.001, "an 80 degree fan")
	await _kit.until(func() -> bool: return not _kit.hits_on_red().is_empty(), 300)
	assert_eq(_kit.hits_on_red().size(), 1, "one hit per sweep")
	assert_eq(int(_kit.hits_on_red()[0]["damage"]), 14)


func test_standing_outside_the_fan_is_safe() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 12))
	assert_true(_kit.boss.force_pattern(&"dish_sweep"))
	await _kit.frames(30)
	_kit.place_red(Vector3(25, 0.02, 12))                       # well off to the side
	await _kit.frames(200)
	assert_eq(_kit.hits_on_red().size(), 0)


func test_a_dash_through_the_beam_beats_it() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 12))
	assert_true(_kit.boss.force_pattern(&"dish_sweep"))
	await _kit.until(func() -> bool: return _kit.boss.runner.elapsed_ms() >= 1400.0, 300)
	var guard: int = 0
	var dashed: bool = false
	while guard < 90 and _kit.hits_on_red().is_empty():
		guard += 1
		var yaws: Vector2 = _kit.boss.fan_yaws()
		var now_yaw: float = HitShapes.beam_yaw(CombatData.moves()["sets"]["hushmaster"]["moves"]["dish_sweep"]["hitboxes"][0], _kit.boss.runner.elapsed_ms() / 1000.0 - 1.4, yaws.x, 1.0 if yaws.y > yaws.x else -1.0)
		var origin: Vector3 = (_kit.boss.origin_of(&"dish") as Transform3D).origin
		var red_yaw: float = atan2(_kit.red.global_position.x - origin.x, _kit.red.global_position.z - origin.z)
		if not dashed and absf(wrapf(red_yaw - now_yaw, -PI, PI)) < 0.12:
			_kit.red.press(&"dash")
			dashed = true
		await _kit.frames(1)
		_kit.red.release(&"dash")
	await _kit.frames(60)
	assert_true(dashed, "she dashed as the beam arrived")
	assert_eq(_kit.hits_on_red().size(), 0, "and the dash's untouchable moment carried her through")


func test_the_dish_comes_down_while_it_recovers() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 12))
	assert_true(_kit.boss.force_pattern(&"dish_sweep"))
	var dish: BossPart = _kit.boss.part(&"dish")
	assert_almost_eq(dish.position.y + dish.height_m * 0.5, 3.4, 0.01, "3.4 m up: out of sword reach")
	await _kit.until(func() -> bool: return _kit.boss.runner.elapsed_ms() >= 2950.0, 500)
	assert_almost_eq(dish.position.y + dish.height_m * 0.5, 2.2, 0.01, "2.2 m during the recovery: jump and sword")


# ---- Drone Drop ----

func test_the_drone_drop_lifts_a_lid_for_a_second_then_three_drones_rise() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 9))
	assert_true(_kit.boss.force_pattern(&"drone_drop"))
	await _kit.frames(30)
	assert_eq(_kit.boss.drones_alive(), 0, "a one-second warning first")
	await _kit.until(func() -> bool: return _kit.boss.drones_alive() > 0, 120)
	assert_eq(_kit.boss.drones_alive(), 3)


func test_four_drones_come_once_two_pairs_are_down() -> void:
	await _setup()
	_kit.break_pair(&"fl")
	_kit.break_pair(&"fr")
	await _kit.frames(120)
	assert_true(_kit.boss.force_pattern(&"drone_drop"))
	await _kit.until(func() -> bool: return _kit.boss.drones_alive() > 0, 200)
	assert_eq(_kit.boss.drones_alive(), 4)


func test_the_hatch_chosen_is_beyond_five_metres_from_red() -> void:
	await _setup()
	_kit.place_red(Vector3(-10, 0.02, -4))                      # close to hatch A
	assert_true(_kit.boss.force_pattern(&"drone_drop"))
	await _kit.frames(5)
	assert_gt(Vector2(_kit.boss._hatch_used.x + 10.0, _kit.boss._hatch_used.z + 4.0).length(), 5.0)


# ---- Quiet Hours ----

func test_quiet_hours_locks_the_hacks_after_the_hum_and_the_dish_comes_down() -> void:
	await _setup()
	var locks: Array[bool] = []
	_kit.director.hack_locked.connect(func(active: bool, _ms: float) -> void: locks.append(active))
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	var dish: BossPart = _kit.boss.part(&"dish")
	await _kit.frames(60)
	assert_false(_kit.director.hacks_locked(), "not yet: 1.4 s of hum")
	assert_true(_kit.boss.is_quiet_humming())
	assert_almost_eq(dish.position.y + dish.height_m * 0.5, 2.2, 0.01)
	await _kit.until(func() -> bool: return _kit.director.hacks_locked(), 120)
	assert_true(_kit.director.hacks_locked())
	assert_eq(locks, [true])
	await _kit.frames(60 * 5 + 20)
	assert_false(_kit.director.hacks_locked(), "5 seconds")
	assert_eq(locks, [true, false])


func test_one_zap_on_the_dish_before_the_lock_cancels_quiet_hours() -> void:
	await _setup()
	var cuts: Array[String] = []
	_kit.boss.quiet_hours_cut.connect(func(by: String) -> void: cuts.append(by))
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	await _kit.frames(30)
	_kit.boss.part(&"dish").apply_hit({"damage": 12, "source": "hack", "outcome": &"hit", "move_id": &"hack_zap"})
	await _kit.frames(120)
	assert_eq(cuts, ["before_lock"])
	assert_false(_kit.director.hacks_locked(), "the lock never landed")


func test_three_sword_hits_on_the_dish_before_the_lock_also_cancel_it() -> void:
	await _setup()
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	await _kit.frames(20)
	for i: int in range(3):
		_kit.boss.part(&"dish").apply_hit({"damage": 8, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	await _kit.frames(120)
	assert_false(_kit.director.hacks_locked())


func test_two_hits_are_not_enough() -> void:
	await _setup()
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	await _kit.frames(20)
	for i: int in range(2):
		_kit.boss.part(&"dish").apply_hit({"damage": 8, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	await _kit.until(func() -> bool: return _kit.director.hacks_locked(), 120)
	assert_true(_kit.director.hacks_locked())


func test_three_hits_during_the_lock_end_it_early() -> void:
	await _setup()
	var cuts: Array[String] = []
	_kit.boss.quiet_hours_cut.connect(func(by: String) -> void: cuts.append(by))
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	await _kit.until(func() -> bool: return _kit.director.hacks_locked(), 150)
	assert_true(_kit.boss.quiet_locked())
	for i: int in range(3):
		_kit.boss.part(&"dish").apply_hit({"damage": 8, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	await _kit.frames(5)
	assert_false(_kit.director.hacks_locked(), "unlocked early")
	assert_eq(cuts, ["during_lock"])


func test_while_the_hacks_are_jammed_no_drone_drop_and_no_second_jam_is_picked() -> void:
	await _setup()
	_kit.director.lock_hacks(20000.0)
	await _kit.frames(2)
	var picked: Dictionary = {}
	for i: int in range(40):
		var pick: Dictionary = _kit.boss.brain.step(1.0e9 + float(i) * 10000.0, _kit.boss._view(_kit.red))
		if not pick.is_empty():
			picked[String(pick["pattern"])] = true
			_kit.boss.brain.finish(1.0e9 + float(i) * 10000.0, 0)
	assert_does_not_have(picked, "drone_drop")
	assert_does_not_have(picked, "quiet_hours")


func test_a_broken_dish_removes_the_sweep_and_quiet_hours_for_good() -> void:
	await _setup()
	var dish: BossPart = _kit.boss.part(&"dish")
	dish.apply_hit({"damage": 999, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	assert_true(dish.dead)
	assert_true(_kit.boss.brain.is_disabled(&"dish_sweep"))
	assert_true(_kit.boss.brain.is_disabled(&"quiet_hours"))
	assert_eq(_kit.boss.state, Hushmaster.State.REACT, "it reels for 1.6 s")


# ---- topple and jack-in ----

func _topple() -> void:
	for pair: StringName in Hushmaster.PAIRS:
		_kit.break_pair(pair)


func test_four_pairs_down_topples_it_drones_switch_off_and_the_sword_hits_full() -> void:
	await _setup()
	_kit.place_red(Vector3(0, 0.02, 9))
	assert_true(_kit.boss.force_pattern(&"drone_drop"))
	await _kit.until(func() -> bool: return _kit.boss.drones_alive() > 0, 200)
	var drones: Array[ActionEnemy] = _kit.boss.drones()
	_topple()
	assert_eq(_kit.boss.state, Hushmaster.State.TOPPLING)
	await _kit.frames(20)
	for drone: ActionEnemy in drones:
		assert_eq(drone.body_state, ActionEnemy.ST_STAGGER, "switched off")
	var result: Dictionary = {"damage": 10, "source": "sword", "outcome": &"hit"}
	_kit.boss.apply_hit(result)
	assert_eq(result["damage"], 10, "full strength now")
	assert_has(_kit.events, &"kasp_rig_topple")


func test_after_2_6_seconds_the_hack_button_offers_jack_in() -> void:
	await _setup()
	var ready: Array[bool] = []
	_kit.boss.jack_in_ready.connect(func() -> void: ready.append(true))
	_topple()
	await _kit.frames(60 * 2)
	assert_true(_kit.director.hack_prompt.is_empty(), "not yet")
	await _kit.frames(60)
	assert_eq(_kit.boss.state, Hushmaster.State.TOPPLED)
	assert_eq(_kit.director.hack_prompt["id"], "jack_in")
	assert_eq(ready.size(), 1)


func test_pressing_the_hack_button_jacks_in_for_sixty_percent_and_ends_the_phase() -> void:
	await _setup()
	var finished: Array[StringName] = []
	_kit.fight.phase_finished.connect(func(id: StringName) -> void: finished.append(id))
	var defeated: Array[StringName] = []
	_kit.boss.defeated.connect(func(reason: StringName) -> void: defeated.append(reason))
	_kit.director.battery.set_charge(100.0)
	_topple()
	await _kit.until(func() -> bool: return not _kit.director.hack_prompt.is_empty(), 400)
	_kit.red.press(&"heavy")
	await _kit.frames(2)
	_kit.red.release(&"heavy")
	assert_eq(_kit.boss.state, Hushmaster.State.JACKING)
	assert_eq(_kit.boss.hp, 200, "500 less 60 percent")
	assert_true(_kit.director.hack_prompt.is_empty(), "the prompt is used up")
	assert_eq(_kit.director.battery.charge(), 100.0, "and the button did not also cast a hack")
	assert_eq(_kit.moves_started_hack(), 0)
	await _kit.until(func() -> bool: return not defeated.is_empty(), 300)
	assert_eq(defeated, [&"jack_in"] as Array[StringName])
	assert_has(finished, &"rig")
	assert_has(_kit.events, &"kasp_rig_jack_in")


func test_beaten_to_zero_while_toppled_ends_the_phase_at_once_with_the_same_beat() -> void:
	await _setup()
	var defeated: Array[StringName] = []
	_kit.boss.defeated.connect(func(reason: StringName) -> void: defeated.append(reason))
	_topple()
	await _kit.until(func() -> bool: return _kit.boss.state == Hushmaster.State.TOPPLED, 400)
	_kit.boss.apply_hit({"damage": 9999, "source": "sword", "outcome": &"hit"})
	assert_eq(_kit.boss.state, Hushmaster.State.JACKING, "no prompt to answer")
	await _kit.until(func() -> bool: return not defeated.is_empty(), 300)
	assert_eq(defeated.size(), 1)


func test_beaten_to_zero_while_upright_topples_first() -> void:
	await _setup()
	_kit.boss.apply_hit({"damage": 9999, "source": "hack", "outcome": &"hit"})
	assert_eq(_kit.boss.state, Hushmaster.State.TOPPLING)


# ---- the pylons ----

func test_the_powered_down_pylons_never_shoot_red() -> void:
	await _setup()
	_kit.place_red(Vector3(-13, 0.02, -6))                       # right in front of turret NW
	await _kit.frames(60 * 8)
	for info: Dictionary in _kit.hits_on_red():
		assert_ne(str(info["attacker"]), "turret_k_nw", "powered down")
	for turret: WallTurret in _kit.fight.turrets:
		assert_false(turret.attacks_allowed)


func test_an_overclocked_pylon_shoots_the_relays_first() -> void:
	await _setup()
	_kit.director.battery.set_charge(100.0)
	_kit.red.global_position = Vector3(-13, 0.02, -6)
	_kit.red.rotation.y = PI
	var turret: WallTurret = _kit.fight.turrets[0]
	turret.rotation.y = 0.0
	turret.spawn_yaw = 0.0
	_kit.caster_select(2)
	_kit.red.press(&"heavy")
	await _kit.frames(1)
	_kit.red.release(&"heavy")
	await _kit.until(func() -> bool: return turret.hijacked_by != null, 120)
	assert_not_null(turret.hijacked_by, "Overclock took the pylon")
	var target: CombatActor = turret._target()
	assert_true(HackCaster.tags_of(target).has("relay"), "its target is a relay, not the body or a drone")


# ---- hints ----

func test_vela_hints_the_relays_after_40_seconds_with_none_broken() -> void:
	await _setup()
	for i: int in range(60 * 41):
		_kit.fight.tick(1.0 / 60.0)
	assert_has(_kit.events, &"vela_rig_zap_relays")
	var count: int = 0
	for id: StringName in _kit.events:
		if id == &"vela_rig_zap_relays":
			count += 1
	assert_eq(count, 1, "once")


func test_no_hint_if_a_relay_is_already_broken() -> void:
	await _setup()
	_kit.break_pair(&"fl")
	for i: int in range(60 * 41):
		_kit.fight.tick(1.0 / 60.0)
	assert_does_not_have(_kit.events, &"vela_rig_zap_relays")


# ---- the whole phase, then on ----

func test_after_the_rig_the_fight_moves_to_the_next_phase_and_sets_the_phase_2_retry_point() -> void:
	await _setup()
	var started: Array[StringName] = []
	_kit.fight.phase_started.connect(func(id: StringName) -> void: started.append(id))
	_kit.fight.skip_phase()
	await _kit.frames(2)
	assert_eq(started.size() > 0, true)
	assert_eq(_kit.fight.phase_id(), &"mech", "no transition node in a stub room: it goes straight on")
	assert_eq(_kit.room.checkpoints.back(), {"spawn": "retry_phase2", "form": &"huge", "full_health": true})
