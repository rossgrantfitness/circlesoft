extends TestCase
## The SceneRouter: go_to(room, spawn) fades, swaps the room through Main, puts Red on the named spawn,
## records where the party is, emits room_entered, refuses nonsense, and leaves Main's battle detach /
## attach alone. Doors use it end to end.

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _entered: Array[String] = []


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_entered = []


func after_each() -> void:
	_state.call("reset")
	for action: StringName in [&"interact", &"move_up"]:
		Input.action_release(action)


func _start(path: String = ExplorationKit.TEST_A) -> void:
	var made: Dictionary = ExplorationKit.make_main_and_router(self, path)
	_main = made["main"]
	_router = made["router"]
	_router.connect("room_entered", func(room_id: String) -> void: _entered.append(room_id))


func _room() -> FieldRoom:
	return _main.get_room() as FieldRoom


func test_go_to_loads_the_room_and_puts_red_on_the_named_spawn() -> void:
	_start()
	await tree.process_frame
	var old_room: Node = _main.get_room()
	var ok: bool = await _router.call("go_to", "test_b", "vault")
	assert_true(ok)
	assert_eq(_entered, ["test_b"] as Array[String], "room_entered fired once with the room id")
	var room: FieldRoom = _room()
	assert_eq(room.room_id, "test_b")
	assert_ne(room, old_room)
	var marker: Marker3D = room.get_node("Spawns/vault") as Marker3D
	assert_lt(room.player.global_position.distance_to(marker.global_position), 0.2)
	assert_eq(_main.get_state(), Main.State.ROOM)
	await tree.process_frame
	assert_false(is_instance_valid(old_room) and old_room.is_inside_tree(), "the old room is gone")
	assert_eq(_main.screen.get_world_root().get_child_count(), 1, "only the new room is in the world")


func test_the_spawn_sets_where_red_faces() -> void:
	_start()
	await tree.process_frame
	assert_true(await _router.call("go_to", "test_a", "start"))
	var facing: Vector3 = _room().player.get_facing()
	assert_gt(facing.x, 0.9, "the start marker faces east (into the room)")


func test_no_spawn_named_uses_the_rooms_default() -> void:
	_start()
	await tree.process_frame
	assert_true(await _router.call("go_to", "test_b"))
	var marker: Marker3D = _room().get_node("Spawns/from_a") as Marker3D
	assert_lt(_room().player.global_position.distance_to(marker.global_position), 0.2)
	assert_eq(_router.call("default_spawn", "test_b"), "from_a")


func test_the_location_is_recorded_in_game_state_before_room_entered() -> void:
	_start()
	await tree.process_frame
	var seen: Array = []
	_router.connect("room_entered", func(_room_id: String) -> void: seen.append(_state.call("get_location")))
	await _router.call("go_to", "test_b", "vault")
	assert_eq(seen[0], {"room": "test_b", "spawn": "vault"})
	assert_eq(_router.get("current_room_id"), "test_b")
	assert_eq(_router.get("current_spawn_id"), "vault")


func test_unknown_rooms_and_spawns_are_refused_and_nothing_changes() -> void:
	_start()
	await tree.process_frame
	var room_before: Node = _main.get_room()
	assert_false(await _router.call("go_to", "nowhere", ""))
	assert_false(await _router.call("go_to", "test_b", "no_such_spawn"))
	assert_eq(_main.get_room(), room_before)
	assert_true(_entered.is_empty())
	assert_false(_router.call("is_busy"), "and it is not stuck busy")


func test_a_second_go_to_while_one_is_running_is_ignored() -> void:
	_start()
	await tree.process_frame
	_router.set("instant", false)
	_router.call("go_to", "test_b", "vault")
	assert_true(_router.call("is_busy"))
	var second: bool = await _router.call("go_to", "test_a", "start")
	assert_false(second)
	while _router.call("is_busy"):
		await tree.process_frame
	assert_eq(_room().room_id, "test_b", "only the first one happened")
	assert_eq(_entered, ["test_b"] as Array[String])


func test_the_screen_fades_to_black_before_the_swap_and_back_after() -> void:
	_start()
	await tree.process_frame
	_router.set("instant", false)
	var steps: int = int(_router.call("fade_steps"))
	var seen: Dictionary = {"at_swap": -1, "max": 0}
	_router.connect("room_entered", func(_room_id: String) -> void: seen["at_swap"] = int(_router.call("get_fade_step")))
	_router.call("go_to", "test_b", "vault")
	while _router.call("is_busy"):
		seen["max"] = maxi(int(seen["max"]), int(_router.call("get_fade_step")))
		await tree.process_frame
	assert_eq(int(seen["at_swap"]), steps, "fully black when the new room appears")
	assert_eq(int(seen["max"]), steps)
	assert_eq(int(_router.call("get_fade_step")), 0, "and clear at the end")
	assert_gt(steps, 1, "in dithered steps")


func test_red_stands_still_while_the_fade_runs() -> void:
	_start()
	await tree.process_frame
	_router.set("instant", false)
	var old_player: PlayerController = _room().player
	_router.call("go_to", "test_b", "vault")
	assert_true(old_player.frozen, "frozen from the first frame")
	await tree.create_timer(0.3).timeout
	assert_true(_room().player.frozen, "the new Red waits for the fade in")
	while _router.call("is_busy"):
		await tree.process_frame
	assert_false(_room().player.frozen, "free again at the end")


