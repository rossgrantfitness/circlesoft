extends TestCase
## ActionEnemy carrying out the enemy AI on a real floor (enemy_ai_design): the dodge with its i-frames and
## punish window, the block with its guard meter and guard break, hit reactions by type, the wind-up floors, tokens
## for defenders and runners, fleeing, flanking, the Brute's enrage, and allies noticing. The defence rolls are
## forced to 100% where a single run has to show the move; the chances themselves are tested in the brain tests.

const FRAME: float = 1.0 / 60.0
const GRUNT_SCENE: String = "res://scenes/actors/enemies/grunt.tscn"
const BRUTE_SCENE: String = "res://scenes/actors/enemies/brute.tscn"

class Stand extends CombatActor:
	var reactions: Array[Dictionary] = []

	func _on_hit_reaction(result: Dictionary) -> void:
		reactions.append(result)

	func is_airborne() -> bool:
		return false


var _director: CombatDirector = null
var _stand: Stand = null
var _extra: int = 0


func _floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape_node.shape = box
	floor_body.add_child(shape_node)
	add_to_root(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


## A director, a floor, a stand-in for Red at the origin facing +Z, and the first enemy at `at`.
func _setup(scene_path: String, at: Vector3, stand_yaw: float = 0.0) -> ActionEnemy:
	_floor()
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	_director.sync_to_wall_clock = false
	add_to_root(_director)
	_director.set_physics_process(false)
	_stand = Stand.new()
	_stand.actor_id = &"red"
	_stand.team = &"player"
	_stand.move_set_id = &"red"
	_stand.hp = 400
	_stand.hp_max = 400
	_stand.height_m = 0.95
	add_to_root(_stand)
	_stand.global_position = Vector3.ZERO
	_stand.rotation.y = stand_yaw
	_stand.set_physics_process(false)
	var enemy: ActionEnemy = _spawn(scene_path, at)
	await tree.physics_frame
	await tree.physics_frame
	return enemy


func _spawn(scene_path: String, at: Vector3) -> ActionEnemy:
	_extra += 1
	var enemy: ActionEnemy = (load(scene_path) as PackedScene).instantiate() as ActionEnemy
	enemy.actor_id = StringName("e%d" % _extra)
	enemy.rng_seed = 100 + _extra
	enemy.position = at
	add_to_root(enemy)
	enemy.set_physics_process(false)
	return enemy


var _all: Array[ActionEnemy] = []


func _step(enemy: ActionEnemy, frames: int) -> void:
	for i: int in range(frames):
		_director.tick(FRAME)
		enemy.tick(FRAME)
		for other: ActionEnemy in _all:
			other.tick(FRAME)


## Step until `condition` is true or `max_frames` pass; returns the frames used (or -1).
func _until(enemy: ActionEnemy, condition: Callable, max_frames: int) -> int:
	for i: int in range(max_frames):
		if condition.call():
			return i
		_step(enemy, 1)
	return -1 if not condition.call() else max_frames


## Patch the enemy's defend numbers and rebuild its brain.
func _force(enemy: ActionEnemy, defend: Dictionary = {}, section: String = "defend") -> void:
	((enemy.data["behaviour"] as Dictionary)[section] as Dictionary).merge(defend, true)
	enemy.brain = enemy._make_brain()


func _red_swings(move_id: StringName) -> void:
	_director.begin_player_swing(_stand, move_id)


func _hit(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"outcome": &"hit", "damage": 8, "hitstun_ms": 320.0, "knockback": Vector3(0, 0, -0.5), "launch_mps": 0.0,
		"knockdown": false, "hit_stop_ms": 0.0, "poise_after": 22.0, "style_points": 10.0, "juggle_count": 0,
		"launched": false, "air_hit": false, "staggered_target": false}
	result.merge(extra, true)
	return result


## Resolve a real move of Red's against the enemy exactly like the director would, and apply it.
func _red_hits(enemy: ActionEnemy, move_id: StringName) -> Dictionary:
	var move: Dictionary = MoveSet.load_default().get_move(&"red", move_id)
	var attack: Dictionary = (move["hit"] as Dictionary).duplicate(true)
	attack["move_id"] = move_id
	attack["launcher"] = bool(move["launcher"])
	attack["swing_id"] = 900 + _extra
	_extra += 1
	var ctx: Dictionary = {"parry": {"rating": "miss"}, "lights_on": {"active": false, "damage_mult": 1.0, "super_armor": false},
			"feel": _director.feel, "hit_feel": CombatData.hit_feel()}
	var result: Dictionary = HitResolver.resolve(attack, _stand.snapshot(), enemy.snapshot(), ctx)
	enemy.apply_hit(result)
	return result


func _to_circle(enemy: ActionEnemy) -> void:
	_director.feel.set_value("enemies_attack", false)
	await _until(enemy, func() -> bool: return enemy.brain.state() == EnemyBrain.CIRCLE, 120)


# ---- dodge ----

func test_a_grunt_dodge_has_220_ms_of_i_frames_then_a_punish_window() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
	_force(grunt, {"dodge_chance": 1.0, "block_chance": 0.0})
	await _to_circle(grunt)
	var start_pos: Vector3 = grunt.global_position
	_red_swings(&"heavy")
	var frames: int = await _until(grunt, func() -> bool: return grunt.body_state == ActionEnemy.ST_DODGE, 30)
	assert_ge(frames, 0, "it dodged")
	assert_le(float(frames) * FRAME * 1000.0, 150.0 + 40.0, "within its reaction time (80 to 150 ms)")
	assert_true(grunt.is_dodging())
	assert_false(grunt.is_invulnerable(), "the 40 ms start-up: the cyan tell, not yet untouchable")
	var vulnerable_after: int = 0
	var invulnerable_frames: int = 0
	var frame_count: int = 0
	var stayed_hittable_at_end: bool = false
	while grunt.body_state == ActionEnemy.ST_DODGE and frame_count < 60:
		_step(grunt, 1)
		frame_count += 1
		if grunt.is_invulnerable():
			invulnerable_frames += 1
		elif invulnerable_frames > 0 and grunt.body_state == ActionEnemy.ST_DODGE:
			vulnerable_after += 1
	stayed_hittable_at_end = vulnerable_after > 0
	assert_almost_eq(float(invulnerable_frames) * FRAME * 1000.0, 220.0, 35.0, "about 220 ms untouchable")
	assert_true(stayed_hittable_at_end, "then about 300 ms of recovery where it can be hit")
	assert_almost_eq(float(vulnerable_after) * FRAME * 1000.0, 300.0, 40.0)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)
	var moved: float = (grunt.global_position - start_pos).length()
	assert_gt(moved, 1.8, "a 2.4 m dodge")


