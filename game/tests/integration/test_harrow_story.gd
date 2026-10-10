extends TestCase
## Harrow Landing's story layer (M3-4): townsfolk whose lines change with the story beat, the job
## board and the two side deliveries end to end, the dock fight scene, the checkpoint, the shops, the
## hidden items, and New Game starting on the ore train. Rooms are the graybox scenes in scenes/rooms/harrow.
## The town tests start from "the train is done": GameState.reset() plus the b1_night beat (New Game itself
## begins on the train, beat b0_train).

const B1: String = "b1_night"
const B2: String = "b2_otis_joined"
const B3: String = "b3_home_again"

var _state: Node = null
var _room: FieldRoom = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_state.call("set_story_beat", B1)
	# Off the train: Red is alone; Otis joins at the dock fight, Mox later.
	_state.call("leave_party", "otis")
	_state.call("leave_party", "mox")
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	_state.call("reset")
	tree.root.get_node("SceneRouter").set("instant", false)


func _load(room_id: String, spawn: String = "", scenes: bool = false) -> FieldRoom:
	_room = ExplorationKit.load_room_at(self, ExplorationKit.harrow(room_id), spawn, scenes)
	return _room


func _beat(beat_id: String) -> void:
	_state.call("set_story_beat", beat_id)


func _says(room: FieldRoom, node_name: String) -> String:
	var npc: PlacedNpc = room.get_node(node_name) as PlacedNpc
	var variant: Dictionary = npc.current_variant()
	return str(variant.get("conversation", variant.get("scene", "")))


# ---- New Game ----

