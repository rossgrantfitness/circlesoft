extends TestCase
## The save screen and the save lamp (M3-9): the prompt's slot list, saving over a slot (asks
## first), the auto-save row, the lamp check (full first, short after, skippable), resting only
## where the lamp says so, and the lamp's place in the interact button.

const MANAGER_PATH: String = "res://scripts/core/save_manager.gd"
const STATE_PATH: String = "res://scripts/core/game_state.gd"
const Cmd: Variant = MenuInput.Cmd

var _dir: String = ""
var _now: float = 1000.0
var _state: Node = null
var _manager: Node = null
var _busy_before: Array[Node] = []


func before_each() -> void:
	_busy_before = SaveTestKit.busy_now(tree)
	_dir = "user://test_lamp_saves_%d" % Time.get_ticks_usec()
	_now = 1000.0
	_state = own((load(STATE_PATH) as GDScript).new() as Node) as Node
	_state.call("load_party", DataDB.get_dict("party/party"))
	_state.call("reset")
	_manager = add_to_root((load(MANAGER_PATH) as GDScript).new() as Node) as Node
	_manager.set("save_dir", _dir)
	_manager.set("game_state", _state)
	_manager.set("clock", func() -> float: return _now)
	# Our own stage, so SavePrompt.open() builds on it and the test frees it.
	add_to_root(UiStage.new())


func after_each() -> void:
	# SavePrompt.open() builds on the first UiStage in the tree, which may be an older one that outlives
	# this test, so the kit takes our screens down and checks the busy group is back to how it was.
	SaveTestKit.tear_down(self, _busy_before)
	_remove_dir(_dir)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _prompt(rest: bool = false, red: Node = null) -> SavePrompt:
	var host: Control = Control.new()
	host.size = Vector2(384, 216)
	add_to_root(host)
	var prompt: SavePrompt = SavePrompt.new()
	prompt.manual_ticks = true
	prompt.animations_enabled = false
	prompt.manager = _manager
	prompt.rest = rest
	prompt.player = red
	host.add_child(prompt)
	assert_true(prompt.open_screen())
	return prompt


func _press(prompt: SavePrompt, command: MenuInput.Cmd, times: int = 1) -> void:
	for i: int in times:
		prompt.handle_command(command)


func _slot_text(slot: int) -> String:
	return FileAccess.get_file_as_string(_manager.call("slot_path", slot))


# ---- the save screen ----

func test_it_lists_three_slots_and_the_auto_save() -> void:
	var prompt: SavePrompt = _prompt()
	var list: MenuList = prompt.get_list()
	assert_eq(prompt.get_state(), SavePrompt.State.PICK)
	assert_eq(list.get_count(), 4)
	assert_true(list.get_items()[0]["label"].contains("Slot 1"))
	assert_true(list.get_items()[0]["label"].contains("empty"))
	assert_true(list.get_items()[3]["label"].contains("Auto"))
	assert_false(bool(list.get_items()[3]["enabled"]), "the auto row can't be picked")
	assert_true(prompt.is_in_group(UiStage.MODAL_GROUP), "field input is locked out while it is up")


func test_rows_show_place_play_time_and_the_party() -> void:
	_state.call("set_location", "test_room", "lamp")
	_state.call("tick_play_time", 3725.0)
	_manager.call("save_slot", 2)
	_manager.call("auto_save")
	var prompt: SavePrompt = _prompt()
	var items: Array[Dictionary] = prompt.get_list().get_items()
	assert_true(items[1]["label"].contains("Test Room"))
	assert_eq(items[1]["value"], "1:02:05")
	assert_true(items[3]["label"].contains("Test Room"), "the auto row shows its save too")
	assert_true(items[0]["value"].is_empty())


