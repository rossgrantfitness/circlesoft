extends TestCase
## Red's four hacks through the real ActionPlayer, HackCaster and CombatDirector (docs/slice/slice_tech_plan.md 4,
## docs/slice/hacks_design.md): the hack button casts, the cost comes out of the battery, hits go through the same chain as
## the sword's (hit-stop, numbers, reactions) and never refill the battery, and each hack does what its data says.

var _kit: HackKit = null


func _setup(attack_enemies: bool = false) -> void:
	_kit = HackKit.new(self)
	await _kit.arena(attack_enemies)


# ---- the button and the battery ----

func test_the_hack_button_casts_the_selected_hack_and_pays_for_it() -> void:
	await _setup()
	assert_eq(_kit.battery().charge(), 50.0, "a new game starts at 50")
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName], "Zap Drone is selected first")
	assert_eq(_kit.battery().charge(), 30.0, "Zap Drone costs 20")
	assert_eq(_kit.casts.size(), 1)
	assert_eq(_kit.casts[0]["hack"], &"zap_drone")
	assert_has(_kit.texts, "Zap Drone  (battery 30)", "the sandbox's call-out line says what happened")
	assert_does_not_have(_kit.texts, "Hack: coming later", "the placeholder is gone once a real hack fires")


func test_sword_hits_fill_the_battery_and_the_director_announces_it() -> void:
	await _setup()
	var enemy: ActionEnemy = _kit.grunt(Vector3(0, 0, 1.4))
	await _kit.settle()
	var seen: Array[float] = []
	_kit.director.battery_changed.connect(func(charge: float, _capacity: float) -> void: seen.append(charge))
	_kit.red.press(&"light")
	await _kit.until(func() -> bool: return _kit.hits_from("sword").size() > 0, 60)
	await _kit.frames(2)
	assert_gt(_kit.hits_from("sword").size(), 0, "the sword connected")
	assert_gt(_kit.battery().charge(), 50.0, "and filled the battery")
	assert_false(seen.is_empty(), "battery_changed fired")
	assert_eq(seen[seen.size() - 1], _kit.battery().charge())
	assert_lt(enemy.hp, enemy.hp_max)


func test_a_hack_hit_never_refills_the_battery() -> void:
	await _setup()
	var enemy: ActionEnemy = _kit.grunt(Vector3(0, 0, 5.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return enemy.hp < enemy.hp_max, 120)
	assert_lt(enemy.hp, enemy.hp_max, "the drone hit")
	await _kit.frames(5)
	assert_eq(_kit.battery().charge(), 30.0, "50 minus the 20 it cost, and the hit gave nothing back")


func test_a_hack_cast_does_not_start_in_town_mode() -> void:
	await _setup()
	_kit.red.set_town_mode(true)
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [] as Array[StringName])
	assert_eq(_kit.battery().charge(), 50.0)


func test_a_press_a_little_early_still_counts_because_the_button_is_buffered() -> void:
	await _setup()
	_kit.red.press(&"light")
	await _kit.frames(2)
	_kit.red.release(&"light")
	await _kit.tap_hack()                # pressed in the middle of Light 1's startup
	await _kit.frames(40)
	assert_true(_kit.moves.has(&"hack_zap"), "the cast started once the swing's chain window opened: %s" % [_kit.moves])
	assert_eq(_kit.moves[0], &"light_1")


# ---- cost, cooldown, jam ----

func test_a_cast_with_too_little_battery_does_nothing_and_says_why() -> void:
	await _setup()
	_kit.battery().set_charge(10.0)
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [] as Array[StringName], "no cast move")
	assert_eq(_kit.battery().charge(), 10.0, "nothing spent")
	assert_eq(_kit.refusals(HackRules.R_BATTERY), 1)
	assert_has(_kit.texts, "Battery low: Zap Drone needs 20, you have 10")


func test_a_second_zap_inside_the_cooldown_is_refused_and_one_after_it_works() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	await _kit.tap_hack()
	await _kit.frames(8)
	await _kit.tap_hack()                  # 500 ms cooldown from the data
	await _kit.frames(40)
	assert_eq(_kit.moves.size(), 1, "the second press was refused")
	assert_true(_kit.refusals(HackRules.R_COOLDOWN) + _kit.refusals(HackRules.R_GLOBAL) >= 1)
	await _kit.frames(30)
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.moves.size(), 2, "after the cooldown it casts again")
	assert_eq(_kit.battery().charge(), 60.0, "two Zaps cost 40")


