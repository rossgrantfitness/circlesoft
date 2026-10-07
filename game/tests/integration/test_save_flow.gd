extends TestCase
## The save system inside the real game (M3-9): the lamp in the test room works through the
## interact button, Continue brings the saved game back, Retry restores the fight's start
## (and never writes a save), and Back to title then Continue loads the newest save.
## Uses the real SaveManager and GameState autoloads with the save folder pointed at a temp dir.

const ENCOUNTER: String = "grunt_pair"
const LAMP_NODE: String = "SaveLamp"
const LAMP_SPAWN: String = "LampSpawn"

var _manager: Node = null
var _state: Node = null
var _old_dir: String = ""
var _dir: String = ""


func before_each() -> void:
	_manager = tree.root.get_node("SaveManager")
	_state = tree.root.get_node("GameState")
	_old_dir = str(_manager.get("save_dir"))
	_dir = "user://test_flow_saves_%d" % Time.get_ticks_usec()
	_manager.set("save_dir", _dir)
	_state.call("reset")


func after_each() -> void:
	_manager.set("save_dir", _old_dir)
	_manager.set("battle_active", false)
	_state.set("playing", false)
	_state.call("reset")
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


func _stand_by_the_lamp(room: FieldRoom) -> SaveLamp:
	var lamp: SaveLamp = room.get_node(LAMP_NODE) as SaveLamp
	room.player.global_position = lamp.global_position + Vector3(0.0, 0.02, 0.9)
	room.player.rotation.y = 0.0
	return lamp


func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _save_in_slot_one_at_the_lamp(main: Main) -> void:
	var room: FieldRoom = main.get_room() as FieldRoom
	var lamp: SaveLamp = _stand_by_the_lamp(room)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(room.interactor.try_interact(), "the interact button takes the lamp")
	assert_true(lamp.is_checking())
	assert_true(room.player.frozen, "Red stays put during the check")
	lamp.skip()
	var prompt: SavePrompt = lamp.get_prompt() as SavePrompt
	assert_not_null(prompt)
	prompt.finish_animations()
	prompt.handle_command(MenuInput.Cmd.CONFIRM)
	prompt.handle_command(MenuInput.Cmd.CONFIRM)
	prompt.finish_animations()
	await _frames(8)


func test_the_lamp_in_the_test_room_saves_a_game_through_the_interact_button() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	assert_not_null(room.get_node_or_null(LAMP_NODE), "the test room has a save lamp")
	_state.call("add_credits", 321)
	await _save_in_slot_one_at_the_lamp(main)
	assert_true(FileAccess.file_exists(_dir + "/slot_1.json"))
	assert_eq(_manager.call("slot_summary", 1)["credits"], 321)
	assert_eq(_state.call("get_location"), {"room": "test_room", "spawn": LAMP_SPAWN})
	assert_false(room.player.frozen, "Red is free again")
	assert_false(UiStage.is_busy(tree), "and the interact button works again")
	assert_false((room.get_node(LAMP_NODE) as SaveLamp).is_checking())


func test_continue_brings_the_saved_game_back_and_stands_red_at_the_lamp() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	_state.call("add_credits", 321)
	_state.call("set_flag", "before_the_save")
	await _save_in_slot_one_at_the_lamp(main)
	_state.call("add_credits", 1000)
	_state.call("set_flag", "after_the_save")
	_state.call("tick_play_time", 10.0)
	assert_true(main.can_continue())
	assert_true(main.continue_game())
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_eq(_state.call("get_credits"), 321)
	assert_true(_state.call("get_flag", "before_the_save"))
	assert_false(_state.call("get_flag", "after_the_save"))
	var room: FieldRoom = main.get_room() as FieldRoom
	var spawn: Marker3D = room.get_node(LAMP_SPAWN) as Marker3D
	assert_lt(room.player.global_position.distance_to(spawn.global_position), 0.3, "Red stands at the lamp")


func test_continue_with_no_save_does_nothing() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	_state.call("add_credits", 5)
	assert_false(main.can_continue())
	assert_false(main.continue_game())
	assert_eq(_state.call("get_credits"), 5)
	assert_eq(main.get_state(), Main.State.ROOM)


