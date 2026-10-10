extends TestCase
## A walk through all of Harrow Landing: start in Red's home, use every door in every room (they take
## Red where the data says, onto the named spawn), visit all nine rooms and the road stub, and walk
## out of the house with the stick.

const ROOMS: Array[String] = ["harrow_home", "harrow_square", "harrow_courier", "harrow_store", "harrow_gear", "harrow_docks",
		"harrow_dock_office", "harrow_bar", "harrow_checkpoint", "road_mast_road"]

var _state: Node = null
var _main: Main = null
var _router: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	# B2 with the one-time scenes already seen, and the locks opened: nothing interrupts the walk.
	_state.call("set_story_beat", "b2_otis_joined")
	for flag: String in ["job_main_taken", "checkpoint_open", "office_chime_seen", "otis_joined", "dock_fight_won", "intro_seen", "mox_cameo_seen"]:
		_state.call("set_flag", flag, true)
	var made: Dictionary = ExplorationKit.make_main_and_router(self, ExplorationKit.TEST_ROOM)
	_main = made["main"]
	_router = tree.root.get_node("SceneRouter")
	_router.set("instant", true)
	made["router"].free()


func after_each() -> void:
	_router.set("instant", false)
	_state.call("reset")


func _settle() -> void:
	while _router.call("is_busy"):
		await tree.process_frame
	await tree.physics_frame


func _room() -> FieldRoom:
	return _main.get_room() as FieldRoom


func test_every_door_in_every_room_works_and_all_rooms_are_visited() -> void:
	assert_true(await _router.call("start_at", "harrow_home", "start"))
	await _settle()
	var visited: Dictionary = {"harrow_home": true}
	var doors_used: int = 0
	var rooms: Dictionary = DataDB.get_dict("world/rooms")["rooms"]
	for room_id: String in ROOMS:
		assert_true(await _router.call("go_to", room_id, ""), "enter " + room_id)
		await _settle()
		assert_eq(_room().room_id, room_id)
		visited[room_id] = true
		var door_ids: Array[String] = []
		for node: Node in _room().find_children("*", "Node3D", true, false):
			if node is Door:
				door_ids.append((node as Door).placement_id)
		assert_gt(door_ids.size(), 0, room_id + " has doors")
		for door_id: String in door_ids:
			var door: Door = null
			for node: Node in _room().find_children("*", "Node3D", true, false):
				if node is Door and (node as Door).placement_id == door_id:
					door = node as Door
			ExplorationKit.prepare(_room())
			assert_true(door.is_unlocked(), door_id + " is open once the flags are set")
			var target: String = door.get_target_room()
			var target_spawn: String = door.get_target_spawn()
			assert_true(door.use(_room().player, _room().interactor), door_id)
			await _settle()
			doors_used += 1
			assert_eq(_room().room_id, target, "%s leads to %s" % [door_id, target])
			var marker: Marker3D = _room().find_spawn(target_spawn)
			assert_lt(_room().player.global_position.distance_to(marker.global_position), 0.35, door_id + " lands on its spawn")
			visited[target] = true
			assert_true(await _router.call("go_to", room_id, ""))
			await _settle()
	for room_id: String in ROOMS:
		assert_true(visited.has(room_id), "visited " + room_id)
	assert_gt(doors_used, 18, "every door in the town was used")
	assert_ge(rooms.size(), ROOMS.size())


func test_the_walk_out_of_the_house_and_into_the_courier_office_with_the_stick() -> void:
	assert_true(await _router.call("start_at", "harrow_home", "start"))
	await _settle()
	var home: FieldRoom = _room()
	ExplorationKit.prepare(home)
	home.story.triggers_enabled = false
	assert_true(await ExplorationKit.walk_to(self, home, Vector3(5.5, 0.0, 3.0)))
	home.player.stick = ExplorationKit.stick_toward(home, Vector3(5.5, 0.0, 6.0))
	for i: int in 180:
		if _router.call("is_busy") or _room() != home:
			break
		await tree.physics_frame
	await _settle()
	assert_eq(_room().room_id, "harrow_square", "walking into the doormat leaves the house")
	var square: FieldRoom = _room()
	ExplorationKit.prepare(square)
	square.story.triggers_enabled = false
	await ExplorationKit.ticks(self, 4)
	assert_true(await ExplorationKit.walk_to(self, square, Vector3(4.0, 0.0, 2.2), true))
	square.player.stick = ExplorationKit.stick_toward(square, Vector3(4.0, 0.0, -1.0))
	for i: int in 180:
		if _router.call("is_busy") or _room() != square:
			break
		await tree.physics_frame
	await _settle()
	assert_eq(_room().room_id, "harrow_courier", "and the courier office is the first door on the square")
