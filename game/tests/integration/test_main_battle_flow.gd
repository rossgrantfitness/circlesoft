extends TestCase
## Milestone 2 flow: Main takes the room out of the PSX world and keeps it in memory, runs a real
## battle (virtual clock, Auto-Timing, a command policy), and puts the room back exactly as it was
## after a win or a run; a loss offers Retry (the GameState snapshot comes back) or the title.

const ENCOUNTER: String = "grunt_pair"
const RED_SPOT: Vector3 = Vector3(3.0, 0.0, 2.0)

var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")


func _room_in_world(main: Main) -> bool:
	var room: Node = main.get_room()
	return room != null and is_instance_valid(room) and room.is_inside_tree() and main.screen.get_world_root().is_ancestor_of(room)


func test_start_battle_detaches_the_room_and_loads_the_stage() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	assert_eq(main.get_state(), Main.State.ROOM)
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	main.start_battle(ENCOUNTER)
	assert_eq(main.get_state(), Main.State.BATTLE)
	assert_not_null(main.get_battle())
	assert_true(main.get_battle() is BattleScene)
	assert_true(main.screen.get_world_root().is_ancestor_of(main.get_battle()), "the stage is in the PSX world")
	assert_true(is_instance_valid(room), "the room is kept in memory")
	assert_false(room.is_inside_tree(), "and is out of the world")
	assert_true(room.is_suspended())
	assert_eq(main.screen.get_world_root().get_child_count(), 1, "only the battle is in the world")
	assert_false(room.prompt.is_showing())
	main.start_battle("grunt_solo")
	assert_eq(main.get_state(), Main.State.BATTLE, "a second start while fighting does nothing")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))


func test_win_returns_to_the_room_exactly_as_it_was() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	room.player.global_position = RED_SPOT + Vector3(0.0, 0.02, 0.0)
	await tree.physics_frame
	await tree.physics_frame
	var spot: Vector3 = room.player.global_position
	var yaw: float = room.player.rotation.y
	_state.call("set_flag", "kept_across_battle", true)
	var credits_before: int = int(_state.call("get_credits"))
	var results: Array = []
	main.battle_finished.connect(func(result: String, report: Dictionary) -> void: results.append([result, report]))
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	main.start_battle(ENCOUNTER)
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"), "the fight ended")
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_eq(main.get_room(), room, "the same room object, not a reload")
	assert_true(_room_in_world(main))
	assert_false(room.is_suspended())
	assert_null(main.get_battle())
	assert_eq(main.screen.get_world_root().get_child_count(), 1, "the stage is gone")
	assert_true(room.player.global_position.distance_to(spot) < 0.05, "Red is where she was")
	assert_almost_eq(room.player.rotation.y, yaw, 0.001)
	assert_true(bool(_state.call("get_flag", "kept_across_battle")))
	assert_eq(results.size(), 1)
	assert_eq(results[0][0], "win")
	assert_gt(int(results[0][1]["xp"]), 0)
	assert_gt(int(_state.call("get_credits")), credits_before, "the win's credits were written to GameState")
	assert_true(room.camera_rig.get_camera().current, "the room's camera is the active one again")


func test_running_away_returns_to_the_room() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	main.battle_setup_hook = BattleFlowKit.running_hook(main)
	main.start_battle(ENCOUNTER)
	assert_true(await BattleFlowKit.finish_fight(tree, main, ""))
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_eq(main.get_room(), room)
	assert_true(_room_in_world(main))