func test_new_game_starts_clean() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	_state.call("add_credits", 5)
	_state.call("mark_opened", "crate")
	main.start_new_game()
	await tree.process_frame
	assert_eq(_state.call("get_credits"), 0)
	assert_false(_state.call("is_opened", "crate"))
	assert_eq(main.get_state(), Main.State.ROOM)


func test_play_time_only_ticks_in_the_field() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await _frames(3)
	assert_true(bool(_state.get("playing")), "the clock runs in the room")
	var before: float = float(_state.call("get_play_time_s"))
	await _frames(10)
	assert_gt(float(_state.call("get_play_time_s")), before)
	main.go_to_title()
	assert_false(bool(_state.get("playing")), "and stops on the title screen")


func test_retry_restores_the_fights_start_and_writes_no_save() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	_state.call("add_item", "ration_bar", 2)
	_state.call("mark_opened", "crate_before")
	_state.call("set_location", "test_room", "PlayerSpawn")
	_state.call("add_credits", 40)
	var bag_before: int = int(_state.call("item_count", "ration_bar"))
	var calls: Array[int] = [0]
	var lose: Callable = BattleFlowKit.losing_hook(main)
	var win: Callable = BattleFlowKit.winning_hook(main)
	main.battle_setup_hook = func(setup: BattleSetup) -> void:
		calls[0] += 1
		if calls[0] == 1:
			lose.call(setup)
		else:
			win.call(setup)
	main.start_battle(ENCOUNTER)
	assert_true(bool(_manager.get("battle_active")), "the auto-save is held back during a fight")
	var first_stage_id: int = main.get_battle().get_instance_id()
	_state.call("add_item", "ration_bar", 5)
	_state.call("mark_opened", "crate_during")
	_state.call("add_credits", 500)
	_state.call("set_location", "somewhere", "else")
	_manager.call("notify_room_entered", "mid_fight_room", "x")
	assert_false(FileAccess.file_exists(_dir + "/auto.json"), "no auto-save mid-battle")
	_state.call("add_credits", 0)
	var time_in_fight: float = float(_state.call("get_play_time_s"))
	var pressed: Array[bool] = [false]
	var start: int = Time.get_ticks_msec()
	while not pressed[0] and Time.get_ticks_msec() - start < BattleFlowKit.WAIT_LIMIT_MS:
		var stage: BattleScene = main.get_battle() as BattleScene
		if stage != null and stage.result == "lose" and stage.hud != null:
			stage.hud.emit_signal("finished", "lose", "retry")
			pressed[0] = true
		await tree.process_frame
	assert_true(pressed[0], "the fight was lost")
	assert_true(await BattleFlowKit.wait_for_new_stage(tree, main, first_stage_id), "the same fight started again")
	assert_eq(int(_state.call("item_count", "ration_bar")), bag_before)
	assert_false(_state.call("is_opened", "crate_during"))
	assert_true(_state.call("is_opened", "crate_before"))
	assert_eq(_state.call("get_credits"), 40)
	assert_eq(_state.call("get_location")["spawn"], "PlayerSpawn", "even the place is back")
	assert_ge(float(_state.call("get_play_time_s")), time_in_fight, "the clock is not rewound")
	assert_eq(DirAccess.get_files_at(_dir).size() if DirAccess.dir_exists_absolute(_dir) else 0, 0, "Retry writes no save")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"))


func test_back_to_title_then_continue_loads_the_newest_save() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	_state.call("add_credits", 77)
	await _save_in_slot_one_at_the_lamp(main)
	_state.call("add_credits", 500)
	main.battle_setup_hook = BattleFlowKit.losing_hook(main)
	main.start_battle(ENCOUNTER)
	assert_true(await BattleFlowKit.finish_fight(tree, main, "title"))
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_true(main.can_continue())
	assert_true(main.continue_game())
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_eq(_state.call("get_credits"), 77, "back to the last save, not the lost fight")