func test_saving_into_an_empty_slot_just_saves() -> void:
	var prompt: SavePrompt = _prompt()
	var saved: Array[int] = []
	var closed: Array[int] = []
	prompt.slot_saved.connect(func(slot: int) -> void: saved.append(slot))
	prompt.closed.connect(func(slot: int) -> void: closed.append(slot))
	_press(prompt, Cmd.DOWN)
	_press(prompt, Cmd.CONFIRM)
	assert_eq(saved, [2] as Array[int])
	assert_true(FileAccess.file_exists(_dir + "/slot_2.json"))
	assert_eq(prompt.get_state(), SavePrompt.State.DONE)
	assert_eq(prompt.get_hint(), "Saved. Lamp stays on.")
	# A new game starts in rooms.json's start_room (Red's home in Harrow Landing), so that is the place saved.
	var start_name: String = str(DataDB.get_value("world/rooms", "rooms.%s.name" % DataDB.get_value("world/rooms", "start_room")))
	assert_true(prompt.get_list().get_items()[1]["label"].contains(start_name), "the row updates at once")
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.CLOSED)
	assert_eq(closed, [2] as Array[int])


func test_saving_over_a_used_slot_asks_first_and_defaults_to_keeping_it() -> void:
	_manager.call("save_slot", 1)
	var before: String = _slot_text(1)
	_now = 2000.0
	_state.call("add_credits", 50)
	var prompt: SavePrompt = _prompt()
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.CONFIRM)
	assert_eq(prompt.get_hint(), "Save over this one?")
	assert_eq(prompt.get_confirm_list().get_cursor_index(), 1, "the cursor starts on the head shake")
	assert_eq(_slot_text(1), before, "nothing written yet")
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.PICK, "Keep it goes back to the slots")
	assert_eq(_slot_text(1), before)
	_press(prompt, Cmd.CONFIRM)
	_press(prompt, Cmd.CANCEL)
	assert_eq(prompt.get_state(), SavePrompt.State.PICK, "cancel also keeps it")
	assert_eq(_slot_text(1), before)
	_press(prompt, Cmd.CONFIRM)
	_press(prompt, Cmd.UP)
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.DONE)
	assert_ne(_slot_text(1), before, "thumbs-up saved over it")
	assert_eq(int(JSON.parse_string(_slot_text(1))["game"]["credits"]), 50)


func test_the_auto_save_row_cannot_be_saved_over_by_hand() -> void:
	_manager.call("auto_save")
	var before: String = _slot_text(0)
	_now = 3000.0
	var prompt: SavePrompt = _prompt()
	_press(prompt, Cmd.UP)
	assert_eq(prompt.get_list().get_cursor_index(), 3, "the cursor can rest on it")
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.PICK)
	assert_eq(_slot_text(0), before)


func test_cancel_closes_without_saving() -> void:
	var prompt: SavePrompt = _prompt()
	var closed: Array[int] = []
	prompt.closed.connect(func(slot: int) -> void: closed.append(slot))
	_press(prompt, Cmd.CANCEL)
	assert_eq(closed, [-1] as Array[int])
	assert_false(FileAccess.file_exists(_dir + "/slot_1.json"))


func test_a_failed_save_says_so_and_stays_open() -> void:
	DirAccess.make_dir_recursive_absolute(_dir + "/slot_1.json.tmp")
	var prompt: SavePrompt = _prompt()
	_press(prompt, Cmd.CONFIRM)
	assert_eq(prompt.get_state(), SavePrompt.State.PICK)
	assert_eq(prompt.get_hint(), "Couldn't write the save. Try another slot.")


func test_resting_heals_the_party_before_the_screen_opens() -> void:
	_state.call("update_member", "red", {"hp": 2, "juice": 0})
	var prompt: SavePrompt = _prompt(true)
	var red: Dictionary = _state.call("get_member", "red")
	assert_eq(int(red["hp"]), int(red["hp_max"]))
	assert_eq(int(red["juice"]), int(red["juice_max"]))
	assert_eq(prompt.get_hint(), "The crew is rested up. Which slot?")