func test_quiet_hours_jams_the_hacks_and_the_hud_hears_about_it() -> void:
	await _setup()
	var locks: Array[Dictionary] = []
	_kit.director.hack_locked.connect(func(active: bool, ms: float) -> void: locks.append({"active": active, "ms": ms}))
	_kit.director.lock_hacks(2000.0)
	await _kit.frames(1)
	assert_true(_kit.director.hacks_locked())
	assert_eq(locks.size(), 1)
	assert_true(bool(locks[0]["active"]))
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [] as Array[StringName], "no cast while jammed")
	assert_eq(_kit.battery().charge(), 50.0, "and the charge is kept")
	assert_eq(_kit.refusals(HackRules.R_LOCKED), 1)
	await _kit.frames(125)                  # the jam runs out on Red's clock
	assert_false(_kit.director.hacks_locked())
	assert_false(bool(locks[locks.size() - 1]["active"]), "hack_locked(false) when it ends")
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName], "and it casts again")


func test_unlocking_early_frees_the_hacks_at_once() -> void:
	await _setup()
	_kit.director.lock_hacks(60000.0)
	await _kit.frames(1)
	_kit.director.unlock_hacks()
	await _kit.frames(1)
	assert_false(_kit.director.hacks_locked())


func test_free_hacks_testing_knob_keeps_the_battery_full_and_costs_nothing() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_free_cast", true)
	await _kit.frames(2)
	assert_eq(_kit.battery().charge(), 100.0, "the battery stays full")
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.battery().charge(), 100.0, "and a cast costs nothing")
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName])


# ---- Zap Drone ----

func test_zap_drone_flies_at_an_enemy_ahead_and_hurts_it_through_the_hit_chain() -> void:
	await _setup()
	var enemy: ActionEnemy = _kit.grunt(Vector3(0, 0, 6.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return enemy.hp < enemy.hp_max, 120)
	assert_eq(enemy.hp, enemy.hp_max - 12, "12 damage from the data")
	var info: Dictionary = _kit.hits_from("hack")[0]
	assert_eq(info["move_id"], &"hack_zap")
	assert_eq(info["attacker"], &"red")
	assert_eq(info["target"], enemy.actor_id)
	assert_eq(info["spark"], "slash", "the spark comes from the hack's data")
	assert_gt(float(info["hit_stop_ms"]), 0.0, "and it has hit-stop like a sword hit")


func test_zap_drone_passes_through_three_enemies_and_stops() -> void:
	await _setup()
	var line: Array[ActionEnemy] = []
	for z: float in [3.0, 4.2, 5.4, 6.6]:
		line.append(_kit.grunt(Vector3(0, 0, z)))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(90)
	var hurt: int = 0
	for enemy: ActionEnemy in line:
		if enemy.hp < enemy.hp_max:
			hurt += 1
	assert_eq(hurt, 3, "three enemies, then the drone is spent")
	assert_eq(line[3].hp, line[3].hp_max, "the fourth is untouched")


func test_the_pierce_knob_changes_how_many() -> void:
	await _setup()
	_kit.director.feel.set_value("zap_pierce", 1)
	var line: Array[ActionEnemy] = []
	for z: float in [3.0, 4.2]:
		line.append(_kit.grunt(Vector3(0, 0, z)))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(90)
	assert_lt(line[0].hp, line[0].hp_max)
	assert_eq(line[1].hp, line[1].hp_max, "pierce 1 stops at the first")


func test_zap_drone_does_double_to_a_drone_tagged_enemy() -> void:
	await _setup()
	var drone: ActionEnemy = _kit.grunt(Vector3(0, 0, 5.0), ["drone"])
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return drone.hp < drone.hp_max, 120)
	assert_eq(drone.hp, drone.hp_max - 24, "12 doubled by the drone tag")


func test_the_damage_knob_scales_zap() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_damage_scale", 2.0)
	var enemy: ActionEnemy = _kit.grunt(Vector3(0, 0, 5.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return enemy.hp < enemy.hp_max, 120)
	assert_eq(enemy.hp, enemy.hp_max - 24)


func test_zap_drone_with_nothing_in_front_flies_straight_and_burns_out() -> void:
	await _setup()
	await _kit.tap_hack()
	await _kit.frames(12)
	assert_eq(_kit.count_nodes(ZapDrone), 1, "the drone is in flight")
	await _kit.frames(90)
	assert_eq(_kit.count_nodes(ZapDrone), 0, "gone after its 18 m")
	assert_eq(_kit.battery().charge(), 30.0, "the cost was spent")


func test_zap_drone_goes_for_the_hard_lock_even_off_to_the_side() -> void:
	await _setup()
	var ahead: ActionEnemy = _kit.grunt(Vector3(0, 0, 6.0))
	var side: ActionEnemy = _kit.grunt(Vector3(6.0, 0, 3.0))
	await _kit.settle()
	var lock: LockOn = LockOn.new()
	lock.read_engine_input = false
	add_to_root(lock)
	lock.origin_node = _kit.red
	_kit.red.lock_on = lock
	lock.set_target(side)
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return side.hp < side.hp_max, 150)
	assert_lt(side.hp, side.hp_max, "the drone went where the lock was")
	assert_eq(ahead.hp, ahead.hp_max, "and not at the one straight ahead")


