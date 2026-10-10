extends TestCase
## Bot runs in the real combat sandbox for the hacks (docs/slice/slice_tech_plan.md 4, VS-9). A scripted Red presses the
## hack button (K / right mouse / Y), picks with the number keys through the sandbox's own input relay, and the runs show:
##   - sword hits fill the battery and a Zap Drone spends it,
##   - Zap Drone, EMP, Overclock and Reboot each do their job to the real Grunt in the real arena,
##   - a Grunt taken over by Overclock hurts another Grunt for Red,
##   - Automatic mode (the feel panel's "How a hack is picked") picks by the situation,
##   - the arena reset puts the battery back.
## The sandbox runs in real time (60 physics steps a second), so each run stops as soon as it has seen what it came for.

const SANDBOX: String = "res://scenes/sandbox/combat_sandbox.tscn"
const FRAME: float = 1.0 / 60.0
const RED_AT: Vector3 = Vector3(4.0, 0.1, 12.0)

var _sandbox: Node = null
var _director: CombatDirector = null
var _red: ActionPlayer = null
var _moves: Array[StringName] = []
var _hits: Array[Dictionary] = []
var _texts: Array[String] = []


func _boot(keep: Array[String]) -> void:
	_sandbox = (load(SANDBOX) as PackedScene).instantiate()
	add_to_root(_sandbox)
	for i: int in range(3):
		await tree.physics_frame
	_director = _sandbox.call("get_director") as CombatDirector
	_red = _sandbox.call("get_player") as ActionPlayer
	assert_not_null(_director, "the sandbox has a director")
	assert_not_null(_red, "and Red")
	_red.read_engine_input = false
	for enemy: Node3D in _sandbox.call("get_enemies"):
		if not keep.has(String((enemy as ActionEnemy).actor_id)):
			enemy.queue_free()
	await tree.physics_frame
	_director.feel.set_value("enemies_attack", false)
	_director.feel.set_value("enemy_dodge_scale", 0.0)
	_director.feel.set_value("enemy_block_scale", 0.0)
	_moves.clear()
	_hits.clear()
	_texts.clear()
	_red.move_started.connect(func(move_id: StringName) -> void: _moves.append(move_id))
	_red.hack_pressed.connect(func(info: Dictionary) -> void: _texts.append(str(info["text"])))
	_director.hit_landed.connect(func(info: Dictionary) -> void: _hits.append(info))


func _enemy(actor_id: String) -> ActionEnemy:
	return _director.get_actor(StringName(actor_id)) as ActionEnemy


func _place(actor: Node3D, at: Vector3, yaw_toward: Vector3 = Vector3.INF) -> void:
	actor.global_position = at
	if yaw_toward != Vector3.INF:
		var look: Vector3 = yaw_toward - at
		actor.rotation.y = atan2(look.x, look.z)


## Red on the open floor facing -Z, enemies `ahead` metres in front of her (+ `side` metres to the right).
func _stage(placements: Array) -> void:
	_place(_red, RED_AT, RED_AT + Vector3(0.0, 0.0, -1.0))
	for entry: Array in placements:
		_place(entry[0] as Node3D, RED_AT + Vector3(float(entry[2]), 0.0, -float(entry[1])), RED_AT)
	for i: int in range(10):
		await tree.physics_frame


func _frames(seconds: float) -> int:
	return int(seconds / FRAME)


func _run(seconds: float, done: Callable = Callable()) -> void:
	for frame: int in range(_frames(seconds)):
		await tree.physics_frame
		if done.is_valid() and bool(done.call()):
			return


## Presses the attack button every few frames (the one-button combo) until `done`, keeping the target alive.
func _mash(seconds: float, done: Callable) -> void:
	var since_press: int = 6
	for frame: int in range(_frames(seconds)):
		await tree.physics_frame
		for enemy: Node3D in _sandbox.call("get_enemies"):
			if is_instance_valid(enemy) and (enemy as ActionEnemy).dead:
				(enemy as ActionEnemy).hp = (enemy as ActionEnemy).hp_max
		if bool(done.call()):
			break
		since_press += 1
		_red.release(&"light")
		if since_press >= 6:
			_red.press(&"light")
			since_press = 0
	_red.release(&"light")


