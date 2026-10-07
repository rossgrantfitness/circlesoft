extends TestCase
## Visible map enemies: they patrol, notice Red in front of them (and not through walls), chase at
## their own speed, give up out of breath, and start a fight on touch with the first-turn rule from
## who faced whom. After a fight Red blinks and cannot be caught; regular enemies come back with the
## room, story fights and bosses stay beaten through a flag.

const TICK: float = 1.0 / 60.0

var _room: FieldRoom = null
var _state: Node = null
var _requests: Array = []


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_requests = []


func after_each() -> void:
	_state.call("reset")


func _load(path: String) -> FieldRoom:
	_room = ExplorationKit.load_room(self, path)
	_room.field_battle_requested.connect(func(encounter: String, enemy_id: String, first_turn: String) -> void:
		_requests.append([encounter, enemy_id, first_turn]))
	for enemy: MapEnemy in _room.encounters.enemies():
		enemy.auto_step = false
	return _room


func _grunt() -> MapEnemy:
	return _room.get_node("Grunt") as MapEnemy


## Runs the enemy (and the physics world) for `seconds`; stops early if `until` returns true.
func _run(enemy: MapEnemy, seconds: float, until: Callable = Callable()) -> float:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await tree.physics_frame
		enemy.step(TICK)
		elapsed += TICK
		if until.is_valid() and bool(until.call()):
			break
	return elapsed


func _place_red(spot: Vector3, facing_yaw_toward: Vector3) -> void:
	var player: PlayerController = _room.player
	player.global_position = Vector3(spot.x, 0.02, spot.z)
	player.velocity = Vector3.ZERO
	var direction: Vector3 = facing_yaw_toward - spot
	direction.y = 0.0
	player.rotation.y = PlayerMotion.yaw_for_direction(direction.normalized())


func _flat_speed(enemy: MapEnemy, from_point: Vector3, seconds: float) -> float:
	var moved: Vector3 = enemy.global_position - from_point
	moved.y = 0.0
	return moved.length() / seconds


# ---- data ----

func test_speeds_and_sight_come_from_the_enemys_field_block() -> void:
	_load(ExplorationKit.TEST_A)
	var field: Dictionary = MapEnemy.enemy_definition("signals_grunt")["field"]
	var grunt: MapEnemy = _grunt()
	assert_eq(grunt.enemy_id, "signals_grunt")
	assert_eq(grunt.encounter_id, "grunt_pair")
	assert_almost_eq(grunt.walk_speed, float(field["walk_speed"]))
	assert_almost_eq(grunt.chase_speed, float(field["chase_speed"]))
	assert_almost_eq(grunt.sight_m, float(field["sight_m"]))
	assert_almost_eq(grunt.give_up_s, float(field["give_up_s"]))
	assert_not_null(grunt.get_node("Visual/Model") if grunt.has_node("Visual/Model") else grunt.get_node("Visual").get_child(0), "uses the existing placeholder model")
	var guard: MapEnemy = ExplorationKit.load_room(self, ExplorationKit.TEST_B).get_node("Guard") as MapEnemy
	assert_eq(guard.enemy_id, "whistle_blower")
	assert_almost_eq(guard.chase_speed, float(MapEnemy.enemy_definition("whistle_blower")["field"]["chase_speed"]))


func test_enemies_do_not_collide_with_red_or_the_crew() -> void:
	_load(ExplorationKit.TEST_A)
	assert_eq(_grunt().collision_layer, 4)
	assert_eq(_grunt().collision_layer & _room.player.collision_mask, 0, "Red passes through them (the touch is the fight)")
	assert_eq(_grunt().collision_mask, 1, "walls stop them")


# ---- patrol ----

