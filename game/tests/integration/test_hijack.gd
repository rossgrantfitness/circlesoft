extends TestCase
## Overclock and the Hijackable component (docs/slice/slice_tech_plan.md 4.4): the hijack takes an enemy for a while, it
## fights Red's enemies and stays out of Red's scoring, and it goes back dazed. Also the designer's rules that stand until
## Ross says otherwise: no second Overclock while one runs, and the cost comes back if the target dies during the reach.

class Host extends Node3D:
	var team: StringName = &"enemy"
	var dead: bool = false
	var begun: int = 0
	var ended: int = 0
	var refuse: bool = false
	var allowed: bool = true

	func on_hijack_begin(_by: CombatActor, _duration_s: float) -> bool:
		if refuse:
			return false
		begun += 1
		team = &"player"
		return true

	func on_hijack_end() -> void:
		ended += 1
		team = &"enemy"

	func hijack_allowed() -> bool:
		return allowed

var _kit: HackKit = null


func _setup(attack_enemies: bool = false) -> void:
	_kit = HackKit.new(self)
	await _kit.arena(attack_enemies)
	_kit.battery().reset_full()
	_kit.caster().select_slot(2)


func _red_actor() -> CombatActor:
	var stand: CombatActor = CombatActor.new()
	stand.actor_id = &"stand_red"
	stand.team = &"player"
	add_to_root(stand)
	return stand


# ---- the component alone ----

func test_a_hijackable_joins_the_group_and_runs_its_owner_hooks() -> void:
	var host: Host = Host.new()
	add_to_root(host)
	var link: Hijackable = Hijackable.new()
	host.add_child(link)
	assert_true(link.is_in_group(Hijackable.GROUP))
	assert_true(link.can_hijack(&"player"))
	var by: CombatActor = _red_actor()
	var started: Array[float] = []
	link.hijack_started.connect(func(_owner: Node, duration: float) -> void: started.append(duration))
	assert_true(link.begin_hijack(by, 5.0))
	assert_eq(host.begun, 1)
	assert_eq(started, [5.0] as Array[float])
	assert_true(link.is_hijacked())
	assert_eq(link.time_left_s(), 5.0)
	assert_false(link.can_hijack(&"player"), "already taken")
	link.end_hijack()
	assert_eq(host.ended, 1)
	assert_false(link.is_hijacked())
	link.end_hijack()
	assert_eq(host.ended, 1, "ending twice is harmless")


func test_the_countdown_runs_and_ends_the_hijack() -> void:
	var host: Host = Host.new()
	add_to_root(host)
	var link: Hijackable = Hijackable.new()
	host.add_child(link)
	link.set_physics_process(false)
	link.begin_hijack(_red_actor(), 1.0)
	for i: int in range(30):
		link.tick(1.0 / 60.0)
	assert_almost_eq(link.time_left_s(), 0.5, 0.02)
	assert_true(link.is_hijacked())
	for i: int in range(40):
		link.tick(1.0 / 60.0)
	assert_false(link.is_hijacked(), "time is up")
	assert_eq(host.ended, 1)


func test_an_owner_can_refuse_and_a_disallowed_one_cannot_be_taken() -> void:
	var host: Host = Host.new()
	add_to_root(host)
	var link: Hijackable = Hijackable.new()
	host.add_child(link)
	host.refuse = true
	assert_false(link.begin_hijack(_red_actor(), 5.0), "the owner said no")
	assert_false(link.is_hijacked())
	host.refuse = false
	link.allowed = false
	assert_false(link.can_hijack(&"player"), "bosses have allowed = false")
	link.allowed = true
	host.allowed = false
	assert_false(link.can_hijack(&"player"), "so does an owner that says it is not allowed")


func test_it_cannot_take_something_already_on_the_hijackers_team() -> void:
	var host: Host = Host.new()
	host.team = &"player"
	add_to_root(host)
	var link: Hijackable = Hijackable.new()
	host.add_child(link)
	assert_false(link.can_hijack(&"player"))


func test_an_owner_that_dies_ends_the_hijack() -> void:
	var host: Host = Host.new()
	add_to_root(host)
	var link: Hijackable = Hijackable.new()
	host.add_child(link)
	link.set_physics_process(false)
	link.begin_hijack(_red_actor(), 10.0)
	host.dead = true
	link.tick(1.0 / 60.0)
	assert_false(link.is_hijacked())
	assert_eq(host.ended, 1)


# ---- Overclock on a Grunt ----