func test_new_game_starts_on_the_ore_train_with_red_alone() -> void:
	var main: Main = (load(BattleFlowKit.MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.debug_overlay_enabled = false
	add_to_root(main)
	await tree.process_frame
	var router: Node = tree.root.get_node("SceneRouter")
	router.set("instant", true)
	main.start_new_game()
	while router.call("is_busy"):
		await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	assert_eq(room.room_id, "train_flatcar", "New Game starts on the ore train's flatcar")
	assert_eq(_state.call("get_story_beat"), "b0_train")
	assert_eq(_state.call("get_location"), {"room": "train_flatcar", "spawn": "start"})
	var marker: Marker3D = room.get_node("Spawns/start") as Marker3D
	assert_lt(room.player.global_position.distance_to(marker.global_position), 0.3)
	assert_eq(DataDB.get_value("world/rooms", "start_room"), "train_flatcar")
	assert_eq(_state.call("get_active_party"), ["red"] as Array[String], "Red is alone")
	assert_eq(int(_state.call("get_member", "red")["level"]), 1, "level 1")
	assert_true(bool(_state.call("has_item", "delivery_crate")), "she carries Watch Zero's crate")
	# The opening plays by itself.
	for i: int in 120:
		if room.runner.is_running():
			break
		await tree.physics_frame
	assert_eq(room.runner.get_current_conversation(), "train_open_1", "the opening scene starts")
	assert_true(bool(_state.call("get_flag", "train_open_seen")))
	ExplorationKit.finish_conversation(room)


func test_the_old_test_room_is_still_reachable_from_a_debug_door_and_back() -> void:
	var square: FieldRoom = _load("harrow_square", "from_home")
	var door: Door = square.get_node("DoorDebug") as Door
	assert_eq(door.get_target_room(), "test_room")
	assert_eq(door.get_target_spawn(), "PlayerSpawn")
	var back: FieldRoom = ExplorationKit.load_room(self, ExplorationKit.TEST_ROOM)
	assert_eq((back.get_node("DoorToHarrow") as Door).get_target_room(), "harrow_square")


# ---- townsfolk by story beat ----

func test_lines_change_by_story_beat() -> void:
	var square: FieldRoom = _load("harrow_square")
	var expected: Dictionary = {
		"Bettor": [B1, "harrow_bettor_b1", B2, "harrow_bettor_b2", B3, "harrow_bettor_b3"],
		"Neighbor": [B1, "harrow_neighbor_b1", B2, "harrow_neighbor_b2", B3, "harrow_neighbor_b3"],
		"SnackSeller": [B1, "harrow_snack_b1", B2, "harrow_snack_b2", B3, "harrow_snack_b2"],
	}
	for node_name: String in expected:
		var list: Array = expected[node_name]
		for i: int in range(0, list.size(), 2):
			_beat(str(list[i]))
			assert_eq(_says(square, node_name), str(list[i + 1]), "%s in %s" % [node_name, list[i]])
	square.free()
	var courier: FieldRoom = _load("harrow_courier")
	for entry: Array in [[B1, "harrow_dispatcher_b1"], [B2, "harrow_dispatcher_b2"], [B3, "harrow_dispatcher_b3"]]:
		_beat(str(entry[0]))
		assert_eq(_says(courier, "Dispatcher"), str(entry[1]))
	assert_eq(_says(courier, "Sleeper"), "harrow_sleeper", "the sleeping courier never wakes up, in any beat")
	_beat(B3)
	assert_eq(_says(courier, "Sleeper"), "harrow_sleeper")


func test_who_is_in_the_room_depends_on_the_beat() -> void:
	var square: FieldRoom = _load("harrow_square")
	assert_true((square.get_node("GateDockhand") as PlacedNpc).is_present(), "B1: the dockhand guards the stairs")
	assert_false((square.get_node("LegendBarfly") as PlacedNpc).is_present())
	assert_false((square.get_node("MoxCameo") as PlacedNpc).is_present(), "Mox waits off stage until his scene")
	square.free()
	_beat(B2)
	square = _load("harrow_square")
	assert_false((square.get_node("GateDockhand") as PlacedNpc).is_present(), "gone in B2")
	square.free()
	_beat(B3)
	square = _load("harrow_square")
	assert_true((square.get_node("LegendBarfly") as PlacedNpc).is_present(), "the legend barfly shows up for the walk home")
	var store: FieldRoom = _load("harrow_store")
	assert_false((store.get_node("Customer") as PlacedNpc).is_present(), "the nervous clerk is a B1 customer only")
	store.free()
	_beat(B1)
	store = _load("harrow_store")
	assert_true((store.get_node("Customer") as PlacedNpc).is_present())
	var checkpoint: FieldRoom = _load("harrow_checkpoint")
	assert_true((checkpoint.get_node("GruntA") as PlacedNpc).is_present(), "two grunts at the barrier in B1")
	checkpoint.free()
	_beat(B2)
	checkpoint = _load("harrow_checkpoint")
	assert_false((checkpoint.get_node("GruntA") as PlacedNpc).is_present(), "radioed up to the tower in B2")
	assert_eq(_says(checkpoint, "FanA"), "harrow_cp_fan_a_b2")


func test_talking_to_a_townsperson_plays_the_beat_line_in_the_plain_box() -> void:
	var square: FieldRoom = _load("harrow_square")
	var bettor: PlacedNpc = square.get_node("Bettor") as PlacedNpc
	await ExplorationKit.stand_before(self, square, bettor)
	assert_eq(square.interactor.get_target(), bettor.get_interactable())
	assert_eq(square.prompt.current_icon, "talk")
	assert_true(square.interactor.try_interact())
	assert_eq(square.runner.get_current_conversation(), "harrow_bettor_b1")
	assert_eq(square.runner.style_for("crowd_bettor"), "box", "townsfolk speak in the plain box")
	ExplorationKit.finish_conversation(square)
	_beat(B2)
	await ExplorationKit.ticks(self, 4)
	assert_true(square.interactor.try_interact())
	assert_eq(square.runner.get_current_conversation(), "harrow_bettor_b2", "the same person says something new")
	ExplorationKit.finish_conversation(square)


func test_the_dock_gate_dockhand_steps_aside_once_red_has_the_slip() -> void:
	var square: FieldRoom = _load("harrow_square")
	var hand: PlacedNpc = square.get_node("GateDockhand") as PlacedNpc
	var home: Vector3 = hand.global_position
	assert_eq(_says(square, "GateDockhand"), "harrow_gate_shut")
	square.free()
	_state.call("set_flag", "job_main_taken", true)
	square = _load("harrow_square")
	hand = square.get_node("GateDockhand") as PlacedNpc
	assert_eq(_says(square, "GateDockhand"), "harrow_gate_open")
	assert_gt(hand.global_position.distance_to(home), 1.0, "he steps aside")


func test_every_dialogue_line_is_marked_placeholder_and_speakers_are_crowd_or_cast() -> void:
	var doc: Dictionary = DataDB.get_dict("dialogue/harrow_town")
	assert_true(str(doc["_about"]).contains("PLACEHOLDER"))
	var cast: Array = ["red", "otis", "mox", "kasp", "narrator", "sign"]
	for id: String in doc["conversations"]:
		for line: Dictionary in doc["conversations"][id]:
			var speaker: String = str(line["speaker"])
			assert_true(speaker.begins_with("crowd_") or cast.has(speaker), "%s: %s" % [id, speaker])
			if line.has("text"):
				assert_le(str(line["text"]).length(), 140, id + " is short")


# ---- job board and the side deliveries ----

func _use_board(room: FieldRoom, index: int) -> void:
	var board: JobBoard = room.get_node("JobBoard") as JobBoard
	assert_true(board.use(room.player, room.interactor))
	assert_true(ExplorationKit.to_choice(room), "the board lists the jobs")
	ExplorationKit.answer(room, index)


func test_the_board_takes_the_main_job_and_the_dock_stairs_open() -> void:
	var square: FieldRoom = _load("harrow_square")
	var stairs: Door = square.get_node("DoorDocks") as Door
	assert_false(stairs.is_unlocked())
	assert_true(stairs.locked_message().begins_with("Docks are shut, Red."), "the lock's message comes from data")
	square.free()
	var courier: FieldRoom = _load("harrow_courier")
	var board: JobBoard = courier.get_node("JobBoard") as JobBoard
	assert_eq(board.job_ids(), ["main", "dark_window", "appeal"] as Array[String])
	assert_eq(board.job_state("main"), "available")
	_use_board(courier, 0)
	assert_eq(board.job_state("main"), "taken")
	assert_true(bool(_state.call("has_item", "courier_job_slip")), "the slip is in the bag")
	assert_true(bool(_state.call("get_flag", "job_main_taken")))
	courier.free()
	square = _load("harrow_square")
	assert_true((square.get_node("DoorDocks") as Door).is_unlocked(), "the stairs are open with the job taken")


func test_the_board_shows_taken_and_done() -> void:
	var courier: FieldRoom = _load("harrow_courier")
	var board: JobBoard = courier.get_node("JobBoard") as JobBoard
	_use_board(courier, 1)
	assert_eq(board.job_state("dark_window"), "taken")
	assert_eq(int(_state.call("item_count", "side_job_parcel")), 1, "the oil can is handed over with the job")
	assert_true(board.use(courier.player, courier.interactor))
	assert_true(ExplorationKit.to_choice(courier))
	courier.runner.get_current_bubble().choose(1)
	for i: int in 12:
		courier.runner.confirm()
		courier.runner.tick(0.5)
	assert_eq(int(_state.call("item_count", "side_job_parcel")), 1, "asking again takes nothing twice")
	_state.call("set_flag", "job_dark_window_done", true)
	assert_eq(board.job_state("dark_window"), "done")
	ExplorationKit.finish_conversation(courier)


func test_the_dark_window_side_job_end_to_end() -> void:
	var courier: FieldRoom = _load("harrow_courier")
	_use_board(courier, 1)
	courier.free()
	var square: FieldRoom = _load("harrow_square")
	var spot: SceneSpot = square.get_node("WindowLedge") as SceneSpot
	var reward: Pickup = square.get_node("WindowReward") as Pickup
	assert_false(reward.visible, "no reward on the sill yet")
	assert_false(reward.interactable.enabled)
	var credits: int = int(_state.call("get_credits"))
	assert_true(spot.use(square.player, square.interactor))
	var result: Dictionary = await ExplorationKit.drive_scene(self, square, "dark_window_light")
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "job_dark_window_done")))
	assert_eq(int(_state.call("item_count", "side_job_parcel")), 0, "the oil can is used up")
	assert_true(reward.visible, "the reward pops onto the sill")
	assert_true(reward.interactable.enabled)
	reward.use(square.player, square.interactor)
	assert_eq(int(_state.call("get_credits")), credits + 100)
	assert_true(bool(_state.call("has_item", "lucky_bolt")))
	assert_true(reward.is_taken())
	# A second visit: the window just glows.
	assert_eq(str(spot.current_variant()["conversation"]), "harrow_window_done")