func test_a_hit_during_the_i_frames_is_evaded_and_after_them_it_lands() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
	_force(grunt, {"dodge_chance": 1.0, "block_chance": 0.0})
	await _to_circle(grunt)
	_red_swings(&"heavy")
	await _until(grunt, func() -> bool: return grunt.is_invulnerable(), 40)
	assert_true(grunt.is_invulnerable())
	var result: Dictionary = _red_hits(grunt, &"light_1")
	assert_eq(result["outcome"], &"evaded", "Red's swing goes through the space it left")
	assert_eq(grunt.hp, grunt.hp_max)
	await _until(grunt, func() -> bool: return not grunt.is_invulnerable(), 40)
	assert_eq(grunt.body_state, ActionEnemy.ST_DODGE, "in recovery")
	var punished: Dictionary = _red_hits(grunt, &"light_1")
	assert_eq(punished["outcome"], &"hit", "the punish window: dash and strike lands")
	assert_lt(grunt.hp, grunt.hp_max)
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)


func test_a_dodge_goes_sideways_or_back_never_toward_red() -> void:
	for rng_seed: int in range(1, 6):
		var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
		grunt.rng_seed = rng_seed * 13
		_force(grunt, {"dodge_chance": 1.0, "block_chance": 0.0})
		await _to_circle(grunt)
		var before: Vector3 = grunt.global_position
		_red_swings(&"heavy")
		await _until(grunt, func() -> bool: return grunt.body_state == ActionEnemy.ST_DODGE, 30)
		await _until(grunt, func() -> bool: return grunt.body_state != ActionEnemy.ST_DODGE, 60)
		var delta: Vector3 = grunt.global_position - before
		assert_ge(delta.z, -0.3, "never closer to Red (she is at z 0)")
		assert_gt(delta.length(), 1.5)
		_cleanup_scene()