func test_zap_drone_can_be_cast_in_the_air() -> void:
	await _setup()
	_kit.red.press(&"jump")
	await _kit.frames(3)
	_kit.red.release(&"jump")
	await _kit.frames(8)
	assert_true(_kit.red.is_airborne(), "she is in the air")
	await _kit.tap_hack()
	await _kit.frames(12)
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName], "air_ok lets Zap fly from the air")
	assert_eq(_kit.battery().charge(), 30.0)


# ---- EMP ----

func test_emp_pushes_everything_in_its_ring_and_leaves_the_rest() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var near: ActionEnemy = _kit.grunt(Vector3(0, 0, 2.0))
	var far: ActionEnemy = _kit.grunt(Vector3(0, 0, 9.0))
	await _kit.settle()
	var near_before: Vector3 = near.global_position
	var far_before: Vector3 = far.global_position
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_eq(_kit.moves, [&"hack_emp"] as Array[StringName])
	assert_eq(_kit.battery().charge(), 60.0, "EMP costs 40")
	assert_gt(near.global_position.z - near_before.z, 1.0, "pushed away from Red")
	assert_lt(near.hp_max - near.hp, 6, "barely hurt: 4 damage")
	assert_gt(near.hp_max - near.hp, 0)
	assert_almost_eq(far.global_position.z, far_before.z, 0.05, "outside the ring: not moved")
	assert_eq(far.hp, far.hp_max)


