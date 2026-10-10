extends TestCase
## The crew follows Red: Otis and Mox walk behind her along her own path at fixed spacing, catch up
## after a teleport, start the room in order (and never inside a wall), and can never block her.

var _room: FieldRoom = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")


func _load() -> FieldRoom:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_A)
	return _room


func _spacing() -> float:
	return FieldTuning.from_db(tree.root.get_node("DataDB")).follow_spacing


func test_otis_and_mox_follow_as_the_rest_of_the_party() -> void:
	_load()
	assert_not_null(_room.party)
	var ids: Array[String] = []
	for follower: PartyFollower in _room.party.followers:
		ids.append(follower.member_id)
	assert_eq(ids, ["otis", "mox"] as Array[String], "the party minus Red, in order")
	for follower: PartyFollower in _room.party.followers:
		assert_not_null(follower.get_model(), follower.member_id + " uses their placeholder model")
		assert_gt(follower.get_head_height(), 0.5)
		assert_true(_room.runner.has_speaker(follower.member_id), "they speak from where they stand")


func test_the_old_test_room_keeps_its_standing_otis_and_mox_instead() -> void:
	var old_room: FieldRoom = ExplorationKit.load_room(self, ExplorationKit.TEST_ROOM)
	assert_null(old_room.party)
	assert_eq(get_follower_count(old_room), 0)


func get_follower_count(room: Node) -> int:
	return room.find_children("*", "CharacterBody3D", true, false).filter(func(n: Node) -> bool: return n is PartyFollower).size()


func test_a_smaller_party_has_fewer_followers() -> void:
	_state.call("load_party", {"default_party": ["red", "mox"], "members": DataDB.get_dict("party/party")["members"]})
	_state.call("reset")
	_load()
	assert_eq(_room.party.followers.size(), 1)
	assert_eq(_room.party.followers[0].member_id, "mox")
	_state.call("load_party", DataDB.get_dict("party/party"))
	_state.call("reset")


func test_the_line_starts_in_order_behind_red_and_inside_the_walls() -> void:
	_load()
	await ExplorationKit.ticks(self, 3)
	var red: Vector3 = _room.player.global_position
	var floor_left: float = -6.0
	for follower: PartyFollower in _room.party.followers:
		assert_gt(follower.global_position.x, floor_left, follower.member_id + " did not start inside the wall")
		assert_lt(follower.global_position.x, red.x + 0.001, "behind her (she faces east)")
	var otis: PartyFollower = _room.party.followers[0]
	var mox: PartyFollower = _room.party.followers[1]
	assert_le(otis.global_position.x, red.x)
	assert_le(mox.global_position.x, otis.global_position.x + 0.001, "Mox behind Otis")


func test_followers_hold_their_spacing_along_the_path_red_walked() -> void:
	_load()
	await ExplorationKit.stand(self, _room, Vector3(-3.0, 0.0, 2.5), Vector3(5.0, 0.0, 2.5))
	_room.party.seed_trail()
	for follower: PartyFollower in _room.party.followers:
		follower.global_position = _room.player.global_position
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(2.5, 0.0, 2.5)))
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(2.5, 0.0, 0.2)), "round a corner")
	await ExplorationKit.ticks(self, 2)
	var spacing: float = _spacing()
	var red: Vector3 = _room.player.global_position
	var otis: Vector3 = _room.party.followers[0].global_position
	var mox: Vector3 = _room.party.followers[1].global_position
	assert_almost_eq(red.distance_to(otis), spacing, 0.12, "Otis one spacing behind")
	assert_almost_eq(otis.distance_to(mox), spacing, 0.12, "Mox one more behind Otis")
	# On the path: Otis is where Red was 'spacing' ago, along the trail.
	assert_almost_eq(_room.party.point_behind(red, spacing).distance_to(otis), 0.0, 0.1)
	assert_almost_eq(_room.party.point_behind(red, spacing * 2.0).distance_to(mox), 0.0, 0.1)


