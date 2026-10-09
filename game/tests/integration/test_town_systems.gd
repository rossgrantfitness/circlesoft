extends TestCase
## VS-15, the town systems end to end with the new Red, in the throwaway graybox hub (data/slice/graybox_rooms.json): talking
## and bubbles, ambient barks, a shop through ShopLogic, the job board, the save terminal (with rest), and the field menu
## opened from the pause menu (items heal the action Red, the sword page equips). The attack button does the talking (Decision 3, A).

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _old_save_dir: String = ""
var _save_dir: String = ""


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_old_save_dir = str(_manager.get("save_dir"))
	_save_dir = "user://test_town_saves_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_save_dir)
	_manager.set("saving_allowed", true)
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	Placements.extra_job_ids = []
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	_remove_dir(_save_dir)
	SandboxPauseGate.clear(tree)
	for action: StringName in [&"light", &"interact", &"jump"]:
		Input.action_release(action)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _start() -> ActionRoom:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_router.set("rooms_id", ROOMS_ID)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.set("rooms_data_id", ROOMS_ID)
	Placements.extra_ids = [PLACEMENTS_ID] as Array[String]
	Placements.extra_job_ids = ["slice/graybox_jobs"] as Array[String]
	_manager.set("save_dir", _save_dir)
	_main.start_new_game()
	var room: ActionRoom = await _until_room("gb_hub")
	room.hero.read_engine_input = false
	room.interactor.read_engine_input = false
	room.runner.manual_ticks = true
	room.runner.chars_per_second_override = 100000.0
	room.barks.set_physics_process(false)
	room.barks.manual_ticks = true
	return room


func _until_room(room_id: String, limit: int = 120) -> ActionRoom:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


## Stands Red `distance` metres in front of a prop (on its +Z side), looking at it.
func _stand_before(room: ActionRoom, prop: Node3D, distance: float = 1.0) -> void:
	room.hero.global_position = prop.global_position + Vector3(0.0, 0.02, -distance)
	room.hero.rotation.y = 0.0               # faces +Z, toward the prop
	room.hero.velocity = Vector3.ZERO
	for i: int in 4:
		await tree.physics_frame
	room.interactor.refresh()


func _tick(room: ActionRoom, frames: int) -> void:
	for i: int in frames:
		room.hero.tick(1.0 / 60.0)


# ---- talking ----

func test_talking_to_a_townsperson_freezes_red_and_hands_her_back() -> void:
	var room: ActionRoom = await _start()
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	await _stand_before(room, vendor, 0.9)
	assert_not_null(room.interactor.get_target(), "the vendor is in front of her")
	assert_true(room.interactor.try_interact())
	assert_true(room.runner.is_running())
	assert_true(room.hero.frozen, "talking freezes the action Red")
	ExplorationKit.finish_conversation(room)
	for i: int in 4:
		room.runner.tick(0.1)
	assert_false(room.hero.frozen)
	assert_false(room.runner.is_running())


func test_the_attack_button_talks_in_town_and_does_not_swing() -> void:
	var room: ActionRoom = await _start()
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	await _stand_before(room, vendor, 0.9)
	room.hero.press(&"light")
	_tick(room, 3)
	assert_true(room.runner.is_running(), "one press of the attack button started the conversation")
	assert_ne(room.hero.get_state(), ActionPlayer.State.ATTACK)


func test_bubbles_follow_the_npcs_on_screen() -> void:
	var room: ActionRoom = await _start()
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	await _stand_before(room, vendor, 3.0)
	await tree.physics_frame
	assert_ne(room.screen_pos_of(&"crowd_bettor", &"head"), Vector2.ZERO, "ActionRoom gives the bubble the same answer for NPCs as for fighters")
	assert_true(room.runner.has_speaker("crowd_bettor"))
	assert_eq(room.runner.camera, room.get_camera_3d(), "the runner projects through the hero's camera")


# ---- ambient barks ----

func test_a_townsperson_barks_when_red_walks_past_and_never_stops_her() -> void:
	var room: ActionRoom = await _start()
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	var heard: Array[String] = []
	room.barks.barked.connect(func(_speaker: String, text: String) -> void: heard.append(text))
	room.hero.global_position = vendor.global_position + Vector3(0.0, 0.02, 2.0)
	var who: PlacedNpc = room.barks.tick(0.1)
	assert_not_null(who, "she is inside bark_radius_m")
	assert_eq(heard, ["Fresh scrap noodles!"] as Array[String])
	assert_eq(room.barks.live_count(), 1, "a short bubble is up")
	assert_false(room.hero.frozen, "a bark does not freeze her")
	assert_false(UiStage.is_busy(tree), "and it is not a menu: she can still walk, talk and use doors")
	assert_true(room.interactor.can_interact())