func test_overclock_takes_the_enemy_in_front_for_ten_seconds_then_gives_it_back_dazed() -> void:
	await _setup()
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	var changes: Array[Dictionary] = []
	_kit.director.hijack_changed.connect(func(info: Dictionary) -> void: changes.append(info))
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return grunt.hijacked_by != null, 60)
	assert_eq(grunt.hijacked_by, _kit.red, "Red has it")
	assert_eq(grunt.team, &"player", "on her side")
	assert_eq(_kit.battery().charge(), 50.0, "Overclock costs 50")
	assert_eq(_kit.moves, [&"hack_overclock"] as Array[StringName])
	assert_eq(changes.size(), 1)
	assert_true(bool(changes[0]["active"]))
	assert_eq(changes[0]["target"], grunt.actor_id)
	assert_eq(changes[0]["duration_s"], 10.0)
	assert_false(_kit.director.living_enemies().has(grunt), "it is no longer one of the enemies")
	assert_eq(_kit.director.player(), _kit.red, "and it is not 'the player'")
	assert_eq(_kit.count_nodes(OverclockLink), 1, "the link line is up")
	await _kit.frames(60 * 9)
	assert_eq(grunt.hijacked_by, _kit.red, "still hers after 9 seconds")
	await _kit.until(func() -> bool: return grunt.hijacked_by == null, 60 * 3)
	assert_null(grunt.hijacked_by, "ten seconds up")
	assert_eq(grunt.team, &"enemy", "back to its owners")
	assert_eq(grunt.body_state, ActionEnemy.ST_STAGGER, "dazed, no instant revenge")
	assert_false(bool(changes[changes.size() - 1]["active"]))
	await _kit.frames(60)
	assert_eq(_kit.count_nodes(OverclockLink), 0, "the link line is gone")
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE, "and after under a second it is awake again")


func test_the_overclock_length_knob_changes_the_time() -> void:
	await _setup()
	_kit.director.feel.set_value("overclock_duration_s", 4.0)
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return grunt.hijacked_by != null, 60)
	await _kit.frames(60 * 3)
	assert_not_null(grunt.hijacked_by)
	await _kit.frames(60 * 2)
	assert_null(grunt.hijacked_by)