func test_it_patrols_its_route_at_walk_speed_and_pauses_at_each_point() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.sight_m = 0.5
	var route: Array[Vector3] = grunt.get_route()
	assert_eq(route.size(), 4)
	_place_red(Vector3(-5.0, 0.0, 3.5), Vector3(0.0, 0.0, 0.0))
	await ExplorationKit.ticks(self, 3)
	await _run(grunt, 1.2)  # it pauses at its first point before setting off
	var start: Vector3 = grunt.global_position
	await _run(grunt, 1.0)
	assert_almost_eq(_flat_speed(grunt, start, 1.0), grunt.walk_speed, 0.35, "walks at walk_speed")
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL)
	var visited: Array[bool] = [false, false, false, false]
	for i: int in 60 * 14:
		await tree.physics_frame
		grunt.step(TICK)
		for p: int in route.size():
			if Vector2(grunt.global_position.x - route[p].x, grunt.global_position.z - route[p].z).length() < 0.4:
				visited[p] = true
	assert_eq(visited, [true, true, true, true] as Array[bool], "all four points visited in turn")
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL)


func test_a_stationary_enemy_just_stands_at_home() -> void:
	var room_b: FieldRoom = _load(ExplorationKit.TEST_B)
	var guard: MapEnemy = room_b.get_node("Guard") as MapEnemy
	assert_true(guard.get_route().is_empty())
	_place_red(Vector3(-4.0, 0.0, 3.0), Vector3(0.0, 0.0, 0.0))
	var home: Vector3 = guard.global_position
	await _run(guard, 2.0)
	assert_lt(guard.global_position.distance_to(home), 0.05)


# ---- noticing and chasing ----

