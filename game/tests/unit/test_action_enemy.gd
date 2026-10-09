extends TestCase
## ActionEnemy (Grunt and Brute) on a real floor: data, visuals with a fallback, reactions to hits, the
## launch and juggle, a readable parryable wind-up, and the whole thing running on the enemy's own clock.

const FRAME: float = 1.0 / 60.0
const GRUNT_SCENE: String = "res://scenes/actors/enemies/grunt.tscn"
const BRUTE_SCENE: String = "res://scenes/actors/enemies/brute.tscn"

class Stand extends CombatActor:
	var reactions: Array[Dictionary] = []
	var invulnerable_now: bool = false

	func _on_hit_reaction(result: Dictionary) -> void:
		reactions.append(result)

	func is_invulnerable() -> bool:
		return invulnerable_now

	func is_airborne() -> bool:
		return false


var _director: CombatDirector = null
var _stand: Stand = null


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


## A director, a floor, a stand-in for Red at (0,0,0), and the enemy at `at`.
func _setup(scene_path: String, at: Vector3, with_stand: bool = true) -> ActionEnemy:
	_floor()
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	_director.feel.set_value("enemy_damage_scale", 1.0)       # raw damage; the shipped default is tuned lower
	_director.feel.set_value("enemy_windup_scale", 1.0)       # the data's own wind-up lengths
	_director.sync_to_wall_clock = false
	add_to_root(_director)
	_director.set_physics_process(false)
	if with_stand:
		_stand = Stand.new()
		_stand.actor_id = &"red"
		_stand.team = &"player"
		_stand.move_set_id = &"red"
		_stand.hp = 120
		_stand.hp_max = 120
		_stand.height_m = 0.95
		add_to_root(_stand)
		_stand.global_position = Vector3.ZERO
	var scene: PackedScene = load(scene_path) as PackedScene
	var enemy: ActionEnemy = scene.instantiate() as ActionEnemy
	enemy.position = at
	add_to_root(enemy)
	enemy.set_physics_process(false)
	if _stand != null:
		_stand.set_physics_process(false)
	await tree.physics_frame
	await tree.physics_frame
	return enemy


func _step(enemy: ActionEnemy, frames: int, wait_physics: bool = false) -> void:
	for i: int in range(frames):
		if wait_physics:
			await tree.physics_frame
		_director.tick(FRAME)
		enemy.tick(FRAME)


func _hit(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"outcome": &"hit", "damage": 8, "hitstun_ms": 320.0, "knockback": Vector3(0, 0, -0.5), "launch_mps": 0.0,
		"knockdown": false, "hit_stop_ms": 0.0, "poise_after": 22.0, "style_points": 10.0, "juggle_count": 0,
		"launched": false, "air_hit": false, "staggered_target": false}
	result.merge(extra, true)
	return result


# ---- data and visuals ----

func test_grunt_and_brute_load_their_numbers_from_data() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8))
	assert_eq(grunt.hp_max, 48)
	assert_almost_eq(grunt.poise_max, 30.0)
	assert_true(grunt.launchable)
	assert_eq(grunt.team, &"enemy")
	assert_eq(grunt.move_set_id, &"grunt")
	assert_false(grunt.is_armored())
	assert_almost_eq(grunt.height_m, 1.19, 0.001)
	var brute: ActionEnemy = (load(BRUTE_SCENE) as PackedScene).instantiate() as ActionEnemy
	brute.position = Vector3(5, 0.1, 5)
	add_to_root(brute)
	brute.set_physics_process(false)
	assert_eq(brute.hp_max, 220)
	assert_false(brute.launchable)
	assert_true(brute.is_armored(), "the Brute has super armor")
	assert_eq(brute.move_set_id, &"brute")


func test_the_model_loads_by_data_path_or_falls_back_to_a_blockout() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8))
	assert_has(["model", "fallback", "blockout"], grunt.visual_kind())
	assert_not_null(grunt.model_root)
	assert_gt(grunt.model_root.get_child_count(), 0)
	# A path that does not exist must still give a body.
	var lost: ActionEnemy = (load(GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	lost.enemy_id = &"grunt"
	lost.position = Vector3(3, 0.1, 3)
	add_to_root(lost)
	lost.set_physics_process(false)
	assert_not_null(lost.model_root)


func test_blockout_is_used_when_no_model_file_exists() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8))
	grunt.data["model"] = "res://nope/missing.glb"
	grunt.data["fallback_model"] = ""
	grunt.model_root.queue_free()
	grunt._overlay_meshes.clear()
	grunt._build_visual()
	assert_eq(grunt.visual_kind(), "blockout")
	assert_gt(grunt._overlay_meshes.size(), 0, "the colour overlay has meshes to colour")