func test_spacing_holds_while_running_too() -> void:
	_load()
	await ExplorationKit.stand(self, _room, Vector3(-3.0, 0.0, 2.5), Vector3(5.0, 0.0, 2.5))
	_room.party.seed_trail()
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(4.0, 0.0, 2.5), true))
	await ExplorationKit.ticks(self, 2)
	var red: Vector3 = _room.player.global_position
	assert_almost_eq(red.distance_to(_room.party.followers[0].global_position), _spacing(), 0.2)
	assert_almost_eq(red.distance_to(_room.party.followers[1].global_position), _spacing() * 2.0, 0.3)


func test_no_new_crumbs_while_red_stands_still() -> void:
	_load()
	await ExplorationKit.ticks(self, 10)
	var count: int = _room.party.trail.size()
	await ExplorationKit.ticks(self, 30)
	assert_eq(_room.party.trail.size(), count, "standing still drops no crumbs")
	assert_lt(_room.party.trail.size(), 40, "and the trail stays short")


func test_followers_run_to_catch_up_after_a_teleport() -> void:
	_load()
	await ExplorationKit.ticks(self, 5)
	var teleports: Array = []
	_room.party.teleport_detected.connect(func() -> void: teleports.append(1))
	_room.player.global_position = Vector3(7.0, 0.02, -0.5)
	await ExplorationKit.ticks(self, 2)
	assert_eq(teleports.size(), 1, "the jump was noticed")
	var field: FieldTuning = FieldTuning.from_db(tree.root.get_node("DataDB"))
	var cap: float = field.run_speed * field.follow_catch_up_speed_mult
	var fastest: float = 0.0
	var otis: PartyFollower = _room.party.followers[0]
	assert_gt(otis.global_position.distance_to(_room.player.global_position), 4.0, "far behind at first")
	var ticks: int = 0
	while ticks < 240:
		await tree.physics_frame
		fastest = maxf(fastest, otis.current_speed)
		ticks += 1
		var done: bool = true
		for follower: PartyFollower in _room.party.followers:
			var wanted: Vector3 = _room.party.point_behind(_room.player.global_position, _spacing() * float(_room.party.followers.find(follower) + 1))
			done = done and follower.global_position.distance_to(wanted) < 0.05
		if done:
			break
	assert_lt(ticks, 240, "they caught up")
	assert_lt(float(ticks) / 60.0, 3.0, "within a few seconds")
	assert_gt(fastest, field.run_speed, "faster than Red runs")
	assert_le(fastest, cap + 0.5, "but no faster than the catch-up cap")


func test_followers_never_block_red() -> void:
	_load()
	for follower: PartyFollower in _room.party.followers:
		assert_eq(follower.collision_layer & _room.player.collision_mask, 0, follower.member_id + " is on a layer Red ignores")
		assert_eq(follower.collision_mask, 0, "and collides with nothing")
		assert_eq(_room.player.collision_layer & follower.collision_mask, 0)
	# Plant both followers right in her way and walk through them.
	_room.party.active = false
	await ExplorationKit.stand(self, _room, Vector3(-3.0, 0.0, 2.5), Vector3(5.0, 0.0, 2.5))
	_room.party.followers[0].global_position = Vector3(-1.5, 0.0, 2.5)
	_room.party.followers[1].global_position = Vector3(-1.4, 0.0, 2.5)
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(1.0, 0.0, 2.5)), "walked straight through the crew")
	assert_gt(_room.player.global_position.x, 0.5)


func test_followers_stand_on_the_floor_and_hop_with_her_trail() -> void:
	_load()
	await ExplorationKit.ticks(self, 10)
	for follower: PartyFollower in _room.party.followers:
		assert_almost_eq(follower.global_position.y, 0.0, 0.05, follower.member_id + " on the floor")


func test_room_load_through_main_keeps_the_crew() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	main.start_scene = null
	await tree.process_frame
	var room: Node = main.enter_room(load(ExplorationKit.TEST_B) as PackedScene, "vault")
	await tree.physics_frame
	var field_room: FieldRoom = room as FieldRoom
	assert_eq(field_room.party.followers.size(), 2)
	assert_lt(field_room.party.followers[0].global_position.distance_to(field_room.player.global_position), 3.0, "they arrive with her")