func test_the_dark_window_does_nothing_without_the_job_or_the_oil() -> void:
	var square: FieldRoom = _load("harrow_square")
	var spot: SceneSpot = square.get_node("WindowLedge") as SceneSpot
	assert_eq(str(spot.current_variant()["conversation"]), "harrow_window_dark")
	_state.call("set_flag", "job_dark_window_taken", true)
	assert_eq(str(spot.current_variant()["conversation"]), "harrow_window_dark", "taken but no oil in the bag")
	_state.call("add_item", "side_job_parcel", 1)
	assert_eq(str(spot.current_variant()["scene"]), "dark_window_light")


func test_the_balcony_can_be_reached_by_hopping_two_crates() -> void:
	var square: FieldRoom = _load("harrow_square")
	var jump_height: float = float(DataDB.get_value("world/field_tuning", "jump.height"))
	var step: MeshInstance3D = square.get_node("CrateStep") as MeshInstance3D
	var balcony: MeshInstance3D = square.get_node("Balcony") as MeshInstance3D
	var step_top: float = step.position.y + (step.mesh as BoxMesh).size.y * 0.5
	var balcony_top: float = balcony.position.y + (balcony.mesh as BoxMesh).size.y * 0.5
	assert_le(step_top, jump_height - 0.1, "floor to crate is one easy jump")
	assert_le(balcony_top - step_top, jump_height - 0.1, "crate to balcony is one easy jump")
	var docks: FieldRoom = _load("harrow_docks")
	var crate_a: MeshInstance3D = docks.get_node("CrateA") as MeshInstance3D
	var crate_b: MeshInstance3D = docks.get_node("CrateB") as MeshInstance3D
	var top_a: float = crate_a.position.y + 0.45
	var top_b: float = crate_b.position.y + 0.45
	assert_le(top_a, jump_height - 0.1)
	assert_le(top_b - top_a, jump_height - 0.1, "the dock stack is two easy hops")
	assert_almost_eq((docks.get_node("ChiliPickup") as Node3D).position.y, top_b, 0.05, "the can of chili sits on the top crate")