func _tap_hack() -> void:
	_red.press(&"heavy")
	await tree.physics_frame
	_red.release(&"heavy")


## A number key, through the sandbox's own input relay (the way the game delivers it).
func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_sandbox.call("handle_input_event", event)


func _hits_by(move_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in _hits:
		if info["move_id"] == move_id:
			out.append(info)
	return out


# ---- the loop: sword fills it, a hack spends it ----

func test_sword_hits_fill_the_battery_and_a_zap_drone_spends_it() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 1.6, 0.0]])
	_director.battery.set_charge(0.0)
	var start_hp: int = grunt.hp
	await _mash(4.0, func() -> bool: return _director.battery.charge() >= 20.0)
	var earned: float = _director.battery.charge()
	print("      [bot] sword hits filled the battery to %.0f; moves %s" % [earned, _moves])
	assert_ge(earned, 20.0, "a few sword hits earn a Zap Drone")
	await _run(1.2)                       # let the swing finish
	grunt.hp = grunt.hp_max               # keep it alive for the zap
	_moves.clear()
	_hits.clear()
	await _tap_hack()
	await _run(2.0, func() -> bool: return _hits_by(&"hack_zap").size() > 0)
	print("      [bot] zap: moves %s, charge %.0f -> %.0f" % [_moves, earned, _director.battery.charge()])
	assert_true(_moves.has(&"hack_zap"), "the hack button cast a Zap Drone")
	assert_gt(float(_hits_by(&"hack_zap").size()), 0.0, "and it hit the Grunt")
	assert_almost_eq(_director.battery.charge(), earned - 20.0, 0.5, "for 20 from the battery")
	assert_lt(grunt.hp, grunt.hp_max)
	assert_gt(float(start_hp), 0.0)


# ---- each hack, in the real arena ----

func test_zap_drone_hits_a_grunt_across_the_arena() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 8.0, 0.0]])
	_director.battery.set_charge(100.0)
	await _tap_hack()
	await _run(2.5, func() -> bool: return _hits_by(&"hack_zap").size() > 0)
	print("      [bot] zap from 8 m: %s" % [_hits_by(&"hack_zap")])
	assert_eq(_hits_by(&"hack_zap").size(), 1)
	assert_eq(_hits_by(&"hack_zap")[0]["source"], "hack")
	assert_eq(grunt.hp, grunt.hp_max - 12)


func test_emp_pushes_a_pack_off_her_from_the_number_key() -> void:
	await _boot(["grunt_1", "grunt_2", "grunt_3"])
	var pack: Array[ActionEnemy] = [_enemy("grunt_1"), _enemy("grunt_2"), _enemy("grunt_3")]
	await _stage([[pack[0], 1.8, 0.0], [pack[1], 1.5, 1.6], [pack[2], 1.5, -1.6]])
	_director.battery.set_charge(100.0)
	var before: Array[float] = []
	for grunt: ActionEnemy in pack:
		before.append(_red.global_position.distance_to(grunt.global_position))
	_key(KEY_2)                           # fires EMP straight away, through the sandbox's own input relay
	await _run(1.2)
	print("      [bot] emp: moves %s, hits %d" % [_moves, _hits_by(&"hack_emp").size()])
	assert_true(_moves.has(&"hack_emp"))
	assert_eq(_hits_by(&"hack_emp").size(), 3, "all three caught in the ring")
	for i: int in range(3):
		assert_gt(_red.global_position.distance_to(pack[i].global_position), before[i] + 0.8, "grunt %d was pushed away" % i)
	assert_almost_eq(_director.battery.charge(), 60.0, 0.5)


