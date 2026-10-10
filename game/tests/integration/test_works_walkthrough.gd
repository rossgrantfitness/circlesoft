extends TestCase
## A walk from Harrow's checkpoint door to the roof stub through the real SceneRouter: the Spillway, the
## Works gate (the sit-in opens the grate), the Sump, the Cable Mill (card door 1), the Bell Gallery, the
## Power Room (the cage gate and lever), the freight lift up to the Drone Line (card door 3), the Last Landing
## and the roof. Then the lift shortcut back down to the Sump. Cards come from winning the three card fights.

var _state: Node = null
var _main: Main = null
var _router: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_state.call("set_story_beat", "b2_otis_joined")
	for flag: String in ["checkpoint_open", "otis_joined", "dock_fight_won", "intro_seen", "office_chime_seen", "job_main_taken"]:
		_state.call("set_flag", flag, true)
	var made: Dictionary = ExplorationKit.make_main_and_router(self, ExplorationKit.harrow("harrow_checkpoint"))
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
	await tree.physics_frame


func _room() -> FieldRoom:
	return _main.get_room() as FieldRoom


## Uses a door in the current room the way a player would and waits for the room change.
func _through(door_id: String, expect_room: String, expect_spawn: String) -> void:
	var room: FieldRoom = _room()
	ExplorationKit.prepare(room)
	var door: Door = WorksKit.door(room, door_id)
	assert_not_null(door, door_id)
	assert_true(door.is_unlocked(), door_id + " is open")
	assert_true(door.use(room.player, room.interactor), door_id)
	ExplorationKit.finish_conversation(room)
	await _settle()
	assert_eq(_room().room_id, expect_room, "%s leads to %s" % [door_id, expect_room])
	var marker: Marker3D = _room().find_spawn(expect_spawn)
	assert_lt(_room().player.global_position.distance_to(marker.global_position), 0.4, "%s lands on %s" % [door_id, expect_spawn])
	ExplorationKit.prepare(_room())


func _win(enemy_id: String) -> void:
	WorksKit.win_fight(_room(), enemy_id)
	ExplorationKit.finish_conversation(_room())


func test_from_the_checkpoint_door_to_the_roof_stub_and_back_down_the_lift() -> void:
	assert_eq(_room().room_id, "harrow_checkpoint")
	await _through("cp_to_road", "road_mast_road", "from_harrow")
	assert_eq(_state.call("get_location")["room"], "road_mast_road")
	await _through("rd_to_foot", "road_mast_foot", "from_road")
	# The sit-in plays by itself on the first visit; the grate opens at the end.
	var driven: Dictionary = await ExplorationKit.drive_scene(self, _room(), "")
	assert_true(driven["ok"], "the sit-in finished")
	assert_true(bool(_state.call("get_flag", "zeroes_back_way")))
	await _through("fo_to_sump", "tower_sump", "from_tunnel")
	# The Sump: beat the card grunt, take card 1.
	_win("ts_card_1")
	assert_eq(WorksKit.cards(_state), 1)
	await _through("ts_to_cable", "tower_cable_hall", "from_below")
	await _through("tc_card_door_1", "tower_bell_gallery", "from_below")
	_win("tb_card_pair")
	assert_eq(WorksKit.cards(_state), 2)
	await _through("tb_to_gen", "tower_generator", "from_below")
	# The Power Room: no enemies, the cage gate, the lever, the lift.
	var gen: FieldRoom = _room()
	assert_eq(gen.encounters.enemies().size(), 0)
	var gate: CardGate = gen.get_node("CardGate") as CardGate
	assert_true(gate.use(gen.player, gen.interactor))
	assert_true(gate.is_open())
	ExplorationKit.finish_conversation(gen)
	var lever: PowerSwitch = gen.get_node("PowerLever") as PowerSwitch
	assert_true(lever.use(gen.player, gen.interactor))
	ExplorationKit.finish_conversation(gen)
	var lift: CageLift = gen.get_node("CageLift") as CageLift
	assert_true(lift.ride_to("tower_jammer_deck"))
	await _settle()
	assert_eq(_room().room_id, "tower_jammer_deck")
	assert_lt(_room().player.global_position.distance_to(_room().find_spawn("from_lift").global_position), 0.4)
	ExplorationKit.prepare(_room())
	# The Drone Line: card 3, then the door.
	var deck: Door = WorksKit.door(_room(), "td_card_door_3")
	assert_false(deck.is_unlocked(), "two cards are not three")
	_win("td_squad")
	assert_eq(WorksKit.cards(_state), 3)
	await _through("td_card_door_3", "tower_landing", "from_below")
	assert_eq(WorksKit.cards(_state), 3, "the cards are never used up")
	await _through("tl_to_roof", "tower_roof", "from_below")
	assert_eq(_state.call("get_location")["room"], "tower_roof")
	# The roof is a stub for M5, with a door back down.
	await _through("rf_to_landing", "tower_landing", "from_above")
	# The shortcut: from the landing back to the deck and down the freight lift to the Sump.
	await _through("tl_to_deck", "tower_jammer_deck", "from_above")
	var down: CageLift = _room().get_node("CageLift") as CageLift
	assert_true(down.ride_to("tower_sump"))
	await _settle()
	assert_eq(_room().room_id, "tower_sump")
	assert_lt(_room().player.global_position.distance_to(_room().find_spawn("from_lift").global_position), 0.4)
	assert_true(SaveLamp.is_near_any(tree, _room().find_spawn("lamp1").global_position, 2.0), "the first save lamp is right there")


## Red can really walk each room from where she arrives to the way on (the walls, the mast column, the
## crates and the machines leave a path), with the enemies standing still.
func test_red_can_walk_every_floor_from_her_arrival_to_the_way_on() -> void:
	var routes: Dictionary = {
		"road_mast_road": ["from_harrow", [Vector3(16.0, 0, 5.5), Vector3(32.5, 0, 4.0)]],
		"road_mast_foot": ["from_road", [Vector3(3.0, 0, 9.5), Vector3(1.4, 0, 8.0)]],
		"tower_sump": ["from_tunnel", [Vector3(5.0, 0, 8.0), Vector3(12.0, 0, 1.6)]],
		"tower_cable_hall": ["from_below", [Vector3(5.0, 0, 8.0), Vector3(12.0, 0, 1.6)]],
		"tower_bell_gallery": ["from_below", [Vector3(8.0, 0, 8.5), Vector3(12.0, 0, 1.6)]],
		"tower_generator": ["from_below", [Vector3(10.0, 0, 8.5), Vector3(15.0, 0, 3.4)]],
		"tower_jammer_deck": ["from_lift", [Vector3(8.0, 0, 3.5), Vector3(3.5, 0, 1.6)]],
		"tower_landing": ["from_below", [Vector3(6.0, 0, 3.0), Vector3(6.0, 0, 1.5)]],
		"tower_roof": ["from_below", [Vector3(10.0, 0, 8.0), Vector3(16.0, 0, 6.0)]],
	}
	for room_id: String in routes:
		var room: FieldRoom = ExplorationKit.load_room_at(self, WorksKit.path(room_id), str(routes[room_id][0]))
		room.encounters.set_enemies_active(false)
		for goal: Vector3 in routes[room_id][1]:
			assert_true(await ExplorationKit.walk_to(self, room, goal, true, 0.5, 600), "%s: Red reaches %s" % [room_id, goal])
		room.free()