func test_the_appeal_side_job_end_to_end() -> void:
	_beat(B2)
	_state.call("set_flag", "otis_joined", true)
	_state.call("join_party", "otis")
	var courier: FieldRoom = _load("harrow_courier")
	_use_board(courier, 2)
	assert_true(bool(_state.call("get_flag", "job_appeal_taken")))
	courier.free()
	var docks: FieldRoom = _load("harrow_docks")
	var pell: PlacedNpc = docks.get_node("Pell") as PlacedNpc
	assert_eq(_says(docks, "Pell"), "harrow_pell_form", "with the job taken, Pell has the form")
	await ExplorationKit.stand_before(self, docks, pell)
	assert_true(docks.interactor.try_interact())
	ExplorationKit.finish_conversation(docks)
	assert_true(bool(_state.call("get_flag", "job_appeal_form_got")), "the line hands the form over")
	assert_eq(int(_state.call("item_count", "side_job_parcel")), 1)
	assert_eq(_says(docks, "Pell"), "harrow_pell_go", "and then points to the booth")
	docks.free()
	var checkpoint: FieldRoom = _load("harrow_checkpoint")
	var slot: SceneSpot = checkpoint.get_node("AppealsSpot") as SceneSpot
	var credits: int = int(_state.call("get_credits"))
	var forms: int = int(_state.call("item_count", "appeal_form"))
	assert_eq(str(slot.current_variant()["scene"]), "appeal_deliver")
	assert_true(slot.use(checkpoint.player, checkpoint.interactor))
	var result: Dictionary = await ExplorationKit.drive_scene(self, checkpoint)
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "job_appeal_done")))
	assert_eq(int(_state.call("get_credits")), credits + 150)
	assert_eq(int(_state.call("item_count", "appeal_form")), forms + 2, "two Appeal Forms for the tower")
	assert_eq(int(_state.call("item_count", "side_job_parcel")), 0)
	assert_eq(str(slot.current_variant()["conversation"]), "harrow_appeal_done")
	checkpoint.free()
	docks = _load("harrow_docks")
	assert_eq(_says(docks, "Pell"), "harrow_pell_done")