func _cleanup_scene() -> void:
	free_owned_nodes()
	_all.clear()


func test_a_defending_enemy_holds_no_token() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
	_force(grunt, {"dodge_chance": 1.0, "block_chance": 0.0})
	await _to_circle(grunt)
	_director.tokens.request(grunt.actor_id)
	assert_true(_director.tokens.has_token(grunt.actor_id))
	_red_swings(&"heavy")
	await _until(grunt, func() -> bool: return grunt.body_state == ActionEnemy.ST_DODGE, 30)
	_step(grunt, 1)
	assert_false(_director.tokens.has_token(grunt.actor_id), "a dodging enemy gives its token back")


func test_no_defence_while_a_lamp_flare_runs_or_while_in_hit_stun() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
	_force(grunt, {"dodge_chance": 1.0, "block_chance": 0.0})
	await _to_circle(grunt)
	_director.time.start_flare(5.0, 0.25, [grunt.actor_id] as Array[StringName])
	_red_swings(&"heavy")
	_step(grunt, 90)
	assert_ne(grunt.body_state, ActionEnemy.ST_DODGE, "caught in the glare")
	_director.time.end_flare()
	grunt.apply_hit(_hit())
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)
	_red_swings(&"heavy")
	_step(grunt, 12)
	assert_ne(grunt.body_state, ActionEnemy.ST_DODGE, "in hit-stun")


# ---- block and guard ----

func _brute_blocking() -> ActionEnemy:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 2.0))
	_force(brute, {"block_chance": 1.0, "dodge_chance": 0.0, "read_weight": {"light": 1.0, "heavy": 1.0, "launcher": 1.0, "air": 1.0}})
	await _to_circle(brute)
	_red_swings(&"light_1")
	await _until(brute, func() -> bool: return brute.body_state == ActionEnemy.ST_BLOCK, 60)
	await _until(brute, func() -> bool: return brute.is_guarding(), 30)
	return brute


func test_the_brute_raises_a_guard_that_covers_his_front() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	assert_eq(brute.body_state, ActionEnemy.ST_BLOCK)
	assert_true(brute.is_guarding())
	var guard: Dictionary = brute.snapshot()["guard"]
	assert_true(bool(guard["up"]))
	assert_almost_eq(float(guard["arc_deg"]), 140.0, 0.001)
	assert_almost_eq(float(guard["meter"]), 60.0, 0.001)


func test_a_blocked_light_does_chip_damage_and_no_hit_stun() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	var hp_before: int = brute.hp
	var result: Dictionary = _red_hits(brute, &"light_1")
	assert_eq(result["outcome"], &"blocked")
	assert_eq(brute.hp, hp_before - 1, "8 x 0.15 rounds to nothing, but a block always costs at least 1")
	assert_eq(brute.body_state, ActionEnemy.ST_BLOCK, "no flinch")
	assert_almost_eq(brute.guard.meter, 60.0 - 8.0, 0.001, "the meter drained by the Light's poise damage")
	assert_almost_eq(brute.poise, brute.poise_max, 0.001, "poise untouched")


func test_a_heavy_breaks_the_brutes_guard_and_opens_him_up() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	var result: Dictionary = _red_hits(brute, &"heavy")
	assert_eq(result["outcome"], &"guard_broken")
	assert_eq(brute.body_state, ActionEnemy.ST_STAGGER)
	assert_false(brute.is_armored(), "his armor is off while he is open")
	assert_false(brute.is_guarding())
	_step(brute, 60)
	assert_eq(brute.body_state, ActionEnemy.ST_STAGGER, "still staggered after a second (1.3 s)")
	assert_eq(brute.guard.meter, brute.guard.meter_max, "and a fresh meter for afterwards")
	_step(brute, 30)
	assert_eq(brute.body_state, ActionEnemy.ST_FREE)
	assert_true(brute.is_armored())
	var open: Dictionary = _red_hits(brute, &"heavy")
	assert_ne(open["outcome"], &"blocked", "the guard is gone")