func test_barks_wait_for_the_cooldown_then_take_the_next_line() -> void:
	var room: ActionRoom = await _start()
	room.barks.show_bubbles = false
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	var heard: Array[String] = []
	room.barks.barked.connect(func(_speaker: String, text: String) -> void: heard.append(text))
	room.hero.global_position = vendor.global_position + Vector3(0.0, 0.02, 2.0)
	room.barks.tick(0.1)
	room.barks.tick(2.0)
	assert_eq(heard.size(), 1, "inside the 6 s cooldown: quiet")
	room.barks.tick(5.0)
	assert_eq(heard, ["Fresh scrap noodles!", "Two creds a bowl."] as Array[String], "the next line in turn")


func test_barks_stay_quiet_out_of_range_and_during_a_talk_or_a_freeze() -> void:
	var room: ActionRoom = await _start()
	room.barks.show_bubbles = false
	var vendor: Node3D = room.find_child("Vendor", true, false) as Node3D
	var heard: Array[String] = []
	room.barks.barked.connect(func(_speaker: String, text: String) -> void: heard.append(text))
	room.hero.global_position = vendor.global_position + Vector3(0.0, 0.02, 7.0)
	room.barks.tick(0.1)
	assert_eq(heard.size(), 0, "too far")
	room.hero.global_position = vendor.global_position + Vector3(0.0, 0.02, 2.0)
	room.hero.frozen = true
	room.barks.tick(0.1)
	assert_eq(heard.size(), 0, "she is frozen (a menu or a talk)")
	room.hero.frozen = false
	room.barks.tick(0.1)
	assert_eq(heard.size(), 1)


# ---- the shop ----

func test_a_shop_counter_sells_to_the_action_red_through_shop_logic() -> void:
	var room: ActionRoom = await _start()
	_state.call("add_credits", 500)
	var counter: ShopCounter = room.find_child("Counter", true, false) as ShopCounter
	var menu: ShopMenu = own(ShopMenu.install(tree, room.hero)) as ShopMenu
	menu.manual_ticks = true
	menu.animations_enabled = false
	counter.shop_menu = menu
	await _stand_before(room, counter, 1.0)
	assert_eq(room.interactor.get_target(), counter)
	room.hero.press(&"light")                      # the attack button opens the shop in town
	_tick(room, 3)
	assert_true(menu.is_open(), "the counter opened")
	assert_true(room.hero.frozen)
	var before: int = int(_state.call("item_count", "ration_bar"))
	menu.handle_command(MenuInput.Cmd.CONFIRM)     # Buy
	menu.handle_command(MenuInput.Cmd.CONFIRM)     # first row
	menu.handle_command(MenuInput.Cmd.CONFIRM)     # one of them
	assert_eq(int(_state.call("item_count", "ration_bar")), before + 1, "bought a Ration Bar")
	assert_eq(int(_state.call("get_credits")), 500 - 15)
	menu.close()
	for i: int in 4:
		menu.tick(0.016)
	assert_false(room.hero.frozen)


# ---- the job board ----

func test_the_job_board_takes_a_slice_job() -> void:
	var room: ActionRoom = await _start()
	var board: JobBoard = room.find_child("Board", true, false) as JobBoard
	assert_eq(board.job_ids(), ["gb_job"] as Array[String], "the slice's jobs file is laid over the old one")
	assert_eq(board.job_state("gb_job"), "available")
	await _stand_before(room, board, 1.0)
	assert_true(room.interactor.try_interact())
	assert_true(ExplorationKit.to_choice(room))
	ExplorationKit.answer(room, 0)
	for i: int in 4:
		room.runner.tick(0.1)
	assert_eq(board.job_state("gb_job"), "taken")
	assert_true(bool(_state.call("get_flag", "gb_job_taken")))
	assert_false(room.hero.frozen)


# ---- the save terminal and rest ----

func test_the_save_terminal_rests_and_saves_with_the_hero_state() -> void:
	var room: ActionRoom = await _start()
	room.hero.hp = 30
	var terminal: SaveLamp = room.find_child("Terminal", true, false) as SaveLamp
	assert_not_null(terminal)
	terminal.read_engine_input = false
	await _stand_before(room, terminal, 0.8)
	assert_true(room.interactor.try_interact(), "the terminal takes the interact button")
	assert_true(terminal.is_checking())
	assert_true(room.hero.frozen)
	terminal.skip()
	var prompt: SavePrompt = terminal.get_prompt() as SavePrompt
	assert_not_null(prompt)
	prompt.finish_animations()
	assert_eq(room.hero.hp, room.hero.hp_max, "resting healed Red")
	prompt.handle_command(MenuInput.Cmd.CONFIRM)
	prompt.handle_command(MenuInput.Cmd.CONFIRM)
	prompt.finish_animations()
	for i: int in 8:
		await tree.process_frame
	assert_true(FileAccess.file_exists(_save_dir + "/slot_1.json"), "slot 1 was written under the slice's save folder")
	assert_false(room.hero.frozen)


