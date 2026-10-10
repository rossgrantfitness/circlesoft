extends TestCase
## B8 (docs/bug_log.md): a Signals drone left the level in the J4 Stand and in J5 and the engine then errored every frame
## ("Object went too far away", about 26,000 lines in one bot run). The cause: two enemies spawned on exactly the same spot (a
## wave entry of count 2 at one marker, no spread) overlap perfectly, the physics engine's push-apart has no direction, and it
## throws both along one axis, harder every frame. The fix has two layers, both checked here: a new enemy steps clear of an
## ally it overlaps, and an enemy that does leave the playable space (not a number, below the floor, above the ceiling, too far
## away) is taken out of play cleanly and counts as defeated (enemies.json `play_bounds`).

const ROOM_FIGHT: String = "enc_j1_pair"
const ROOM_ID: String = "junk_j1"
const ROOM_SPAWN: String = "from_market"
const HOVER_SPOT: Vector3 = Vector3(10.0, 0.1, 10.0)       # a marker on the floor, like w3_signals_drone_1 (y 0.1)

var _kit: HackKit = null
var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _old_dir: String = ""
var _dir: String = ""


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_old_dir = str(_manager.get("save_dir"))
	_dir = "user://test_enemy_bounds_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_dir)
	_manager.set("rooms_data_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	Placements.extra_job_ids = []
	Placements.extra_scene_ids = []
	InputSorting.revert()
	SandboxPauseGate.clear(tree)
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


func _arena() -> void:
	_kit = HackKit.new(self)
	await _kit.arena(true)


## A solid box on the world layer (a wall or a ceiling).
func _slab(centre: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	add_to_root(body)
	body.global_position = centre


func _hit(extra: Dictionary) -> Dictionary:
	var result: Dictionary = {"outcome": &"hit", "damage": 1, "hitstun_ms": 320.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
		"knockdown": false, "hit_stop_ms": 0.0, "poise_after": 0.0, "style_points": 0.0, "juggle_count": 0,
		"launched": false, "air_hit": false, "staggered_target": false}
	result.merge(extra, true)
	return result


## True while the enemy is somewhere sane: a real position, inside the arena's walls and ceiling, above the kill height.
func _in_arena(enemy: ActionEnemy) -> bool:
	var at: Vector3 = enemy.global_position
	return is_finite(at.x) and is_finite(at.y) and is_finite(at.z) and absf(at.x) < 120.0 and absf(at.z) < 120.0 \
			and at.y > -5.0 and at.y < 40.0


# ---- the cause: enemies spawned on one spot ----

func test_two_drones_spawned_on_one_spot_step_apart_and_stay_in_the_arena() -> void:
	await _arena()
	var first: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	var second: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(1)
	var flat: Vector3 = first.global_position - second.global_position
	flat.y = 0.0
	assert_gt(flat.length(), first.radius_m + second.radius_m - 0.001, "the second drone stepped clear of the first")
	var worst: float = 0.0
	for i: int in 40:
		await _kit.frames(10)
		worst = maxf(worst, maxf(first.global_position.length(), second.global_position.length()))
		assert_true(_in_arena(first) and _in_arena(second), "both drones are still in the arena after %d frames" % ((i + 1) * 10))
	assert_lt(worst, 60.0, "neither drone drifted far from the spot it spawned on (B8 sent them 1 km away in a few frames)")
	assert_false(first.dead or second.dead, "nobody was removed: the root cause is gone, not just the symptom")
	assert_eq(first.escapes + second.escapes, 0, "the safety net never had to act")


func test_three_grunts_spawned_on_one_spot_do_not_launch_each_other() -> void:
	await _arena()
	var cops: Array[ActionEnemy] = []
	for i: int in 3:
		cops.append(_kit.spawn(HackKit.GRUNT_SCENE, Vector3(20.0, 0.1, 20.0)))
	for i: int in 12:
		await _kit.frames(5)
		for cop: ActionEnemy in cops:
			assert_lt(cop.global_position.y, 1.0, "a cop stays on the floor (stacked bodies used to shoot upward at 12 m per 5 frames)")
			assert_true(_in_arena(cop))


func test_spawning_on_a_spot_with_a_dead_ally_does_not_shove() -> void:
	await _arena()
	var corpse: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(1)
	corpse.apply_hit(_hit({"damage": 999}))
	var fresh: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(1)
	assert_almost_eq(fresh.global_position.x, HOVER_SPOT.x, 0.001, "a dead body does not push a new spawn around")


func test_a_static_turret_is_not_nudged_off_its_mount() -> void:
	await _arena()
	var blocker: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(30.0, 0.1, 30.0))
	var turret: ActionEnemy = _kit.spawn(HackKit.TURRET_SCENE, Vector3(30.0, 0.1, 30.0))
	await _kit.frames(1)
	assert_almost_eq(turret.global_position.x, 30.0, 0.001, "bolted down")
	assert_almost_eq(turret.global_position.z, 30.0, 0.001, "bolted down")
	assert_not_null(blocker)


# ---- the engine-side trigger: huge pushes next to walls ----

func test_a_drone_hit_with_a_huge_launch_beside_a_wall_and_ceiling_stays_in_bounds_or_is_removed() -> void:
	await _arena()
	_slab(Vector3(15.0, 4.0, 10.0), Vector3(1.0, 8.0, 40.0))       # a wall 5 m east of the drone
	_slab(Vector3(10.0, 7.0, 10.0), Vector3(40.0, 1.0, 40.0))      # a low ceiling
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(10.0, 0.1, 10.0))
	await _kit.frames(30)
	# the heaviest thing in the game, launched hard into the wall and up into the ceiling (a loader or colossus hit)
	drone.apply_hit(_hit({"damage": 1, "launch_mps": 400.0, "knockback": Vector3(60.0, 0.0, 0.0), "launched": true, "air_hit": true}))
	for i: int in 30:
		await _kit.frames(10)
		assert_true(_in_arena(drone), "after %d frames the drone is in the arena (or parked back at its spawn)" % ((i + 1) * 10))
	assert_eq(drone.play_area_breach(), &"", "and it is not past any limit")