func test_light_light_heavy_is_the_way_into_a_brute() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	assert_eq(_red_hits(brute, &"light_1")["outcome"], &"blocked")
	assert_eq(_red_hits(brute, &"light_2")["outcome"], &"blocked")
	assert_eq(_red_hits(brute, &"heavy")["outcome"], &"guard_broken")


func test_a_launcher_breaks_a_guard_too() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	assert_eq(_red_hits(brute, &"launcher")["outcome"], &"guard_broken")
	assert_false(brute.velocity.y > 1.0, "a guard break does not launch")


func test_three_lights_break_a_grunts_guard() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.9))
	_force(grunt, {"block_chance": 1.0, "dodge_chance": 0.0, "read_weight": {"light": 1.0}})
	await _to_circle(grunt)
	_red_swings(&"light_1")
	await _until(grunt, func() -> bool: return grunt.is_guarding(), 60)
	assert_true(grunt.is_guarding())
	assert_eq(_red_hits(grunt, &"light_1")["outcome"], &"blocked")
	assert_eq(_red_hits(grunt, &"light_2")["outcome"], &"blocked")
	assert_eq(_red_hits(grunt, &"light_1")["outcome"], &"guard_broken", "the third Light empties the 24 point meter")


func test_a_hit_from_behind_goes_through_the_guard() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	_stand.global_position = Vector3(0, 0, 6.0)      # Red dashed round behind him; the Brute faces -Z
	var hp_before: int = brute.hp
	var result: Dictionary = _red_hits(brute, &"light_1")
	assert_ne(result["outcome"], &"blocked", "his back is open: the guard does not cover it")
	assert_eq(brute.hp, hp_before - 8, "full damage, not chip damage")


func test_the_guard_drops_and_the_brute_is_free_again() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	_step(brute, 20)
	assert_true(brute.is_guarding())
	var frames: int = await _until(brute, func() -> bool: return brute.body_state == ActionEnemy.ST_FREE, 160)
	assert_gt(frames, 0, "the guard came down by itself")
	assert_lt(float(frames) * FRAME * 1000.0, 1600.0)
	assert_false(brute.is_guarding())


func test_the_guard_meter_refills_after_a_quiet_moment() -> void:
	var brute: ActionEnemy = await _brute_blocking()
	_red_hits(brute, &"light_1")
	_red_hits(brute, &"light_2")
	assert_almost_eq(brute.guard.meter, 44.0, 0.001)
	_step(brute, 240)
	assert_gt(brute.guard.meter, 50.0, "refilling at 18 per second after a second of quiet")


# ---- hit reactions by type ----

func test_hit_reactions_follow_the_kind_of_hit() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6.0))
	await _to_circle(grunt)
	# a light hit: a short flinch that turns to face Red
	grunt.rotation.y = PI * 0.5
	grunt.apply_hit(_hit({"hitstun_ms": 320.0}))
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)
	_step(grunt, 9)
	var to_red: Vector3 = (Vector3.ZERO - grunt.global_position).normalized()
	assert_gt(grunt.forward().dot(to_red), 0.8, "turned to face Red within about 120 ms")
	_step(grunt, 30)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)
	# a heavy hit: a longer flinch, pushed back
	grunt.apply_hit(_hit({"hitstun_ms": 480.0, "knockback": Vector3(0, 0, 1.4)}))
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)
	var z_before: float = grunt.global_position.z
	_step(grunt, 15)
	assert_gt(grunt.global_position.z, z_before + 0.2, "pushed back along the hit")
	_step(grunt, 30)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)
	# a poise break: the long stagger
	grunt.apply_hit(_hit({"outcome": &"stagger", "hitstun_ms": 700.0, "staggered_target": true}))
	assert_eq(grunt.body_state, ActionEnemy.ST_STAGGER)
	_step(grunt, 60)
	assert_eq(grunt.body_state, ActionEnemy.ST_STAGGER, "1.1 s for a Grunt")
	_step(grunt, 15)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)


func test_the_brute_staggers_for_1_3_seconds() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 8.0))
	await _to_circle(brute)
	brute.apply_hit(_hit({"outcome": &"stagger", "hitstun_ms": 700.0, "staggered_target": true}))
	_step(brute, 70)
	assert_eq(brute.body_state, ActionEnemy.ST_STAGGER)
	_step(brute, 15)
	assert_eq(brute.body_state, ActionEnemy.ST_FREE)