func test_it_chases_at_chase_speed_once_red_is_in_front_of_it_within_sight() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.rotation.y = deg_to_rad(90.0)  # looks east
	_place_red(Vector3(5.0, 0.0, 1.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	var states: Array = []
	grunt.state_changed.connect(func(s: MapEnemy.State) -> void: states.append(s))
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.CHASE, "4.5 m ahead, within sight")
	var from_point: Vector3 = grunt.global_position
	await _run(grunt, 0.5)
	assert_almost_eq(_flat_speed(grunt, from_point, 0.5), grunt.chase_speed, 0.5, "runs at chase_speed")
	assert_gt(grunt.chase_speed, grunt.walk_speed)


func test_it_does_not_see_red_behind_it_unless_she_is_very_close() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.rotation.y = deg_to_rad(90.0)
	_place_red(Vector3(-3.0, 0.0, 1.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL, "3.5 m behind its back: not noticed")
	_place_red(Vector3(-0.6, 0.0, 1.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.global_position = Vector3(0.5, 0.0, 1.0)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.CHASE, "1.1 m behind: close enough to hear")


func test_it_does_not_see_red_beyond_its_sight_range() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.rotation.y = deg_to_rad(90.0)
	_place_red(Vector3(0.5 + grunt.sight_m + 1.0, 0.0, 1.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL)


func test_a_wall_between_them_blocks_the_view() -> void:
	var room_b: FieldRoom = _load(ExplorationKit.TEST_B)
	var guard: MapEnemy = room_b.get_node("Guard") as MapEnemy
	guard.rotation.y = deg_to_rad(-90.0)  # looks west, at the fence
	_place_red(Vector3(-0.8, 0.0, -0.8), Vector3(4.6, 0.0, -0.8))
	await ExplorationKit.ticks(self, 3)
	guard.step(TICK)
	assert_eq(guard.get_state(), MapEnemy.State.PATROL, "the fence is in the way (5.4 m, in its cone)")
	_place_red(Vector3(1.8, 0.0, -0.8), Vector3(4.6, 0.0, -0.8))
	await ExplorationKit.ticks(self, 3)
	guard.step(TICK)
	assert_eq(guard.get_state(), MapEnemy.State.CHASE, "clear view once she is on its side")


func test_it_gives_up_when_red_outruns_it_then_rests_then_patrols_and_ignores_her_for_a_moment() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.sight_m = 2.0  # a small room: keep the "lost her" distance (sight x 1.4) short
	grunt.rotation.y = deg_to_rad(90.0)
	_place_red(Vector3(2.0, 0.0, 1.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.CHASE)
	# Red is far gone (beyond sight times the lose multiplier) and stays out of sight.
	_place_red(Vector3(9.5, 0.0, -3.0), Vector3(0.5, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	var cfg: Dictionary = DataDB.get_dict("world/map_enemies")
	var give_up_after: float = await _run(grunt, grunt.give_up_s + 1.5, func() -> bool: return grunt.get_state() == MapEnemy.State.GIVE_UP)
	assert_eq(grunt.get_state(), MapEnemy.State.GIVE_UP)
	assert_almost_eq(give_up_after, grunt.give_up_s, 0.35, "gives up after give_up_s without seeing her")
	var rested: float = await _run(grunt, 5.0, func() -> bool: return grunt.get_state() == MapEnemy.State.PATROL)
	assert_almost_eq(rested, float(cfg["rest_s"]), 0.3, "stands out of breath for rest_s")
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL)
	# Red walks right back into view: it ignores her until the cooldown has run out.
	grunt.rotation.y = deg_to_rad(90.0)
	_place_red(grunt.global_position + Vector3(1.6, 0.0, 0.0), grunt.global_position)
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.PATROL, "still catching its breath, not chasing yet")
	await _run(grunt, float(cfg["reaggro_cooldown_s"]) + 0.5)
	_place_red(grunt.global_position + Vector3(1.6, 0.0, 0.0), grunt.global_position)
	grunt.rotation.y = deg_to_rad(90.0)
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(grunt.get_state(), MapEnemy.State.CHASE, "and chases again afterwards")


# ---- touching, first turn ----

func test_touching_red_asks_for_the_encounter_with_the_first_turn_from_facing() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	# 1) From behind: the grunt looks east, Red walks up behind it looking east: the party goes first.
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	grunt.rotation.y = deg_to_rad(90.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(3.0, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(_requests, [["grunt_pair", "test_a_grunt", "party"]], "a free first turn for the party")
	assert_true(_room.encounters.is_fighting())


func test_getting_caught_from_behind_means_the_enemies_go_first() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	grunt.rotation.y = deg_to_rad(-90.0)  # looks west, at Red
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(0.0, 0.0, 1.0))  # she looks west too: running away
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][2], "enemies")


func test_meeting_face_to_face_is_a_normal_start() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	grunt.rotation.y = deg_to_rad(-90.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(_requests[0][2], "normal")


func test_only_one_fight_at_a_time_and_nothing_while_red_is_talking() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	_room.player.frozen = true
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_true(_requests.is_empty(), "a frozen Red (a bubble, the menu) cannot be caught")
	_room.player.frozen = false
	grunt.step(TICK)
	grunt.step(TICK)
	assert_eq(_requests.size(), 1, "one request, however long it touches")


# ---- blink ----

func test_a_blinking_red_cannot_be_caught_and_is_not_hunted() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	_place_red(Vector3(1.6, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	_room.player.start_blink()
	assert_true(_room.player.is_blinking())
	assert_false(_room.player.is_catchable())
	await ExplorationKit.ticks(self, 2)
	for i: int in 30:
		grunt.step(TICK)
	assert_true(_requests.is_empty(), "no touch while she blinks")
	assert_ne(grunt.get_state(), MapEnemy.State.CHASE, "and it does not hunt her")
	grunt.global_position = _room.player.global_position + Vector3(0.3, 0.0, 0.0)
	var blink: float = FieldTuning.from_db(tree.root.get_node("DataDB")).blink_time_s
	_room.player.tick_blink(blink + 0.1)
	assert_false(_room.player.is_blinking())
	grunt.reset_touch()
	grunt.step(TICK)
	assert_eq(_requests.size(), 1, "caught again once the blink is over")


func test_the_blink_lasts_blink_time_and_flickers_the_model() -> void:
	_load(ExplorationKit.TEST_A)
	var blink: float = FieldTuning.from_db(tree.root.get_node("DataDB")).blink_time_s
	var flash: float = FieldTuning.from_db(tree.root.get_node("DataDB")).blink_flash_s
	var visual: Node3D = _room.player.get_node("Visual") as Node3D
	_room.player.start_blink()
	assert_almost_eq(_room.player.get_blink_left(), blink, 0.001)
	var seen_hidden: bool = false
	var seen_shown: bool = false
	var elapsed: float = 0.0
	while elapsed < blink - 0.05:
		_room.player.tick_blink(flash * 0.5)
		elapsed += flash * 0.5
		seen_hidden = seen_hidden or not visual.visible
		seen_shown = seen_shown or visual.visible
	assert_true(seen_hidden and seen_shown, "she flickers")
	_room.player.tick_blink(0.2)
	assert_false(_room.player.is_blinking())
	assert_true(visual.visible, "and ends visible")


func test_after_a_fight_red_blinks_whether_she_won_or_ran() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	assert_eq(_requests.size(), 1)
	_room.battle_finished("ran")
	assert_true(_room.player.is_blinking())
	assert_false(_room.encounters.is_fighting())
	assert_false(grunt.is_defeated(), "running leaves the enemy standing")
	assert_eq(grunt.get_state(), MapEnemy.State.GIVE_UP, "out of breath")
	_room.player.tick_blink(5.0)
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	grunt.step(TICK)
	assert_eq(_requests.size(), 2, "it can catch her again afterwards")
	_room.battle_finished("win")
	assert_true(_room.player.is_blinking())
	assert_true(grunt.is_defeated(), "a win removes it")


# ---- respawn and staying beaten ----

func test_a_regular_enemy_comes_back_when_the_room_is_entered_again() -> void:
	_load(ExplorationKit.TEST_A)
	var grunt: MapEnemy = _grunt()
	grunt.global_position = Vector3(2.0, 0.0, 1.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	grunt.step(TICK)
	_room.battle_finished("win")
	assert_true(grunt.is_defeated())
	assert_false(bool(_state.call("get_flag", "defeated_test_a_grunt")), "a regular enemy leaves no flag")
	await tree.process_frame
	_room.free()
	_load(ExplorationKit.TEST_A)
	assert_eq(_room.encounters.enemies().size(), 1, "back again")
	assert_not_null(_room.get_node_or_null("Grunt"))


func test_a_story_fight_stays_beaten_through_its_flag() -> void:
	var room_b: FieldRoom = _load(ExplorationKit.TEST_B)
	var guard: MapEnemy = room_b.get_node("Guard") as MapEnemy
	assert_true(guard.is_persistent())
	guard.global_position = Vector3(2.0, 0.0, 1.0)
	_place_red(Vector3(1.4, 0.0, 1.0), Vector3(2.0, 0.0, 1.0))
	await ExplorationKit.ticks(self, 2)
	guard.step(TICK)
	assert_eq(_requests[0][0], "grunt_solo")
	room_b.battle_finished("ran")
	assert_false(bool(_state.call("get_flag", "defeated_test_b_guard")), "running does not beat it")
	room_b.player.tick_blink(5.0)
	guard.reset_touch()
	guard.global_position = Vector3(2.0, 0.0, 1.0)
	guard.step(TICK)
	room_b.battle_finished("win")
	assert_true(bool(_state.call("get_flag", "defeated_test_b_guard")))
	await tree.process_frame
	room_b.free()
	_load(ExplorationKit.TEST_B)
	assert_eq(_room.encounters.enemies().size(), 0, "still beaten on re-entry")
	await tree.process_frame
	assert_true(_room.get_node_or_null("Guard") == null or _room.get_node("Guard").is_queued_for_deletion())
	# And it follows the save: a new game has it back.
	_room.free()
	_state.call("reset")
	_load(ExplorationKit.TEST_B)
	assert_eq(_room.encounters.enemies().size(), 1)
