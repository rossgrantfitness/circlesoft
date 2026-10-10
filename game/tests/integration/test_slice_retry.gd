extends TestCase
## VS-16, knock-out and retry (Decision 2, recommended A): RoomSnapshot puts back items, credits, flags and opened ids, sticky
## puzzle ids survive, the Continue screen is wired to the room, and the rule is a data switch. Health, battery and credit
## cost are also covered in test_action_room.gd.

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"

var _main: Main = null
var _router: Node = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	InputSorting.revert()
	SandboxPauseGate.clear(tree)
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()


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
	_main.start_new_game()
	return await _until_room("gb_hub")


func _until_room(room_id: String, limit: int = 120) -> ActionRoom:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func _until_replaced(old: ActionRoom, limit: int = 120) -> ActionRoom:
	for i: int in limit:
		await tree.physics_frame
		var now: ActionRoom = _main.get_room() as ActionRoom
		if now != null and now != old and now.hero != null and not bool(_router.call("is_busy")):
			await tree.physics_frame
			return now
	fail("the room never restarted")
	return null


func _kill(hero: ActionPlayer) -> void:
	hero.apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})


func _enter_yard() -> ActionRoom:
	_router.call("go_to", "gb_yard", "from_hub")
	return await _until_room("gb_yard")


# ---- RoomSnapshot in a real restart ----

func test_a_restart_puts_back_items_flags_and_opened_ids() -> void:
	await _start()
	_state.call("add_item", "ration_bar", 1)
	_state.call("add_credits", 30)
	_state.call("set_flag", "before_the_yard")
	var rations_in: int = int(_state.call("item_count", "ration_bar"))
	var yard: ActionRoom = await _enter_yard()
	_state.call("add_item", "ration_bar", 4)
	_state.call("add_item", "juice_box", 1)
	_state.call("add_credits", 100)
	_state.call("set_flag", "found_in_the_yard")
	_state.call("mark_opened", "pickup_in_the_yard")
	_kill(yard.hero)
	assert_eq(int(_state.call("item_count", "ration_bar")), rations_in + 4, "sanity: the rations picked up in the yard are in the bag")
	assert_true(yard.continue_after_knockout())
	var again: ActionRoom = await _until_replaced(yard)
	assert_eq(again.room_id, "gb_yard")
	assert_eq(int(_state.call("item_count", "ration_bar")), rations_in, "back to the rations she walked in with")
	assert_eq(int(_state.call("item_count", "juice_box")), 0, "the juice box picked up in the yard is back on the floor")
	assert_eq(int(_state.call("get_credits")), 30)
	assert_true(bool(_state.call("get_flag", "before_the_yard")))
	assert_false(bool(_state.call("get_flag", "found_in_the_yard")), "a flag set in the yard is cleared")
	assert_false(bool(_state.call("is_opened", "pickup_in_the_yard")))


func test_sticky_puzzle_flags_survive_a_restart() -> void:
	await _start()
	var yard: ActionRoom = await _enter_yard()
	assert_has(yard.sticky_ids(), "gb_fuse_open", "the fuse box is marked sticky in the placements")
	_state.call("set_flag", "gb_fuse_open")
	_state.call("set_flag", "ordinary_flag")
	_kill(yard.hero)
	assert_true(yard.continue_after_knockout())
	await _until_replaced(yard)
	assert_true(bool(_state.call("get_flag", "gb_fuse_open")), "an opened fuse-box door stays open")
	assert_false(bool(_state.call("get_flag", "ordinary_flag")))


func test_a_sticky_door_stays_open() -> void:
	await _start()
	var yard: ActionRoom = await _enter_yard()
	var ids: Array = yard.sticky_ids()
	assert_does_not_have(ids, "door_gb_yard_to_hub", "doors are only sticky when the placement says so")


# ---- the Continue screen ----

func test_the_knock_out_opens_the_continue_screen_and_continue_restarts() -> void:
	await _start()
	var yard: ActionRoom = await _enter_yard()
	var hud: Node = yard.get_hud()
	var screen: ContinueScreen = hud.call("get_continue_screen") as ContinueScreen
	assert_not_null(screen)
	assert_false(screen.is_open())
	_kill(yard.hero)
	assert_true(screen.is_open(), "the HUD opened the Continue screen on the knock-out")
	assert_eq(float(yard.get("_ko_timer")), -1.0, "no auto-continue is running: the screen waits for her")
	screen.continue_chosen.emit()
	var again: ActionRoom = await _until_replaced(yard)
	assert_eq(again.room_id, "gb_yard")
	assert_false(screen.is_open(), "closed once the restart began")
	SandboxPauseGate.clear(tree)


func test_the_auto_continue_stand_in_is_off_in_the_shipped_data() -> void:
	assert_eq(float(DataDB.get_value("slice/slice", "retry.auto_continue_s", -1.0)), 0.0)


# ---- the rule is data ----

func test_the_rule_none_means_no_continue_screen_and_she_gets_up() -> void:
	await _start()
	var yard: ActionRoom = await _enter_yard()
	yard._slice["retry"] = {"rule": "none"}
	yard.hero.set_death_mode(yard._death_mode())
	var screen: ContinueScreen = yard.get_hud().call("get_continue_screen") as ContinueScreen
	_kill(yard.hero)
	assert_false(screen.is_open())
	assert_false(yard.hero.is_knocked_out())
	for i: int in 240:
		await tree.physics_frame
	assert_false(yard.hero.dead, "she got up on her own, as in the sandbox")


func test_rest_at_a_terminal_wipes_the_carried_damage() -> void:
	await _start()
	_state.set("slice_run", {"session": {"hp": 20, "sword": "machete"}})
	_state.call("rest_party")
	var session: Dictionary = (_state.get("slice_run") as Dictionary)["session"]
	assert_eq(int(session["hp"]), 0, "0 reads as full on the next door")
	assert_eq(str(session["sword"]), "machete", "the sword stays")
	assert_eq(HeroSession.from_dict(session).health_for(120), 120)