func test_the_appeal_slot_wants_a_form_first() -> void:
	var checkpoint: FieldRoom = _load("harrow_checkpoint")
	var slot: SceneSpot = checkpoint.get_node("AppealsSpot") as SceneSpot
	assert_eq(str(slot.current_variant()["conversation"]), "harrow_appeal_empty")


# ---- the dock fight and the checkpoint ----

func test_the_dock_scene_plays_the_fight_with_the_party_first_and_otis_joins() -> void:
	var docks: FieldRoom = _load("harrow_docks", "from_square", true)
	assert_true((docks.get_node("Kasp") as PlacedNpc).is_present())
	assert_null(docks.party.follower_for("otis"), "no Otis yet")
	var result: Dictionary = await ExplorationKit.drive_scene(self, docks)
	assert_true(result["ok"], "the scene played through")
	assert_eq(result["fights"], [["dock_ambush", "party"]], "one fight, the party goes first")
	assert_true(bool(_state.call("get_flag", "dock_fight_won")))
	assert_true(bool(_state.call("get_flag", "otis_joined")))
	assert_eq(_state.call("get_story_beat"), B2, "the whole town is open")
	assert_false((docks.get_node("Kasp") as PlacedNpc).is_present(), "Kasp storms off")
	assert_false((docks.get_node("GruntA") as PlacedNpc).is_present())
	assert_not_null(docks.party.follower_for("otis"), "Otis walks with Red now")
	assert_false(docks.player.frozen, "and Red is free again")
	# The fight is a story fight: no Run.
	var encounter: Dictionary = {}
	for entry: Dictionary in DataDB.get_dict("battle/encounters")["encounters"]:
		if entry["id"] == "dock_ambush":
			encounter = entry
	assert_false(bool(encounter["can_run"]), "the dock fight can't be run from")
	assert_eq(encounter["enemies"], ["signals_grunt", "signals_grunt"])


func test_the_dock_scene_does_not_replay_and_the_docks_are_calm_afterwards() -> void:
	var docks: FieldRoom = _load("harrow_docks", "from_square", true)
	await ExplorationKit.drive_scene(self, docks)
	docks.free()
	docks = _load("harrow_docks", "from_square", true)
	await ExplorationKit.ticks(self, 20)
	assert_false(docks.story.is_running(), "it only happens once")
	assert_false((docks.get_node("Kasp") as PlacedNpc).is_present())
	assert_eq(docks.party.followers.size(), 1, "Otis follows from the start of the room")
	assert_eq(docks.party.followers[0].member_id, "otis")
	assert_eq(_says(docks, "HandA"), "harrow_dock_hand_a_b2", "the dockhands thank her")