func test_a_flinch_picks_one_of_the_two_chest_or_head_clips() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6.0))
	var seen: Dictionary = {}
	for i: int in range(30):
		seen[grunt._pick_flinch_clip()] = true
	assert_has(seen.keys(), &"hurt")
	assert_has(seen.keys(), &"hurt_head")
	assert_eq(seen.size(), 2)


func test_a_knocked_down_grunt_sometimes_rolls_away_and_is_untouchable_while_it_does() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 5.0))
	await _to_circle(grunt)
	_force(grunt, {"getup_roll_chance": 1.0}, "reactions")
	grunt.apply_hit(_hit({"knockdown": true, "knockback": Vector3(0, 0, 0.5)}))
	assert_eq(grunt.body_state, ActionEnemy.ST_DOWN)
	await _until(grunt, func() -> bool: return grunt.body_state != ActionEnemy.ST_DOWN, 90)
	assert_eq(grunt.body_state, ActionEnemy.ST_DODGE, "rolled away instead of standing up")
	assert_eq(grunt.runner.current_move(), &"getup_roll")
	var before: Vector3 = grunt.global_position
	assert_true(grunt.is_invulnerable())
	await _until(grunt, func() -> bool: return grunt.body_state == ActionEnemy.ST_FREE, 60)
	assert_gt((grunt.global_position - before).length(), 1.0, "it travelled about 1.8 m")
	assert_gt(grunt.global_position.distance_to(Vector3.ZERO), before.distance_to(Vector3.ZERO), "away from Red")


func test_every_get_up_is_untouchable_for_250_ms_and_not_longer() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 5.0))
	await _to_circle(grunt)
	_force(grunt, {"getup_roll_chance": 0.0}, "reactions")
	grunt.apply_hit(_hit({"knockdown": true}))
	await _until(grunt, func() -> bool: return grunt.body_state == ActionEnemy.ST_GETUP, 90)
	assert_true(grunt.is_invulnerable())
	_step(grunt, 12)
	assert_true(grunt.is_invulnerable(), "200 ms in")
	_step(grunt, 6)
	assert_false(grunt.is_invulnerable(), "300 ms in: open again, so there is no endless lock")
	assert_eq(grunt.body_state, ActionEnemy.ST_GETUP)


func test_the_brute_does_not_flinch_but_pulses() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 8.0))
	await _to_circle(brute)
	brute.apply_hit(_hit({"outcome": &"armored", "hitstun_ms": 0.0}))
	assert_eq(brute.body_state, ActionEnemy.ST_FREE)
	assert_gt(brute._flash, 0.5, "the edge light still pulses")


# ---- wind-up floors, tokens, rear attacks ----

func _first_telegraph(enemy: ActionEnemy, max_frames: int = 60 * 14) -> Dictionary:
	var seen: Array[Dictionary] = []
	var on_telegraph: Callable = func(info: Dictionary) -> void: seen.append(info)
	_director.telegraphed.connect(on_telegraph)
	await _until(enemy, func() -> bool: return not seen.is_empty(), max_frames)
	_director.telegraphed.disconnect(on_telegraph)
	return seen[0] if not seen.is_empty() else {}


func test_the_telegraph_says_what_kind_of_cue_to_show() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.6))
	var info: Dictionary = await _first_telegraph(grunt)
	assert_false(info.is_empty())
	assert_eq(info["telegraph_kind"], &"parryable")
	assert_eq(info["move_id"], &"swipe")


func test_the_windup_slider_stretches_but_never_shortens_below_the_floor() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.6))
	_director.feel.set_value("enemy_windup_scale", 0.8)
	var short: Dictionary = await _first_telegraph(grunt)
	assert_false(short.is_empty())
	assert_ge(float(short["impact_in_ms"]), 500.0 - 1.0, "0.8 x 560 would be 448: the floor holds it at 500")
	assert_le(float(short["impact_in_ms"]), 560.0)
	var other_world: ActionEnemy = await _spawn_fresh(GRUNT_SCENE, Vector3(0, 0.1, 1.6))
	_director.feel.set_value("enemy_windup_scale", 2.0)
	var long: Dictionary = await _first_telegraph(other_world)
	assert_almost_eq(float(long["impact_in_ms"]), 1120.0, 2.0, "twice as long")