func test_it_stands_on_the_floor_and_registers() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 8))
	await _step(grunt, 10)
	assert_true(grunt.is_on_floor())
	assert_not_null(_director.get_actor(grunt.actor_id))
	assert_not_null(grunt.get_hurtbox())
	assert_not_null(grunt.get_hitbox())


# ---- behaviour ----

func test_it_notices_walks_up_and_circles() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 10))
	_director.feel.set_value("enemies_attack", false)
	await _step(grunt, 20)
	var start: float = grunt.global_position.distance_to(Vector3.ZERO)
	await _step(grunt, 180)
	var later: float = grunt.global_position.distance_to(Vector3.ZERO)
	assert_lt(later, start - 2.0, "it walked toward the player")
	await _step(grunt, 300)
	assert_gt(later, 0.0)
	assert_ge(grunt.global_position.distance_to(Vector3.ZERO), 1.9, "it keeps its distance while circling")
	assert_eq(grunt.brain.state(), &"circle")
	assert_false(grunt.is_attacking(), "enemies_attack is off")


func test_facing_follows_the_player() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(6, 0.1, 0))
	_director.feel.set_value("enemies_attack", false)
	await _step(grunt, 120)
	var to_player: Vector3 = (Vector3.ZERO - grunt.global_position)
	to_player.y = 0.0
	assert_gt(grunt.forward().dot(to_player.normalized()), 0.9)


func test_the_wind_up_is_telegraphed_long_enough_to_react_and_is_parryable() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.5))
	var telegraphs: Array[Dictionary] = []
	_director.telegraphed.connect(func(info: Dictionary) -> void: telegraphs.append(info))
	var started: Array[Dictionary] = []
	_director.move_started.connect(func(info: Dictionary) -> void: started.append(info))
	var elapsed: int = 0
	while telegraphs.is_empty() and elapsed < 60 * 12:
		await _step(grunt, 1)
		elapsed += 1
	assert_eq(telegraphs.size(), 1, "the attack was announced")
	assert_eq(telegraphs[0]["move_id"], &"swipe")
	assert_true(telegraphs[0]["parryable"])
	assert_ge(float(telegraphs[0]["impact_in_ms"]), 400.0, "at least 400 ms of warning, enough to see it and parry")
	assert_true(grunt.is_attacking())
	assert_eq(grunt.get_hitbox().active_count(), 0, "nothing hurts during the wind-up")
	assert_true(_director.tokens.has_token(grunt.actor_id), "an attack needs a token")


func test_a_swipe_hurts_the_player_after_the_wind_up_and_the_token_comes_back() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.4))
	var hits: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	var frames: int = 0
	while frames < 60 * 8:
		await _step(grunt, 1, true)
		frames += 1
		if not hits.is_empty() and not grunt.is_attacking():
			break
	assert_eq(hits.size(), 1, "one swing, one hit")
	assert_eq(hits[0]["move_id"], &"swipe")
	assert_eq(_stand.hp, 120 - 10)
	assert_false(_director.tokens.has_token(grunt.actor_id), "the token is given back when the move ends")


func test_hit_stop_pauses_the_enemys_attack_clock() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.5))
	var frames: int = 0
	while not grunt.is_attacking() and frames < 60 * 12:
		await _step(grunt, 1)
		frames += 1
	await _step(grunt, 10)
	var ms_before: float = grunt.runner.elapsed_ms()
	_director.time.add_hit_stop([grunt.actor_id] as Array[StringName], 200.0)
	await _step(grunt, 10)
	assert_almost_eq(grunt.runner.elapsed_ms(), ms_before, 0.01, "frozen for the 160 ms that passed")
	await _step(grunt, 10)
	assert_gt(grunt.runner.elapsed_ms(), ms_before + 50.0)


func test_a_lamp_flare_slows_the_wind_up() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.5))
	var frames: int = 0
	while not grunt.is_attacking() and frames < 60 * 12:
		await _step(grunt, 1)
		frames += 1
	_director.time.start_flare(5.0, 0.25, [grunt.actor_id] as Array[StringName])
	var before: float = grunt.runner.elapsed_ms()
	await _step(grunt, 40)
	var gained: float = grunt.runner.elapsed_ms() - before
	assert_almost_eq(gained, 40.0 * FRAME * 1000.0 * 0.25, 5.0, "a quarter of the time passed for it")