func test_a_lost_dock_fight_does_not_set_any_flag() -> void:
	var docks: FieldRoom = _load("harrow_docks", "from_square", true)
	# Nothing in the scene runs past the fight until it is won: stop the scene at the battle request.
	var asked: Array = []
	docks.field_battle_requested.connect(func(encounter: String, _id: String, _turn: String) -> void: asked.append(encounter))
	docks.story.run_scene("dock_scene")
	for i: int in 200:
		if docks.runner.is_running():
			docks.runner.confirm()
			docks.runner.tick(0.5)
		if not asked.is_empty():
			break
		await tree.physics_frame
	assert_eq(asked, ["dock_ambush"])
	assert_false(bool(_state.call("get_flag", "dock_fight_won")), "the flags wait for the win")
	assert_eq(_state.call("get_story_beat"), B1)


func test_the_mox_cameo_plays_once_when_red_first_steps_out() -> void:
	var square: FieldRoom = _load("harrow_square", "from_home", true)
	var mox: PlacedNpc = square.get_node("MoxCameo") as PlacedNpc
	var result: Dictionary = await ExplorationKit.drive_scene(self, square)
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "mox_cameo_seen")))
	assert_false(mox.is_present(), "he dashes off down the stairs")
	assert_false(square.player.frozen, "Red is never held for it")
	square.free()
	square = _load("harrow_square", "from_home", true)
	await ExplorationKit.ticks(self, 20)
	assert_false(square.story.is_running(), "once only")


func test_the_checkpoint_in_b1_shows_the_ticket_scene_and_a_closed_barrier() -> void:
	var checkpoint: FieldRoom = _load("harrow_checkpoint", "from_square", true)
	var result: Dictionary = await ExplorationKit.drive_scene(self, checkpoint)
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "checkpoint_b1_seen")))
	var road: Door = checkpoint.get_node("DoorRoad") as Door
	assert_false(road.is_unlocked())
	assert_eq(road.locked_message(), "Stair's closed. Signals business.")


func test_in_b2_otis_lifts_the_barrier_and_it_stays_open() -> void:
	_beat(B2)
	_state.call("set_flag", "otis_joined", true)
	_state.call("join_party", "otis")
	var checkpoint: FieldRoom = _load("harrow_checkpoint", "from_square", true)
	assert_not_null(checkpoint.party.follower_for("otis"))
	var road: Door = checkpoint.get_node("DoorRoad") as Door
	assert_false(road.is_unlocked())
	var result: Dictionary = await ExplorationKit.drive_scene(self, checkpoint)
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "checkpoint_open")))
	assert_true(road.is_unlocked(), "the road is open")
	assert_false(checkpoint.party.active == false, "the crew is back in line")
	checkpoint.free()
	checkpoint = _load("harrow_checkpoint", "from_square", true)
	await ExplorationKit.ticks(self, 20)
	assert_false(checkpoint.story.is_running(), "the scene does not replay")
	var arm: FlagPose = checkpoint.get_node("BarrierArm") as FlagPose
	assert_almost_eq(arm.rotation_degrees.z, 80.0, 0.5, "the boom barrier stays raised")


func test_the_road_door_goes_to_the_road_stub_and_back() -> void:
	var door: Door = _load("harrow_checkpoint").get_node("DoorRoad") as Door
	assert_eq(door.get_target_room(), "road_mast_road")
	assert_eq(door.get_target_spawn(), "from_harrow")
	var road: FieldRoom = ExplorationKit.load_room_at(self, "res://scenes/rooms/road/road_mast_road.tscn", "from_harrow")
	assert_eq((road.get_node("DoorHarrow") as Door).get_target_room(), "harrow_checkpoint")