func test_a_drone_launched_into_open_sky_is_removed_not_lost() -> void:
	await _arena()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(30)
	drone.apply_hit(_hit({"damage": 1, "launch_mps": 400.0, "knockback": Vector3(60.0, 0.0, 0.0), "launched": true, "air_hit": true}))
	await _kit.until(func() -> bool: return drone.dead, 120)
	assert_true(drone.dead, "a launch that would carry it 3 km up takes it out of play (it counts as defeated)")
	assert_eq(drone.escapes, 1)
	for i: int in 10:
		await _kit.frames(10)
		assert_true(_in_arena(drone), "and it stays parked on the level")


func test_emp_on_a_drone_pressed_against_a_wall_stays_in_bounds() -> void:
	await _arena()
	_slab(Vector3(8.0, 4.0, 6.0), Vector3(1.0, 8.0, 20.0))
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var first: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(6.5, 0.1, 6.0))
	var second: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(6.5, 0.1, 6.0))
	await _kit.settle()
	await _kit.frames(20)
	await _kit.tap_hack()
	for i: int in 30:
		await _kit.frames(10)
		assert_true(_in_arena(first) and _in_arena(second), "both drones are in the arena %d frames after the EMP" % ((i + 1) * 10))


# ---- the safety net ----

func test_an_enemy_with_a_speed_that_is_not_a_number_is_removed_cleanly() -> void:
	await _arena()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	var deaths: Array[StringName] = []
	_kit.director.actor_died.connect(func(id: StringName) -> void: deaths.append(id))
	await _kit.frames(10)
	drone.velocity = Vector3(NAN, 0.0, 0.0)
	assert_eq(drone.play_area_breach(), ActionEnemy.REASON_NOT_FINITE)
	await _kit.frames(2)
	assert_true(drone.dead, "counted as defeated")
	assert_true(_in_arena(drone), "put back on the level")
	assert_true(is_finite(drone.velocity.x) and is_finite(drone.velocity.y) and is_finite(drone.velocity.z), "no stray speed left")
	assert_lt(drone.velocity.length(), 2.0, "and it is not going anywhere")
	assert_eq(deaths.size(), 1, "the director saw exactly one death")
	assert_eq(drone.escapes, 1)