# ---- reactions ----

func test_a_hit_causes_hitstun_then_it_recovers() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6))
	_director.feel.set_value("enemies_attack", false)
	await _step(grunt, 5)
	grunt.apply_hit(_hit())
	assert_eq(grunt.hp, 40)
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)
	await _step(grunt, 10)
	assert_eq(grunt.body_state, ActionEnemy.ST_HURT)
	await _step(grunt, 15)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE, "320 ms later it is back")


func test_a_hit_cuts_off_an_attack_and_turns_the_hitbox_off() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.5))
	var frames: int = 0
	while not grunt.is_attacking() and frames < 60 * 12:
		await _step(grunt, 1)
		frames += 1
	grunt.apply_hit(_hit())
	assert_false(grunt.is_attacking())
	assert_eq(grunt.get_hitbox().active_count(), 0)
	assert_false(_director.tokens.has_token(grunt.actor_id))


func test_armored_hits_do_not_flinch() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 8))
	_director.feel.set_value("enemies_attack", false)
	await _step(brute, 5)
	brute.apply_hit(_hit({"outcome": &"armored", "hitstun_ms": 0.0}))
	assert_eq(brute.body_state, ActionEnemy.ST_FREE)
	assert_eq(brute.hp, 220 - 8)


func test_a_poise_break_staggers_and_drops_the_armor() -> void:
	var brute: ActionEnemy = await _setup(BRUTE_SCENE, Vector3(0, 0.1, 8))
	_director.feel.set_value("enemies_attack", false)
	await _step(brute, 5)
	assert_true(brute.is_armored())
	brute.apply_hit(_hit({"outcome": &"stagger", "hitstun_ms": 1100.0, "poise_after": 90.0, "staggered_target": true}))
	assert_eq(brute.body_state, ActionEnemy.ST_STAGGER)
	assert_false(brute.is_armored(), "free hits while it is staggered")
	await _step(brute, 80)
	assert_eq(brute.body_state, ActionEnemy.ST_FREE)
	assert_true(brute.is_armored())


func test_a_launch_sends_it_up_it_falls_and_gets_up() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6))
	_director.feel.set_value("enemies_attack", false)
	await _step(grunt, 5)
	grunt.apply_hit(_hit({"launch_mps": 11.0, "launched": true, "juggle_count": 1, "outcome": &"hit"}))
	assert_eq(grunt.body_state, ActionEnemy.ST_LAUNCHED)
	var peak: float = 0.0
	var frames: int = 0
	while grunt.body_state == ActionEnemy.ST_LAUNCHED and frames < 200:
		await _step(grunt, 1)
		peak = maxf(peak, grunt.global_position.y)
		frames += 1
	assert_gt(peak, 1.5, "a real launch height")
	assert_lt(peak, 4.0)
	assert_eq(grunt.body_state, ActionEnemy.ST_DOWN)
	assert_eq(grunt.juggle_count, 0, "landing ends the juggle")
	await _step(grunt, 70)
	assert_eq(grunt.body_state, ActionEnemy.ST_GETUP)
	assert_true(grunt.is_invulnerable(), "no hits while getting up")
	await _step(grunt, 50)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)