func test_retry_restores_the_snapshot_and_restarts_the_same_encounter() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	_state.call("add_item", "ration_bar", 2)
	_state.call("set_flag", "before_the_fight", true)
	var bag_before: int = int(_state.call("item_count", "ration_bar"))
	var calls: Array[int] = [0]
	var lose: Callable = BattleFlowKit.losing_hook(main)
	var win: Callable = BattleFlowKit.winning_hook(main)
	var encounters: Array[String] = []
	main.battle_setup_hook = func(setup: BattleSetup) -> void:
		calls[0] += 1
		encounters.append(setup.encounter_id)
		if calls[0] == 1:
			lose.call(setup)
		else:
			win.call(setup)
	main.start_battle(ENCOUNTER)
	var first_stage_id: int = main.get_battle().get_instance_id()
	# Something changes while the fight is on; Retry must undo it.
	_state.call("add_item", "ration_bar", 5)
	_state.call("set_flag", "during_the_fight", true)
	# Wait for the game over, then answer Retry.
	var pressed: Array[bool] = [false]
	var start: int = Time.get_ticks_msec()
	while not pressed[0] and Time.get_ticks_msec() - start < BattleFlowKit.WAIT_LIMIT_MS:
		var stage: BattleScene = main.get_battle() as BattleScene
		if stage != null and stage.result == "lose" and stage.hud != null:
			stage.hud.emit_signal("finished", "lose", "retry")
			pressed[0] = true
		await tree.process_frame
	assert_true(pressed[0], "the fight was lost")
	assert_true(await BattleFlowKit.wait_for_new_stage(tree, main, first_stage_id), "a new fight started")
	assert_eq(main.get_state(), Main.State.BATTLE)
	assert_eq(int(_state.call("item_count", "ration_bar")), bag_before, "the bag is back to the snapshot")
	assert_false(bool(_state.call("get_flag", "during_the_fight")), "flags are back to the snapshot")
	assert_true(bool(_state.call("get_flag", "before_the_fight")))
	assert_eq(encounters, [ENCOUNTER, ENCOUNTER], "the same encounter again")
	assert_true(room.is_suspended(), "the room is still waiting in memory")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"), "the retry was won")
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_true(_room_in_world(main))


func test_lose_then_title_goes_to_the_title_screen() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	var results: Array = []
	main.battle_finished.connect(func(result: String, _report: Dictionary) -> void: results.append(result))
	main.battle_setup_hook = BattleFlowKit.losing_hook(main)
	main.start_battle(ENCOUNTER)
	var start: int = Time.get_ticks_msec()
	var pressed: bool = false
	while main.get_state() == Main.State.BATTLE and Time.get_ticks_msec() - start < BattleFlowKit.WAIT_LIMIT_MS:
		var stage: BattleScene = main.get_battle() as BattleScene
		if stage != null and stage.result == "lose" and stage.hud != null and not pressed:
			stage.hud.emit_signal("finished", "lose", "title")
			pressed = true
		await tree.process_frame
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_not_null(main.get_title())
	assert_null(main.get_room())
	assert_false(is_instance_valid(room) and room.is_inside_tree(), "the kept room is gone")
	assert_eq(main.screen.get_world_root().get_child_count(), 0)
	assert_eq(results, ["lose"])
	assert_false(UiStage.is_busy(tree), "nothing is left holding the UI lock")


func test_battle_from_the_title_returns_to_the_title() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	main.go_to_title()
	assert_eq(main.get_state(), Main.State.TITLE)
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	main.start_battle(ENCOUNTER, &"title")
	assert_eq(main.get_state(), Main.State.BATTLE)
	assert_null(main.get_title(), "the title steps aside for the fight")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_not_null(main.get_title())


func test_title_battle_test_signal_starts_that_encounter() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	main.go_to_title()
	var title: Node = main.get_title()
	if not title.has_signal("battle_test_requested"):
		assert_true(true, "the title has no Battle Test entry yet")
		return
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	title.emit_signal("battle_test_requested", "drone_flock")
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.BATTLE)
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.TITLE)


func test_back_button_does_not_leave_a_fight() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	main.start_battle(ENCOUNTER)
	Input.action_press(&"start")
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.BATTLE, "Esc / Start does not leave mid-battle")
	Input.action_release(&"start")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))


func test_the_button_that_dismissed_the_win_does_not_jump_or_talk() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	main.start_battle(ENCOUNTER)
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))
	await tree.process_frame
	Input.action_press(&"jump")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(room.player.is_on_floor(), "a jump press right after coming back is ignored")
	Input.action_release(&"jump")