func test_a_hijacked_enemy_fights_the_nearest_enemy_and_its_hits_are_not_red_s_score() -> void:
	await _setup()
	var ally: ActionEnemy = _kit.grunt(Vector3(0, 0, 3.0))
	# A second enemy that stands still and never fights back (nothing ticks it): the hijacked one has to go and hit it.
	var victim: ActionEnemy = (load(HackKit.GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	victim.position = Vector3(5.0, 0, 3.0)
	add_to_root(victim)
	victim.set_physics_process(false)
	await _kit.settle()
	var charge_before: float = _kit.battery().charge()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return ally.hijacked_by != null, 60)
	var after_cast: float = _kit.battery().charge()
	assert_eq(after_cast, charge_before - 50.0)
	_kit.director.feel.set_value("enemies_attack", false)        # (the knob only governs enemies; a hijacked one ignores it)
	await _kit.until(func() -> bool: return victim.hp < victim.hp_max, 60 * 8)
	assert_lt(victim.hp, victim.hp_max, "the hijacked Grunt hurt the other enemy")
	var hit: Dictionary = _kit.hits_from("hijacked")[0]
	assert_eq(hit["attacker"], ally.actor_id)
	assert_eq(hit["target"], victim.actor_id)
	assert_eq(_kit.red.hp, _kit.red.hp_max, "and left Red alone")
	assert_eq(_kit.battery().charge(), after_cast, "its hits do not fill Red's battery")
	assert_eq(_kit.director.style.points(), 0.0, "or score Noise for her")


func test_a_hijacked_enemy_is_left_alone_by_emp_and_zap() -> void:
	await _setup()
	var ally: ActionEnemy = _kit.grunt(Vector3(0, 0, 3.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return ally.hijacked_by != null, 60)
	await _kit.frames(60)
	_kit.battery().reset_full()
	_kit.caster().select_slot(1)
	await _kit.frames(60)
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_eq(_kit.moves.back(), &"hack_emp")
	assert_eq(ally.hp, ally.hp_max, "the EMP did not touch her ally")
	assert_ne(ally.body_state, ActionEnemy.ST_STAGGER)


func test_a_hijacked_enemy_that_dies_just_dies() -> void:
	await _setup()
	var ally: ActionEnemy = _kit.grunt(Vector3(0, 0, 3.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return ally.hijacked_by != null, 60)
	ally.apply_hit({"damage": 999, "outcome": &"hit"})
	await _kit.frames(5)
	assert_true(ally.dead)
	assert_null(ally.hijacked_by, "the hijack is over")
	assert_eq(ally.body_state, ActionEnemy.ST_DEAD, "and it stays dead (no stun, no revival)")


# ---- the refusals ----

func test_no_hijackable_in_range_means_no_cast_and_no_charge_spent() -> void:
	await _setup()
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.moves, [] as Array[StringName])
	assert_eq(_kit.battery().charge(), 100.0)
	assert_eq(_kit.refusals(HackRules.R_NO_SIGNAL), 1)
	assert_has(_kit.texts, "No signal")


func test_something_out_of_reach_is_not_a_target() -> void:
	await _setup()
	_kit.grunt(Vector3(0, 0, 20.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.refusals(HackRules.R_NO_SIGNAL), 1)


func test_an_enemy_the_data_does_not_allow_cannot_be_taken() -> void:
	await _setup()
	var brute: ActionEnemy = (load(HackKit.BRUTE_SCENE) as PackedScene).instantiate() as ActionEnemy
	brute.position = Vector3(0, 0, 3.0)
	add_to_root(brute)
	brute.set_physics_process(false)
	await _kit.settle()
	assert_null(brute.hijackable, "the Brute has no Hijackable")
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.refusals(HackRules.R_NO_SIGNAL), 1)


func test_a_boss_tagged_enemy_says_no() -> void:
	await _setup()
	var boss: ActionEnemy = _kit.grunt(Vector3(0, 0, 3.0), ["boss"])
	await _kit.settle()
	assert_false(boss.hijack_allowed())
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.refusals(HackRules.R_NO_SIGNAL), 1)
	assert_null(boss.hijacked_by)


func test_a_second_overclock_is_refused_while_one_runs() -> void:
	await _setup()
	var first: ActionEnemy = _kit.grunt(Vector3(0, 0, 3.0))
	var second: ActionEnemy = _kit.grunt(Vector3(1.5, 0, 4.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return first.hijacked_by != null or second.hijacked_by != null, 60)
	var taken: ActionEnemy = first if first.hijacked_by != null else second
	var other: ActionEnemy = second if taken == first else first
	await _kit.frames(60 * 2)             # past the 1.5 s cooldown
	_kit.battery().reset_full()
	await _kit.tap_hack()
	await _kit.frames(30)
	assert_eq(_kit.refusals(HackRules.R_OVERCLOCK), 1, "one at a time")
	assert_null(other.hijacked_by)
	assert_eq(_kit.battery().charge(), 100.0, "and nothing was spent on the refused one")
	assert_not_null(taken.hijacked_by)


func test_the_cost_is_refunded_if_the_target_dies_during_the_reach() -> void:
	await _setup()
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(4)                      # inside the 200 ms reach
	assert_eq(_kit.battery().charge(), 50.0, "the cost is spent at the start of the cast")
	grunt.apply_hit({"damage": 999, "outcome": &"hit"})
	await _kit.frames(30)
	assert_eq(_kit.battery().charge(), 100.0, "refunded")
	assert_eq(_kit.refusals(HackRules.R_NO_SIGNAL) + _kit.refusals(&"target_lost"), 1)
	assert_has(_kit.texts, "Signal lost")
	assert_null(grunt.hijacked_by)
	# and it left no cooldown behind
	var other: ActionEnemy = _kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return other.hijacked_by != null, 40)
	assert_not_null(other.hijacked_by, "she can cast again at once")


func test_the_hard_lock_picks_which_one_to_take() -> void:
	await _setup()
	var near: ActionEnemy = _kit.grunt(Vector3(0, 0, 2.5))
	var far: ActionEnemy = _kit.grunt(Vector3(3.0, 0, 7.0))
	await _kit.settle()
	var lock: LockOn = LockOn.new()
	lock.read_engine_input = false
	add_to_root(lock)
	lock.origin_node = _kit.red
	_kit.red.lock_on = lock
	lock.set_target(far)
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return far.hijacked_by != null or near.hijacked_by != null, 60)
	assert_not_null(far.hijacked_by, "the locked one")
	assert_null(near.hijacked_by)


func test_without_a_lock_the_best_in_front_is_taken() -> void:
	await _setup()
	var ahead: ActionEnemy = _kit.grunt(Vector3(0, 0, 5.0))
	var behind: ActionEnemy = _kit.grunt(Vector3(0, 0, -3.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return ahead.hijacked_by != null or behind.hijacked_by != null, 60)
	assert_not_null(ahead.hijacked_by, "the one she is facing, though the other is closer")
	assert_null(behind.hijacked_by)


func test_overclock_is_ground_only() -> void:
	await _setup()
	_kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	_kit.red.press(&"jump")
	await _kit.frames(3)
	_kit.red.release(&"jump")
	await _kit.frames(8)
	await _kit.tap_hack()
	await _kit.frames(5)
	assert_eq(_kit.refusals(HackRules.R_AIR), 1)
	assert_eq(_kit.battery().charge(), 100.0)


func test_resetting_red_lets_go_of_a_hijack() -> void:
	await _setup()
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 4.0))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return grunt.hijacked_by != null, 60)
	_kit.red.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
	assert_null(grunt.hijacked_by)
	assert_eq(grunt.team, &"enemy")