func test_no_rest_leaves_hp_alone() -> void:
	_state.call("update_member", "red", {"hp": 2})
	_prompt(false)
	assert_eq(int(_state.call("get_member", "red")["hp"]), 2, "save lamps save; they don't heal")


func test_the_player_is_frozen_while_it_is_up_and_freed_after() -> void:
	var red: Node = own(FakePlayer.new()) as Node
	var prompt: SavePrompt = _prompt(false, red)
	assert_true(bool(red.get("frozen")))
	_press(prompt, Cmd.CANCEL)
	for i: int in 3:
		prompt.tick(0.02)
	assert_false(bool(red.get("frozen")), "released a couple of frames after")


func test_the_press_that_opened_it_does_not_pick_a_slot() -> void:
	var prompt: SavePrompt = _prompt()
	prompt.set("_arm_left", 3)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"confirm"
	press.pressed = true
	prompt._input(press)
	assert_false(FileAccess.file_exists(_dir + "/slot_1.json"), "armed frames swallow the first presses")
	for i: int in 3:
		prompt.tick(0.01)
	prompt._input(press)
	assert_true(FileAccess.file_exists(_dir + "/slot_1.json"))


# ---- the lamp check ----

func _lamp(rest: bool = false) -> SaveLamp:
	var lamp: SaveLamp = SaveLamp.new()
	lamp.manual_ticks = true
	lamp.read_engine_input = false
	lamp.save_manager = _manager
	lamp.game_state = _state
	lamp.rest = rest
	lamp.room_id = "test_room"
	lamp.spawn_id = "LampSpawn"
	add_to_root(lamp)
	return lamp


func _run_beats(lamp: SaveLamp, max_seconds: float = 10.0) -> void:
	var waited: float = 0.0
	while lamp.get_phase() == SaveLamp.Phase.BEATS or lamp.get_phase() == SaveLamp.Phase.GESTURE:
		lamp.tick(0.1)
		waited += 0.1
		if waited > max_seconds:
			fail("the lamp check never ended")
			return


func _close_prompt(lamp: SaveLamp) -> void:
	var prompt: SavePrompt = lamp.get_prompt() as SavePrompt
	prompt.finish_animations()
	_press(prompt, Cmd.CANCEL)
	prompt.finish_animations()
	for i: int in 4:
		lamp.tick(0.02)


func test_the_lamp_is_a_placeholder_glow_in_the_interactable_group() -> void:
	var lamp: SaveLamp = _lamp()
	assert_true(lamp.is_in_group(Interactable.GROUP))
	assert_true(lamp.is_in_group(SaveLamp.GROUP_LAMP))
	assert_not_null(lamp.get_node_or_null("Bulb"))
	assert_not_null(lamp.get_node_or_null("Light"))
	assert_eq(lamp.current_conversation(), "lamp_check")
	assert_eq(lamp.current_kind_name(), "examine")


func test_the_first_check_is_full_and_the_next_is_short() -> void:
	var lamp: SaveLamp = _lamp()
	var fulls: Array[bool] = []
	lamp.check_started.connect(func(full: bool) -> void: fulls.append(full))
	assert_true(lamp.start_check())
	assert_false(lamp.start_check(), "one check at a time")
	var full_length: int = 0
	while lamp.get_phase() == SaveLamp.Phase.BEATS or lamp.get_phase() == SaveLamp.Phase.GESTURE:
		lamp.tick(0.1)
		full_length += 1
		if full_length > 200:
			break
	assert_eq(lamp.get_phase(), SaveLamp.Phase.MENU, "the save screen opens when the check is over")
	assert_not_null(lamp.get_prompt())
	_close_prompt(lamp)
	assert_eq(lamp.get_phase(), SaveLamp.Phase.IDLE)
	assert_true(lamp.start_check())
	var short_length: int = 0
	while lamp.get_phase() == SaveLamp.Phase.BEATS or lamp.get_phase() == SaveLamp.Phase.GESTURE:
		lamp.tick(0.1)
		short_length += 1
		if short_length > 200:
			break
	assert_eq(fulls, [true, false] as Array[bool])
	assert_lt(short_length, full_length, "the short check is shorter")
	assert_true(lamp.is_lit(), "the lamp stays lit")