func test_the_office_has_otis_say_the_crate_is_by_the_door_once_in_b2() -> void:
	_beat(B2)
	_state.call("set_flag", "otis_joined", true)
	_state.call("join_party", "otis")
	var office: FieldRoom = _load("harrow_dock_office", "from_docks", true)
	var result: Dictionary = await ExplorationKit.drive_scene(self, office)
	assert_true(result["ok"])
	assert_true(bool(_state.call("get_flag", "office_chime_seen")))


func test_home_again_and_the_legend_gags_play() -> void:
	_beat(B3)
	var home: FieldRoom = _load("harrow_home", "from_square", true)
	var result: Dictionary = await ExplorationKit.drive_scene(self, home)
	assert_true(result["ok"], "the walk home ends at the lamp")
	home.free()
	var square: FieldRoom = _load("harrow_square")
	var barfly: PlacedNpc = square.get_node("LegendBarfly") as PlacedNpc
	await ExplorationKit.stand_before(self, square, barfly)
	assert_true(square.interactor.try_interact())
	result = await ExplorationKit.drive_scene(self, square)
	assert_true(result["ok"], "the square's tall tale ends with Red's correction")
	square.free()
	_beat(B2)
	var bar: FieldRoom = _load("harrow_bar")
	assert_eq(_says(bar, "FlyC"), "legend_gag_bar")
	var fly: PlacedNpc = bar.get_node("FlyC") as PlacedNpc
	await ExplorationKit.stand_before(self, bar, fly)
	assert_true(bar.interactor.try_interact())
	result = await ExplorationKit.drive_scene(self, bar)
	assert_true(result["ok"], "the bar's version too")


func test_the_old_barfly_thanks_red_after_the_dark_window() -> void:
	var bar: FieldRoom = _load("harrow_bar")
	assert_eq(_says(bar, "OldBarfly"), "harrow_old_dark")
	_state.call("set_flag", "job_dark_window_done", true)
	assert_eq(_says(bar, "OldBarfly"), "harrow_old_done")


# ---- the home lamp, shops, hidden items ----

func test_red_s_window_lamp_rests_and_saves() -> void:
	var home: FieldRoom = _load("harrow_home", "start")
	var lamp: SaveLamp = home.get_node("SaveLamp") as SaveLamp
	assert_true(lamp.rest, "free full heal at home")
	assert_eq(lamp.room_id, "harrow_home")
	assert_eq(lamp.spawn_id, "start")
	assert_true(DataDB.get_dict("world/rooms")["rooms"]["harrow_home"]["spawns"].has(lamp.spawn_id), "Continue can router to it")
	await ExplorationKit.ticks(self, 4)
	home.interactor.refresh()
	assert_eq(home.interactor.get_target(), lamp, "Red starts the game right at the lamp")
	assert_true(SaveLamp.is_near_any(tree, home.player.global_position, 2.0), "the Camp Stove rule sees it")


func test_the_two_shops_open_from_their_counters() -> void:
	for entry: Array in [["harrow_store", "harrow_general"], ["harrow_gear", "harrow_gear"]]:
		var room: FieldRoom = _load(str(entry[0]))
		var counter: ShopCounter = room.get_node("ShopCounter") as ShopCounter
		assert_eq(counter.shop_id, str(entry[1]))
		assert_true(ShopData.has_shop(counter.shop_id))
		assert_eq(ShopData.validate(ShopData.load_shop(counter.shop_id)), [] as Array[String], "the stock is valid")
		var menu: ShopMenu = own(ShopMenu.install(tree, room.player)) as ShopMenu
		menu.manual_ticks = true
		menu.animations_enabled = false
		counter.shop_menu = menu
		await ExplorationKit.stand(self, room, counter.global_position + Vector3(0.0, 0.0, 1.0), counter.global_position)
		assert_eq(room.interactor.get_target(), counter)
		assert_true(room.interactor.try_interact())
		assert_true(menu.is_open(), "%s opened" % entry[1])
		assert_eq(menu.get_shop_id(), str(entry[1]))
		menu.close()
		for i: int in 4:
			menu.tick(0.016)
		room.free()
		await tree.process_frame