func test_air_hits_hold_it_up_longer_than_a_plain_fall() -> void:
	var plain: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6))
	_director.feel.set_value("enemies_attack", false)
	await _step(plain, 5)
	plain.apply_hit(_hit({"launch_mps": 11.0, "launched": true, "juggle_count": 1}))
	var plain_frames: int = 0
	while plain.body_state == ActionEnemy.ST_LAUNCHED and plain_frames < 300:
		await _step(plain, 1)
		plain_frames += 1
	var juggled: ActionEnemy = (load(GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	juggled.position = Vector3(8, 0.1, 6)
	juggled.rng_seed = 9
	add_to_root(juggled)
	juggled.set_physics_process(false)
	await tree.physics_frame
	await _step(juggled, 5)
	juggled.apply_hit(_hit({"launch_mps": 11.0, "launched": true, "juggle_count": 1}))
	var juggled_frames: int = 0
	var hits_given: int = 0
	while juggled.body_state == ActionEnemy.ST_LAUNCHED and juggled_frames < 600:
		await _step(juggled, 1)
		juggled_frames += 1
		if juggled_frames in [28, 52, 76, 100] and juggled.body_state == ActionEnemy.ST_LAUNCHED:
			hits_given += 1
			juggled.apply_hit(_hit({"launch_mps": 4.2, "launched": true, "air_hit": true, "juggle_count": 1 + hits_given, "damage": 7}))
	assert_eq(hits_given, 4, "four air hits all landed on a target still in the air")
	assert_gt(juggled_frames, plain_frames + 60, "the float keeps it up well past a plain fall")


func test_a_slam_knocks_it_down_fast() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6))
	_director.feel.set_value("enemies_attack", false)
	await _step(grunt, 5)
	grunt.apply_hit(_hit({"launch_mps": 11.0, "launched": true, "juggle_count": 1}))
	await _step(grunt, 20)
	grunt.apply_hit(_hit({"knockdown": true, "air_hit": true, "juggle_count": 2}))
	var frames: int = 0
	while grunt.body_state == ActionEnemy.ST_LAUNCHED and frames < 100:
		await _step(grunt, 1)
		frames += 1
	assert_lt(frames, 30, "slammed down within half a second")
	assert_eq(grunt.body_state, ActionEnemy.ST_DOWN)


func test_a_perfect_parry_staggers_it_for_a_long_moment_and_a_parry_recoils_it() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 1.5))
	var frames: int = 0
	while not grunt.is_attacking() and frames < 60 * 12:
		await _step(grunt, 1)
		frames += 1
	grunt.on_parried({"outcome": &"perfect_parry"})
	assert_eq(grunt.body_state, ActionEnemy.ST_STAGGER)
	assert_false(grunt.is_attacking())
	assert_eq(grunt.get_hitbox().active_count(), 0)
	await _step(grunt, 60)
	assert_eq(grunt.body_state, ActionEnemy.ST_STAGGER, "still staggered after a second")
	await _step(grunt, 50)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)
	grunt.on_parried({"outcome": &"parried"})
	assert_eq(grunt.body_state, ActionEnemy.ST_RECOIL)
	await _step(grunt, 50)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE, "a plain parry recoils for less than a second")


func test_death_and_respawn() -> void:
	var grunt: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(0, 0.1, 6))
	_director.feel.set_value("enemies_attack", false)
	var deaths: Array[StringName] = []
	_director.actor_died.connect(func(id: StringName) -> void: deaths.append(id))
	await _step(grunt, 5)
	grunt.apply_hit(_hit({"damage": 999}))
	assert_true(grunt.dead)
	assert_eq(grunt.body_state, ActionEnemy.ST_DEAD)
	assert_eq(deaths.size(), 1)
	grunt._respawn_s = 0.5
	grunt.global_position = Vector3(3, 0.1, 3)
	await _step(grunt, 20)
	assert_true(grunt.dead, "still down")
	await _step(grunt, 20)
	assert_false(grunt.dead)
	assert_eq(grunt.hp, grunt.hp_max)
	assert_eq(grunt.body_state, ActionEnemy.ST_FREE)
	assert_almost_eq(grunt.global_position.x, 0.0, 0.01)
	assert_almost_eq(grunt.global_position.z, 6.0, 0.01, "back at its spawn")


func test_six_enemies_do_not_all_attack_at_once() -> void:
	var first: ActionEnemy = await _setup(GRUNT_SCENE, Vector3(1.5, 0.1, 0))
	var enemies: Array[ActionEnemy] = [first]
	for i: int in range(5):
		var extra: ActionEnemy = (load(GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
		extra.actor_id = StringName("grunt_extra_%d" % i)
		extra.rng_seed = 100 + i
		extra.position = Vector3(1.6 * cos(float(i)), 0.1, 1.6 * sin(float(i)) + 0.5)
		add_to_root(extra)
		extra.set_physics_process(false)
		enemies.append(extra)
	await tree.physics_frame
	var most: int = 0
	for frame: int in range(60 * 10):
		_director.tick(FRAME)
		var attacking: int = 0
		for enemy: ActionEnemy in enemies:
			enemy.tick(FRAME)
			if enemy.is_attacking():
				attacking += 1
		most = maxi(most, attacking)
	assert_le(most, 2, "attack tokens cap it at max_attackers")
	assert_ge(most, 1, "and somebody did attack")