func test_one_press_skips_the_check() -> void:
	var lamp: SaveLamp = _lamp()
	var skipped: Array[bool] = []
	lamp.check_skipped.connect(func() -> void: skipped.append(true))
	lamp.start_check()
	lamp.tick(0.1)
	lamp.skip()
	assert_eq(lamp.get_phase(), SaveLamp.Phase.MENU)
	assert_eq(skipped.size(), 1)
	assert_not_null(lamp.get_prompt())
	lamp.skip()
	assert_eq(skipped.size(), 1, "skipping again does nothing")
	assert_false(_manager.call("is_first_lamp_check"), "a skipped check still counts: the next one is short")


func test_the_lamp_locks_field_input_until_the_screen_is_gone() -> void:
	var lamp: SaveLamp = _lamp()
	lamp.start_check()
	assert_true(lamp.is_in_group(UiStage.MODAL_GROUP), "the interact button is locked out during the check")
	lamp.skip()
	assert_true(lamp.is_in_group(UiStage.MODAL_GROUP))
	_close_prompt(lamp)
	assert_false(lamp.is_in_group(UiStage.MODAL_GROUP))
	assert_eq(lamp.get_phase(), SaveLamp.Phase.IDLE)


func test_a_dungeon_lamp_saves_but_does_not_heal() -> void:
	_state.call("update_member", "red", {"hp": 2})
	var lamp: SaveLamp = _lamp(false)
	lamp.start_check()
	lamp.skip()
	assert_eq(int(_state.call("get_member", "red")["hp"]), 2)
	_close_prompt(lamp)


func test_a_resting_lamp_heals_the_party() -> void:
	_state.call("update_member", "red", {"hp": 2, "juice": 0})
	var lamp: SaveLamp = _lamp(true)
	lamp.start_check()
	_run_beats(lamp)
	var red: Dictionary = _state.call("get_member", "red")
	assert_eq(int(red["hp"]), int(red["hp_max"]))
	_close_prompt(lamp)


func test_a_save_made_at_the_lamp_remembers_the_lamp() -> void:
	_state.call("set_location", "somewhere_else", "door")
	var lamp: SaveLamp = _lamp()
	lamp.start_check()
	lamp.skip()
	var prompt: SavePrompt = lamp.get_prompt() as SavePrompt
	prompt.finish_animations()
	_press(prompt, Cmd.CONFIRM)
	var summary: Dictionary = _manager.call("slot_summary", 1)
	assert_eq(summary["place"], "Test Room")
	_state.call("reset")
	_manager.call("load_slot", 1)
	assert_eq(_state.call("get_location"), {"room": "test_room", "spawn": "LampSpawn"})
	_press(prompt, Cmd.CONFIRM)
	prompt.finish_animations()
	for i: int in 4:
		lamp.tick(0.02)


func test_the_player_is_frozen_for_the_whole_check_and_freed_after() -> void:
	var lamp: SaveLamp = _lamp()
	var red: Node = own(FakePlayer.new()) as Node
	lamp.player = red
	lamp.start_check()
	assert_true(bool(red.get("frozen")))
	lamp.skip()
	assert_true(bool(red.get("frozen")))
	_close_prompt(lamp)
	assert_false(bool(red.get("frozen")), "back to how she was")


func test_nearby_lamps_are_found_for_the_camp_stove() -> void:
	var lamp: SaveLamp = _lamp()
	lamp.global_position = Vector3(2.0, 0.0, 2.0)
	assert_true(SaveLamp.is_near_any(tree, Vector3(2.5, 0.0, 2.5)))
	assert_false(SaveLamp.is_near_any(tree, Vector3(9.0, 0.0, 9.0)))


class FakePlayer extends Node:
	var frozen: bool = false