func test_a_door_takes_red_through_end_to_end() -> void:
	_start()
	await tree.process_frame
	var room: FieldRoom = _room()
	ExplorationKit.prepare(room)
	var door: Door = room.get_node("DoorToB") as Door
	door.router = _router
	await ExplorationKit.stand(self, room, Vector3(8.0, 0.0, -3.1), Vector3(8.0, 0.0, -4.0))
	assert_true(room.interactor.try_interact())
	assert_true(_router.call("is_busy"))
	while _router.call("is_busy"):
		await tree.process_frame
	assert_eq(_room().room_id, "test_b")
	var arrival: Marker3D = _room().get_node("Spawns/from_a") as Marker3D
	assert_lt(_room().player.global_position.distance_to(arrival.global_position), 0.3)
	# And back through B's own door.
	var back: FieldRoom = _room()
	ExplorationKit.prepare(back)
	(back.get_node("DoorToA") as Door).router = _router
	await ExplorationKit.stand(self, back, Vector3(-3.5, 0.0, -3.1), Vector3(-3.5, 0.0, -4.0))
	assert_true(back.interactor.try_interact())
	while _router.call("is_busy"):
		await tree.process_frame
	assert_eq(_room().room_id, "test_a")
	assert_lt(_room().player.global_position.distance_to((_room().get_node("Spawns/from_b") as Marker3D).global_position), 0.3)
	assert_eq(_entered, ["test_b", "test_a"] as Array[String])


func test_start_at_enters_a_room_without_fading_out() -> void:
	_start(ExplorationKit.TEST_ROOM)
	await tree.process_frame
	_router.set("instant", false)
	assert_true(await _router.call("start_at", "test_a", "from_vault"))
	assert_eq(_room().room_id, "test_a")
	assert_eq(_entered, ["test_a"] as Array[String])


func test_the_crew_comes_along_into_each_room() -> void:
	_start()
	await tree.process_frame
	assert_true(await _router.call("go_to", "test_b", "from_a"))
	assert_eq(_room().party.followers.size(), 2)


func test_rooms_that_name_a_missing_data_file_are_refused() -> void:
	_start()
	await tree.process_frame
	var rooms: Dictionary = DataDB.get_dict("world/rooms")["rooms"]
	rooms["ghost"] = {"name": "Ghost", "scene": "res://scenes/rooms/ghost.tscn", "spawns": ["a"], "default_spawn": "a"}
	assert_false(await _router.call("go_to", "ghost", "a"), "a room whose scene is missing is refused")
	rooms.erase("ghost")
	assert_eq(_entered.size(), 0)


# ---- battles through the router's rooms ----

func test_a_battle_from_a_routed_room_comes_back_to_that_room_and_the_router_waits() -> void:
	_start()
	await tree.process_frame
	assert_true(await _router.call("go_to", "test_b", "from_a"))
	var room: FieldRoom = _room()
	var spot: Vector3 = room.player.global_position
	_main.battle_setup_hook = BattleFlowKit.winning_hook(_main)
	_main.start_battle("grunt_solo")
	assert_eq(_main.get_state(), Main.State.BATTLE)
	assert_false(await _router.call("go_to", "test_a", "start"), "no room changes in the middle of a fight")
	assert_true(await BattleFlowKit.finish_fight(tree, _main, "continue"))
	await tree.process_frame
	assert_eq(_main.get_room(), room, "the same room, kept in memory")
	assert_eq(_main.get_state(), Main.State.ROOM)
	assert_lt(room.player.global_position.distance_to(spot), 0.1)
	assert_true(room.player.is_blinking(), "Red blinks after the fight")
	assert_true(await _router.call("go_to", "test_a", "start"), "and the router works again")
	assert_eq(_room().room_id, "test_a")


func test_the_old_test_room_has_a_door_to_the_yard_and_back() -> void:
	_start(ExplorationKit.TEST_ROOM)
	await tree.process_frame
	var room: FieldRoom = _room()
	ExplorationKit.prepare(room)
	var door: Door = room.get_node("DoorToYard") as Door
	door.router = _router
	await ExplorationKit.stand(self, room, Vector3(-4.1, 0.0, -1.4), Vector3(-5.0, 0.0, -1.4))
	assert_eq(room.interactor.get_target(), door.interactable)
	assert_true(room.interactor.try_interact())
	while _router.call("is_busy"):
		await tree.process_frame
	assert_eq(_room().room_id, "test_a")
	var yard: FieldRoom = _room()
	ExplorationKit.prepare(yard)
	var back: Door = yard.get_node("DoorToTestRoom") as Door
	back.router = _router
	await ExplorationKit.stand(self, yard, Vector3(-5.1, 0.0, -0.8), Vector3(-6.0, 0.0, -0.8))
	assert_true(yard.interactor.try_interact())
	while _router.call("is_busy"):
		await tree.process_frame
	assert_eq(_room().room_id, "test_room")
	var arrival: Marker3D = _room().get_node("Spawns/from_yard") as Marker3D
	assert_lt(_room().player.global_position.distance_to(arrival.global_position), 0.3)
	assert_eq(_entered, ["test_a", "test_room"] as Array[String])