func _spawn_fresh(scene_path: String, at: Vector3) -> ActionEnemy:
	free_owned_nodes()
	_all.clear()
	return await _setup(scene_path, at)


func test_a_stretched_windup_still_lands_where_it_says() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.6))
	_director.feel.set_value("enemy_windup_scale", 2.0)
	var hits: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	var info: Dictionary = await _first_telegraph(grunt)
	var started_frame: int = 0
	var frames: int = 0
	while hits.is_empty() and frames < 60 * 4:
		_step(grunt, 1)
		frames += 1
	assert_false(hits.is_empty())
	assert_almost_eq(float(frames) * FRAME * 1000.0, float(info["impact_in_ms"]), 60.0, "the hit lands when the telegraph said it would")
	assert_not_null(started_frame)


func test_from_behind_it_uses_the_650_ms_attack() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, -1.6), 0.0)
	var info: Dictionary = await _first_telegraph(grunt)
	assert_false(info.is_empty())
	assert_eq(info["move_id"], &"swipe_flank", "Red faces +Z and the Grunt is behind her")
	assert_ge(float(info["impact_in_ms"]), 650.0)


func test_a_slow_slider_cannot_make_a_rear_attack_shorter_than_650() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, -1.6), 0.0)
	_director.feel.set_value("enemy_windup_scale", 0.8)
	var info: Dictionary = await _first_telegraph(grunt)
	assert_ge(float(info["impact_in_ms"]), 650.0 - 1.0)


func test_two_enemies_never_land_hits_closer_than_450_ms() -> void:
	var first: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(1.2, 0.1, 1.2))
	var second: ActionEnemy = _spawn(GRUNT_SCENE, Vector3(-1.2, 0.1, 1.2))
	_all = [second]
	_stand.hp = 99999
	_stand.hp_max = 99999
	var stamps: Array[float] = []
	var by: Array[StringName] = []
	var clock: Array[float] = [0.0]
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == &"red":
			stamps.append(clock[0])
			by.append(info["attacker"]))
	for frame: int in range(60 * 40):
		clock[0] += FRAME * 1000.0
		_step(first, 1)
	assert_gt(float(stamps.size()), 3.0, "both of them keep attacking")
	var attackers: Dictionary = {}
	for who: StringName in by:
		attackers[who] = true
	assert_eq(attackers.size(), 2, "both landed hits")
	for i: int in range(1, stamps.size()):
		if by[i] != by[i - 1]:
			assert_ge(stamps[i] - stamps[i - 1], 450.0 - FRAME * 1000.0 * 1.5, "hit %d by %s after %s" % [i, by[i], by[i - 1]])


# ---- low health ----

func test_a_wounded_grunt_runs_away_and_gives_its_token_back() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 3.0))
	_force(grunt, {"flee_chance_alone": 1.0, "flee_chance_pack": 1.0}, "low_health")
	await _to_circle(grunt)
	_director.feel.set_value("enemies_attack", true)
	_director.tokens.request(grunt.actor_id)
	grunt.hp = 10
	var frames: int = await _until(grunt, func() -> bool: return grunt.brain.is_fleeing(), 30)
	assert_ge(frames, 0, "under 40% hp it flees")
	_step(grunt, 2)
	assert_false(_director.tokens.has_token(grunt.actor_id), "a fleeing enemy holds no token")
	var before: float = grunt.global_position.distance_to(Vector3.ZERO)
	_step(grunt, 60)
	assert_gt(grunt.global_position.distance_to(Vector3.ZERO), before + 3.0, "about 4.6 m/s")
	var speed: float = Vector2(grunt.velocity.x, grunt.velocity.z).length()
	assert_almost_eq(speed, 4.6, 0.6)
	assert_gt(grunt.forward().dot((grunt.global_position - Vector3.ZERO).normalized()), 0.5, "it faces where it runs")