func test_an_enemy_below_the_kill_height_is_removed_and_counted() -> void:
	await _arena()
	var cop: ActionEnemy = _kit.grunt(Vector3(12.0, 0.1, 12.0))
	var reasons: Array[StringName] = []
	cop.left_play_area.connect(func(reason: StringName) -> void: reasons.append(reason))
	await _kit.frames(10)
	cop.global_position = Vector3(12.0, -80.0, 12.0)
	await _kit.frames(2)
	assert_true(cop.dead)
	assert_eq(reasons, [ActionEnemy.REASON_BELOW_FLOOR] as Array[StringName])
	assert_almost_eq(cop.global_position.y, 0.1, 0.5, "back on its spawn spot")


func test_an_enemy_far_above_or_far_away_is_removed() -> void:
	await _arena()
	var high: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(-20.0, 0.1, 10.0))
	var far: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(20.0, 0.1, -10.0))
	await _kit.frames(10)
	high.global_position = high.global_position + Vector3(0.0, 500.0, 0.0)
	far.global_position = far.global_position + Vector3(1.2e6, 0.0, 0.0)       # the 1.2 km jump in the bot log, and more
	assert_eq(high.play_area_breach(), ActionEnemy.REASON_ABOVE_CEILING)
	assert_eq(far.play_area_breach(), ActionEnemy.REASON_TOO_FAR)
	await _kit.frames(2)
	assert_true(high.dead and far.dead, "both counted as defeated")
	assert_true(_in_arena(high) and _in_arena(far))
	for i: int in 20:
		await _kit.frames(10)
		assert_true(_in_arena(far), "and it stays put: no body is left to fly off again")


func test_an_enemy_inside_the_limits_is_left_alone() -> void:
	await _arena()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(30)
	assert_eq(drone.play_area_breach(), &"")
	assert_false(drone.dead)
	drone.global_position = HOVER_SPOT + Vector3(100.0, 5.0, 100.0)       # a big arena is fine
	assert_eq(drone.play_area_breach(), &"", "a fight across a wide room is not an escape")


func test_a_removed_hijacked_drone_is_no_longer_hijacked() -> void:
	await _arena()
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, HOVER_SPOT)
	await _kit.frames(10)
	assert_true(drone.hijackable.begin_hijack(_kit.red, 10.0), "Overclock took the drone")
	drone.global_position = Vector3(0.0, -500.0, 0.0)
	await _kit.frames(2)
	assert_true(drone.dead)
	assert_null(drone.hijacked_by)


# ---- in the real rooms ----

func _boot(room_id: String, spawn: String) -> ActionRoom:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_manager.set("save_dir", _dir)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.call("reset")
	_router.call("start_at", room_id, spawn)
	for i: int in 240:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func test_in_a_real_room_two_drones_on_one_marker_stay_in_the_level() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	if room == null:
		return
	room.hero.global_position = Vector3(40.0, 0.1, 40.0)
	var pair: Array[Node3D] = []
	for i: int in 2:
		pair.append(room.spawn_enemy("signals_drone", Vector3(56.0, 0.1, 42.0)))      # w3_signals_drone_1, both on it
	for i: int in 300:
		await tree.physics_frame
		for drone: Node3D in pair:
			assert_lt(drone.global_position.length(), 600.0, "the drone is still in the junkyard")
	for drone: Node3D in pair:
		assert_false(bool(drone.get("dead")), "and nobody had to be removed")


func test_in_a_real_fight_an_escaped_enemy_counts_as_defeated_and_the_fight_clears() -> void:
	var room: ActionRoom = await _boot(ROOM_ID, ROOM_SPAWN)
	if room == null:
		return
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	room.hero.global_position = Vector3(30.0, 0.1, 22.0)
	room.hero.velocity = Vector3.ZERO
	runner.tick(0.1)
	assert_eq(runner.state_of(ROOM_FIGHT), "running", "walking into the pound starts the pair")
	var cops: Array[Node3D] = runner.enemies_of(ROOM_FIGHT)
	assert_eq(cops.size(), 2, "two cops")
	if cops.size() < 2:
		return
	(cops[0] as CombatActor).apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})
	cops[1].global_position = Vector3(5.0e6, 40.0, -3.0e6)      # the second cop is thrown out of the level
	for i: int in 4:
		await tree.physics_frame
	runner.tick(0.1)
	assert_true(bool(cops[1].get("dead")), "the escaped cop was removed")
	assert_eq(runner.enemies_of(ROOM_FIGHT).size(), 0, "so the encounter has nobody left to wait for")
	assert_eq(runner.state_of(ROOM_FIGHT), "cleared", "and the fight clears")