func test_overclock_turns_a_grunt_on_the_others() -> void:
	await _boot(["grunt_1", "grunt_2"])
	var mine: ActionEnemy = _enemy("grunt_1")
	var theirs: ActionEnemy = _enemy("grunt_2")
	await _stage([[mine, 4.0, 0.0], [theirs, 6.5, 3.0]])
	theirs.set_physics_process(false)          # a punching bag: this run is about the hijacked Grunt, not about chasing a circling one
	_director.battery.set_charge(100.0)
	_key(KEY_3)                           # Overclock
	await _run(1.5, func() -> bool: return mine.hijacked_by != null)
	assert_eq(mine.hijacked_by, _red, "Overclock took the Grunt she was facing")
	assert_eq(mine.team, &"player")
	await _run(9.0, func() -> bool: return theirs.hp < theirs.hp_max)
	var by_ally: Array[Dictionary] = []
	for info: Dictionary in _hits:
		if str(info.get("source", "")) == "hijacked":
			by_ally.append(info)
	print("      [bot] overclock: ally hits on the other grunt: %d, its hp %d/%d" % [by_ally.size(), theirs.hp, theirs.hp_max])
	assert_gt(float(by_ally.size()), 0.0, "the hijacked Grunt hit the other one")
	assert_lt(theirs.hp, theirs.hp_max)
	assert_eq(_red.hp, _red.hp_max, "and nothing touched Red")


func test_reboot_heals_her_and_empties_the_battery() -> void:
	await _boot(["grunt_1"])
	await _stage([])
	_director.battery.reset_full()
	_red.hp = 30
	_key(KEY_4)                           # Reboot
	await _run(1.5, func() -> bool: return _red.hp > 30)
	print("      [bot] reboot: hp 30 -> %d, battery %.0f" % [_red.hp, _director.battery.charge()])
	assert_eq(_red.hp, 90)
	assert_eq(_director.battery.charge(), 0.0)


# ---- a hack inside a string ----

func test_a_zap_drone_slots_into_the_middle_of_a_light_string() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 1.6, 0.0]])
	_director.battery.set_charge(100.0)
	_red.press(&"light")
	await _run(0.25)
	_red.release(&"light")
	await _tap_hack()
	await _run(1.5)
	grunt.hp = grunt.hp_max
	print("      [bot] string then hack: %s" % [_moves])
	assert_eq(_moves[0], &"light_1")
	assert_true(_moves.has(&"hack_zap"), "the hack followed the swing")


# ---- automatic mode ----

func test_automatic_mode_zaps_one_enemy_and_emps_a_crowd() -> void:
	await _boot(["grunt_1", "grunt_2", "grunt_3"])
	var pack: Array[ActionEnemy] = [_enemy("grunt_1"), _enemy("grunt_2"), _enemy("grunt_3")]
	_director.feel.set_value("hack_pick_mode", "automatic")
	await _stage([[pack[0], 6.0, 0.0], [pack[1], 14.0, 8.0], [pack[2], 14.0, -8.0]])
	_director.battery.set_charge(100.0)
	await _tap_hack()
	await _run(1.0)
	assert_eq(_moves, [&"hack_zap"] as Array[StringName], "one enemy near: a Zap Drone")
	await _run(1.0)
	await _stage([[pack[0], 2.0, 0.0], [pack[1], 1.5, 1.6], [pack[2], 1.5, -1.6]])
	_moves.clear()
	await _tap_hack()
	await _run(1.0)
	print("      [bot] automatic: %s" % [_moves])
	assert_eq(_moves, [&"hack_emp"] as Array[StringName], "three close: an EMP")


# ---- the arena reset ----

func test_the_arena_reset_puts_the_battery_back() -> void:
	await _boot(["grunt_1"])
	_director.battery.reset_full()
	_sandbox.call("reset_arena")
	await tree.physics_frame
	assert_eq(_director.battery.charge(), 50.0)