func test_a_save_remembers_the_sword_the_hacks_and_her_health_and_loads_them_back() -> void:
	var room: ActionRoom = await _start()
	room.hero.hp = 77
	var sword_ids: Array = DataDB.get_dict("combat/swords").get("swords", {}).keys()
	var held: StringName = room.hero.current_sword()
	var other: StringName = held
	for id: Variant in sword_ids:
		if StringName(str(id)) != held and room.hero.equip_sword(StringName(str(id))):
			other = StringName(str(id))
			break
	assert_true(bool(_state.call("has_hack", "emp")), "a slice New Game starts with the pitch's four hacks")
	assert_true(_manager.call("save_slot", 1))
	var file: Dictionary = (_manager.call("read_file", 1) as Dictionary)["game"]
	assert_eq(int(file["save_version"]), 3)
	assert_eq(file["hacks"], ["zap_drone", "emp", "overclock", "reboot"])
	assert_eq(int(file["hero_hp"]), 77, "her live health was flushed into the file")
	assert_eq(file["sword"], String(other))
	_state.call("reset")
	assert_false(bool(_state.call("has_hack", "emp")))
	assert_true(_manager.call("load_slot", 1))
	assert_true(bool(_state.call("has_hack", "emp")))
	var session: Dictionary = (_state.get("slice_run") as Dictionary)["session"]
	assert_eq(int(session["hp"]), 77)
	assert_eq(str(session["sword"]), String(other))


# ---- the field menu from the pause menu ----

func test_the_hud_pause_menu_opens_the_field_menu_and_a_heal_item_heals_red() -> void:
	var room: ActionRoom = await _start()
	var hud: Node = room.get_hud()
	assert_not_null(hud, "the persistent HUD is up")
	assert_true(hud.is_connected("field_menu_requested", room.open_field_menu), "the pause menu's Menu row opens the field menu")
	room.hero.hp = 40
	_state.call("add_item", "ration_bar", 1)
	var menu: FieldMenu = room.field_menu
	menu.manual_ticks = true
	menu.animations_enabled = false
	assert_false(menu.listen_open_action, "the menu button is not the slice's menu button")
	hud.emit_signal("field_menu_requested")
	assert_true(menu.is_open())
	assert_true(room.hero.frozen)
	var ids: Array[String] = []
	for row: Dictionary in menu.get_main_list().get_items():
		ids.append(str(row["id"]))
	assert_eq(ids, ["items", "sword", "config", "save"] as Array[String], "Party, Skills and Status are hidden: Red alone")
	# Items page: use the ration bar on Red.
	menu.get_main_list().set_index(0, false)
	menu.get_main_list().activate()
	assert_eq(menu.get_page(), "items")
	var page: PageItems = menu.get_page_object() as PageItems
	var list: MenuList = page.primary_list()
	for i: int in list.get_count():
		if list.get_item_id(i) == "ration_bar":
			list.set_index(i, false)
	menu.handle_command(MenuInput.Cmd.CONFIRM)          # pick the item
	menu.handle_command(MenuInput.Cmd.CONFIRM)          # on Red
	menu.close()
	for i: int in 4:
		menu.tick(0.016)
	assert_gt(room.hero.hp, 40, "the live Red was healed through the menu")
	assert_false(room.hero.frozen)


func test_the_sword_page_puts_a_sword_in_her_hand() -> void:
	var room: ActionRoom = await _start()
	var menu: FieldMenu = room.field_menu
	menu.manual_ticks = true
	menu.animations_enabled = false
	assert_true(room.open_field_menu())
	menu.get_main_list().set_index(1, false)
	menu.get_main_list().activate()
	assert_eq(menu.get_page(), "sword")
	var page: PageSword = menu.get_page_object() as PageSword
	var list: MenuList = page.primary_list()
	assert_gt(list.get_count(), 1, "the swords from swords.json")
	var held: StringName = room.hero.current_sword()
	var target: int = -1
	for i: int in list.get_count():
		if StringName(list.get_item_id(i)) != held:
			target = i
	if target < 0 or held == &"":
		menu.close()
		return          # no sword art in this build
	list.set_index(target, false)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(room.hero.current_sword(), StringName(list.get_item_id(target)))
	assert_eq(str(((_state.get("slice_run") as Dictionary)["session"] as Dictionary)["sword"]), list.get_item_id(target))
	menu.close()
	for i: int in 4:
		menu.tick(0.016)


func test_the_menu_button_does_not_open_the_field_menu_in_the_slice() -> void:
	var room: ActionRoom = await _start()
	var menu: FieldMenu = room.field_menu
	var press: InputEventAction = InputEventAction.new()
	press.action = &"menu"
	press.pressed = true
	menu._input(press)
	assert_false(menu.is_open(), "Tab / C / pad Y are lock-on and the hack button in the slice")


func test_a_combat_room_stands_still_while_the_field_menu_is_open() -> void:
	await _start()
	_router.call("go_to", "gb_yard", "from_hub")
	var yard: ActionRoom = await _until_room("gb_yard")
	var menu: FieldMenu = yard.field_menu
	menu.manual_ticks = true
	menu.animations_enabled = false
	assert_true(yard.open_field_menu())
	assert_true(tree.paused, "enemies do not move while she is in the menu")
	menu.close()
	for i: int in 4:
		menu.tick(0.016)
	yard._release_menu_hold()
	assert_false(tree.paused)