func test_the_gear_shop_sells_all_three_shop_weapons() -> void:
	var stock: Array = ShopData.load_shop("harrow_gear")["stock"]
	for weapon: String in ["rebar_blade", "rivet_hammer", "pipe_wrench"]:
		assert_has(stock, weapon)
	assert_does_not_have(stock, "earplugs", "found in town, not sold")
	assert_does_not_have(stock, "lucky_bolt", "a job reward, not sold")
	assert_does_not_have(ShopData.load_shop("harrow_general")["stock"], "appeal_form", "the Noise Ticket cure comes from the side job")


func test_the_five_hidden_items_are_each_granted_once() -> void:
	var hidden: Array = [
		["harrow_square", "AlleyStash", "smoke_bomb", 1, 60],
		["harrow_docks", "ChiliPickup", "can_of_chili", 2, 0],
		["harrow_docks", "PierCoffee", "canned_coffee", 2, 0],
		["harrow_checkpoint", "Bin", "earplugs", 1, 0],
		["harrow_bar", "JukeboxPickup", "ginger_chews", 2, 0],
	]
	for entry: Array in hidden:
		var room: FieldRoom = _load(str(entry[0]))
		var prop: RoomProp = room.get_node(str(entry[1])) as RoomProp
		var before: int = int(_state.call("item_count", str(entry[2])))
		var credits: int = int(_state.call("get_credits"))
		assert_true(prop.use(room.player, room.interactor), str(entry[1]))
		ExplorationKit.finish_conversation(room)
		assert_eq(int(_state.call("item_count", str(entry[2]))), before + int(entry[3]), "%s gives %s" % [entry[1], entry[2]])
		assert_eq(int(_state.call("get_credits")), credits + int(entry[4]))
		assert_false(prop.use(room.player, room.interactor), "only once")
		room.free()
		var again: FieldRoom = _load(str(entry[0]))
		var same: RoomProp = again.get_node(str(entry[1])) as RoomProp
		assert_false(same.use(again.player, again.interactor), "still gone when the room is entered again")
		again.free()


func test_the_starter_items_and_the_delivery_crate() -> void:
	var home: FieldRoom = _load("harrow_home")
	var tin: Pickup = home.get_node("PantryTin") as Pickup
	var rations: int = int(_state.call("item_count", "ration_bar"))
	assert_true(tin.use(home.player, home.interactor))
	assert_eq(int(_state.call("item_count", "ration_bar")), rations + 2)
	home.free()
	var office: FieldRoom = _load("harrow_dock_office")
	var crate: Pickup = office.get_node("DeliveryCrate") as Pickup
	assert_true(crate.use(office.player, office.interactor))
	assert_true(bool(_state.call("has_item", "delivery_crate")), "the key item is in the bag")
	assert_true(crate.last_messages.size() == 2 and crate.last_messages[1].contains("MOX WUZ HERE"), "the scratch on the lid")


func test_the_bridge_lamp_line_is_the_story_bibles_and_only_in_b2_and_later() -> void:
	var office: FieldRoom = _load("harrow_dock_office")
	var spot: SceneSpot = office.get_node("LampSpot") as SceneSpot
	assert_eq(str(spot.current_variant()["conversation"]), "harrow_ex_bridge_lamp_alone", "B1: just the lamp")
	_beat(B2)
	assert_eq(str(spot.current_variant()["conversation"]), "harrow_ex_bridge_lamp")
	var lines: Array = DataDB.get_dict("dialogue/harrow_town")["conversations"]["harrow_ex_bridge_lamp"]
	assert_eq(lines[1]["text"], "Came off a hull I hauled for the Navy. Somebody'd left it on.", "the locked line, word for word")