func test_red_can_catch_a_fleeing_grunt_and_a_hit_knocks_it_down() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 3.0))
	_force(grunt, {"flee_chance_alone": 1.0, "flee_chance_pack": 1.0}, "low_health")
	await _to_circle(grunt)
	_director.feel.set_value("enemies_attack", true)
	grunt.hp = 12
	await _until(grunt, func() -> bool: return grunt.brain.is_fleeing(), 30)
	_step(grunt, 20)
	assert_true(grunt.snapshot()["flee_knockdown"])
	var result: Dictionary = _red_hits(grunt, &"light_1")
	assert_eq(result["outcome"], &"hit")
	assert_true(bool(result["knockdown"]))
	assert_eq(grunt.body_state, ActionEnemy.ST_DOWN, "knocked flat")
	assert_false(grunt.brain.is_fleeing())


func test_a_fleeing_grunt_against_a_wall_turns_and_swipes() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 3.0))
	_force(grunt, {"flee_chance_alone": 1.0, "flee_chance_pack": 1.0}, "low_health")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 4, 1)
	shape_node.shape = box
	wall.add_child(shape_node)
	add_to_root(wall)
	wall.global_position = Vector3(0, 2, 7.0)
	await _to_circle(grunt)
	_director.feel.set_value("enemies_attack", true)
	grunt.hp = 10
	var telegraph: Dictionary = await _first_telegraph(grunt, 60 * 8)
	assert_false(telegraph.is_empty(), "cornered, it fights back with a full wind-up")
	assert_eq(telegraph["move_id"], &"swipe")
	assert_ge(float(telegraph["impact_in_ms"]), 500.0)


func test_a_wounded_grunt_can_flank_to_red_s_back_and_swipe_from_there() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(2.0, 0.1, 3.0))
	_force(grunt, {"flee_chance_alone": 0.0, "flee_chance_pack": 0.0}, "low_health")
	_stand.hp = 99999
	_stand.hp_max = 99999
	await _to_circle(grunt)
	_director.feel.set_value("enemies_attack", true)
	grunt.hp = 10
	await _until(grunt, func() -> bool: return grunt.brain.is_flanking(), 30)
	assert_true(grunt.brain.is_flanking())
	var reached_rear: bool = false
	var held_at: Array[float] = []
	var telegraph: Array[Dictionary] = []
	_director.telegraphed.connect(func(info: Dictionary) -> void: telegraph.append(info))
	for frame: int in range(60 * 6):
		_step(grunt, 1)
		var angle: float = EnemyRules.relative_angle_deg(_stand.global_position, _stand.forward(), grunt.global_position)
		if EnemyRules.in_rear_arc(angle, 120.0):
			reached_rear = true
			if held_at.is_empty() and bool(grunt.last_intent.get("want_token", false)):
				held_at.append(grunt.global_position.distance_to(_stand.global_position))
		if not telegraph.is_empty():
			break
	assert_true(reached_rear, "it ran round to her back")
	assert_false(telegraph.is_empty(), "and attacked from there")
	assert_eq(telegraph[0]["move_id"], &"swipe_flank")
	assert_ge(float(telegraph[0]["impact_in_ms"]), 650.0, "she gets 650 ms or more to react to a hit from behind")
	assert_false(held_at.is_empty(), "it stood behind her, asking for its turn")
	assert_almost_eq(held_at[0], 3.6, 1.0, "waiting about 3.6 m behind her")
	assert_lt(grunt.global_position.distance_to(_stand.global_position), 2.4, "then closed in to strike")


# ---- the Brute's rage ----

func test_the_brute_roars_with_armor_then_hits_harder_and_faster() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 4.5))
	await _to_circle(brute)
	var calm_speed: float = float(brute.data["move_speed_mps"])
	brute.hp = 40
	await _until(brute, func() -> bool: return brute.runner.is_busy() and brute.runner.current_move() == &"enrage", 30)
	assert_eq(brute.runner.current_move(), &"enrage")
	assert_true(brute.is_armored(), "super armor through the roar")
	assert_eq(brute.get_hitbox().active_count(), 0, "a roar does no damage")
	assert_false(brute.is_enraged())
	await _until(brute, func() -> bool: return not brute.runner.is_busy(), 120)
	assert_true(brute.is_enraged())
	assert_false(brute.brain.poise_regen_allowed(), "no poise regeneration")
	assert_almost_eq(calm_speed, 2.0, 0.001)