func test_emp_knocks_out_a_drone_tagged_enemy_for_three_seconds() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var drone: ActionEnemy = _kit.grunt(Vector3(0, 0, 2.0), ["drone"])
	var plain: ActionEnemy = _kit.grunt(Vector3(2.0, 0, 0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_eq(drone.body_state, ActionEnemy.ST_STAGGER, "knocked out a second later")
	await _kit.frames(60 * 2)
	assert_eq(drone.body_state, ActionEnemy.ST_STAGGER, "and still out after 3 seconds in all")
	await _kit.frames(60 * 2)
	assert_eq(drone.body_state, ActionEnemy.ST_FREE, "back on its feet after 3 s")
	assert_ne(plain.body_state, ActionEnemy.ST_STAGGER, "an untagged enemy is only pushed")


func test_emp_breaks_a_raised_guard() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var brute: ActionEnemy = (load(HackKit.BRUTE_SCENE) as PackedScene).instantiate() as ActionEnemy
	brute.position = Vector3(0, 0, 2.0)
	brute.rotation.y = PI
	add_to_root(brute)
	brute.set_physics_process(false)
	_kit.enemies.append(brute)
	await _kit.settle()
	brute.body_state = ActionEnemy.ST_BLOCK
	brute._block_phase = ActionEnemy.PHASE_HOLD
	brute._state_ms = 500.0
	assert_true(brute.is_guarding(), "his guard is up")
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return _kit.hits_from("hack").size() > 0, 90)
	var info: Dictionary = _kit.hits_from("hack")[0]
	assert_eq(info["outcome"], HitResolver.OUTCOME_GUARD_BROKEN, "EMP breaks the guard whatever the poise")


func test_emp_can_be_cast_in_the_air() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	_kit.red.press(&"jump")
	await _kit.frames(3)
	_kit.red.release(&"jump")
	await _kit.frames(8)
	await _kit.tap_hack()
	await _kit.frames(14)
	assert_eq(_kit.moves, [&"hack_emp"] as Array[StringName])


# ---- Reboot ----

func test_reboot_needs_a_full_battery_and_says_so() -> void:
	await _setup()
	_kit.caster().select_slot(3)
	await _kit.tap_hack()
	await _kit.frames(20)
	assert_eq(_kit.moves, [] as Array[StringName])
	assert_eq(_kit.refusals(HackRules.R_NOT_FULL), 1)
	assert_has(_kit.texts, "Reboot needs a full battery")


func test_reboot_heals_half_her_health_empties_the_battery_and_makes_her_untouchable() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(3)
	_kit.red.hp = 30
	await _kit.tap_hack()
	await _kit.frames(8)
	assert_eq(_kit.red.hp, 30, "nothing yet: the reboot sequence takes 260 ms")
	await _kit.until(func() -> bool: return _kit.red.hp > 30, 60)
	assert_eq(_kit.red.hp, 90, "half of 120 restored")
	assert_eq(_kit.battery().charge(), 0.0, "the whole battery is spent")
	assert_true(_kit.red.is_invulnerable(), "untouchable while it runs")
	await _kit.frames(30 + 6)
	assert_false(_kit.red.is_invulnerable(), "for 600 ms only")


func test_reboot_does_not_overheal() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(3)
	_kit.red.hp = 110
	await _kit.tap_hack()
	await _kit.frames(40)
	assert_eq(_kit.red.hp, 120)


func test_reboot_in_the_air_is_refused() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.caster().select_slot(3)
	_kit.red.press(&"jump")
	await _kit.frames(3)
	_kit.red.release(&"jump")
	await _kit.frames(8)
	await _kit.tap_hack()
	await _kit.frames(5)
	assert_eq(_kit.refusals(HackRules.R_AIR), 1)
	assert_eq(_kit.battery().charge(), 100.0)


# ---- picking ----

func test_keys_one_to_four_choose_the_hack() -> void:
	await _setup()
	var chosen: Array[StringName] = []
	_kit.director.hack_selected.connect(func(id: StringName) -> void: chosen.append(id))
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_3
	event.pressed = true
	_kit.red.handle_input_event(event)
	assert_eq(_kit.caster().selected(), &"overclock")
	assert_eq(chosen, [&"overclock"] as Array[StringName])
	assert_has(_kit.texts, "Hack: Overclock  (costs 50)")


func test_the_mouse_wheel_and_dpad_step_the_selection() -> void:
	await _setup()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	_kit.red.handle_input_event(down)
	assert_eq(_kit.caster().selected(), &"emp", "wheel down is next")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_LEFT
	pad.pressed = true
	_kit.red.handle_input_event(pad)
	assert_eq(_kit.caster().selected(), &"zap_drone", "d-pad left is previous")
	pad.button_index = JOY_BUTTON_DPAD_LEFT
	_kit.red.handle_input_event(pad)
	assert_eq(_kit.caster().selected(), &"reboot", "and it wraps")


func test_a_selection_key_does_nothing_in_automatic_mode() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_pick_mode", "automatic")
	_kit.caster().select_slot(2)
	assert_eq(_kit.caster().selected(), &"zap_drone")


func test_automatic_mode_zaps_by_default_and_the_hud_shows_the_last_used() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_pick_mode", "automatic")
	_kit.battery().set_charge(100.0)
	_kit.grunt(Vector3(0, 0, 6.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(40)
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName])
	assert_eq(_kit.caster().shown(), &"zap_drone")


func test_automatic_mode_fires_an_emp_into_a_crowd() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_pick_mode", "automatic")
	_kit.battery().set_charge(100.0)
	_kit.grunt(Vector3(0, 0, 2.5))
	_kit.grunt(Vector3(2.0, 0, 1.0))
	_kit.grunt(Vector3(-2.0, 0, 1.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(40)
	assert_eq(_kit.moves, [&"hack_emp"] as Array[StringName], "three close enemies: the crowd rule")


func test_automatic_mode_holding_the_button_reboots_and_tapping_does_not() -> void:
	await _setup()
	_kit.director.feel.set_value("hack_pick_mode", "automatic")
	_kit.battery().reset_full()
	_kit.red.hp = 40
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.moves, [&"hack_zap"] as Array[StringName], "a tap zaps, it does not reboot")
	await _kit.frames(60)
	_kit.battery().reset_full()
	_kit.moves.clear()
	_kit.red.press(&"heavy")
	await _kit.frames(40)              # held past 450 ms
	_kit.red.release(&"heavy")
	await _kit.frames(30)
	assert_eq(_kit.moves, [&"hack_reboot"] as Array[StringName], "a hold reboots")
	assert_gt(_kit.red.hp, 40)


func test_the_pick_mode_knob_switches_while_playing() -> void:
	await _setup()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	_kit.director.feel.set_value("hack_pick_mode", "automatic")
	assert_true(_kit.caster().is_auto())
	_kit.director.feel.set_value("hack_pick_mode", "pick_then_fire")
	assert_false(_kit.caster().is_auto())
	assert_eq(_kit.caster().selected(), &"emp", "the pick is remembered")


# ---- the arena reset ----

func test_resetting_the_director_puts_the_battery_back() -> void:
	await _setup()
	_kit.battery().reset_full()
	_kit.director.lock_hacks(10000.0)
	_kit.director.reset_hacks()
	assert_eq(_kit.battery().charge(), 50.0)
	assert_false(_kit.director.hacks_locked())


func test_a_bare_red_without_a_director_still_shows_the_coming_later_call_out() -> void:
	var red: ActionPlayer = (load(HackKit.RED_SCENE) as PackedScene).instantiate() as ActionPlayer
	red.read_engine_input = false
	add_to_root(red)
	red.set_physics_process(false)
	var texts: Array[String] = []
	red.hack_pressed.connect(func(info: Dictionary) -> void: texts.append(str(info["text"])))
	red.press(&"heavy")
	red.tick(1.0 / 60.0)
	assert_eq(texts, ["Hack: coming later"] as Array[String], "no hack system to fire: the old line stays")