func test_a_poise_break_cancels_the_roar() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 4.5))
	await _to_circle(brute)
	brute.hp = 40
	await _until(brute, func() -> bool: return brute.runner.is_busy() and brute.runner.current_move() == &"enrage", 30)
	brute.apply_hit(_hit({"outcome": &"stagger", "hitstun_ms": 700.0, "staggered_target": true}))
	assert_false(brute.runner.is_busy(), "the roar is cut")
	assert_eq(brute.body_state, ActionEnemy.ST_STAGGER)
	assert_true(brute.is_enraged())


func test_the_enraged_slam_hurts_15_percent_more() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 2.4))
	_stand.hp = 99999
	_stand.hp_max = 99999
	brute.brain._enraged = true
	_director.feel.set_value("enemies_attack", true)
	var hits: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == &"red":
			hits.append(info))
	var frames: int = 0
	while hits.is_empty() and frames < 60 * 14:
		_step(brute, 1)
		frames += 1
	assert_false(hits.is_empty())
	assert_eq(int(hits[0]["damage"]), 32, "28 x 1.15 = 32")


# ---- allies ----

func test_a_hit_enemy_wakes_its_idle_neighbours() -> void:
	var near: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 12.0))
	_director.feel.set_value("enemies_attack", false)
	var hit_one: ActionEnemy = _spawn(GRUNT_SCENE, Vector3(5.0, 0.1, 11.0))
	var far: ActionEnemy = _spawn(GRUNT_SCENE, Vector3(-20.0, 0.1, 30.0))
	_all = [hit_one, far]
	_director.feel.set_value("enemies_attack", false)
	# idle outside the notice range: nothing happens
	near.global_position = Vector3(0, 0.1, 30.0)
	hit_one.global_position = Vector3(3.0, 0.1, 30.0)
	far.global_position = Vector3(-30.0, 0.1, 30.0)
	_step(near, 5)
	assert_eq(near.brain.state(), EnemyBrain.IDLE)
	assert_eq(far.brain.state(), EnemyBrain.IDLE)
	hit_one.apply_hit(_hit())
	assert_ne(near.brain.state(), EnemyBrain.IDLE, "3 m from the one that was hit: it looks up")
	assert_eq(far.brain.state(), EnemyBrain.IDLE, "33 m away it hears nothing")
	_step(near, 14)
	assert_eq(near.brain.state(), EnemyBrain.APPROACH, "after 150 ms instead of 450")


func test_a_dying_enemy_alerts_allies_within_their_own_radius() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 40.0))
	var brute: ActionEnemy = _spawn(BRUTE_SCENE, Vector3(9.5, 0.1, 40.0))
	var dying: ActionEnemy = _spawn(GRUNT_SCENE, Vector3(10.0, 0.1, 40.0))
	_all = [brute, dying]
	_director.feel.set_value("enemies_attack", false)
	_step(grunt, 3)
	dying.apply_hit(_hit({"damage": 999}))
	assert_eq(brute.brain.state(), EnemyBrain.NOTICE, "the Brute hears within 10 m")
	assert_eq(grunt.brain.state(), EnemyBrain.IDLE, "the Grunt is 10 m away: outside its 9 m")


# ---- the knobs ----

func test_the_health_slider_scales_hp_and_keeps_the_share() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8.0))
	assert_eq(grunt.hp_max, 48)
	grunt.hp = 24
	_director.feel.set_value("enemy_hp_scale", 2.0)
	_step(grunt, 2)
	assert_eq(grunt.hp_max, 96)
	assert_eq(grunt.hp, 48, "half health stays half health")
	_director.feel.set_value("enemy_hp_scale", 1.0)
	_step(grunt, 2)
	assert_eq(grunt.hp_max, 48)


func test_the_attackers_at_once_slider_changes_the_token_cap() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8.0))
	_director.feel.set_value("enemy_max_attackers", 1)
	_step(grunt, 1)
	assert_eq(_director.tokens.max_attackers, 1)
	_director.feel.set_value("enemy_max_attackers", 3)
	_step(grunt, 1)
	assert_eq(_director.tokens.max_attackers, 3)
