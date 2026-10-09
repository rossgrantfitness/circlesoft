extends TestCase
## VS-5, ActionRoom: one room script driven by the rooms file. Three throwaway graybox rooms joined by doors in data
## (data/slice/graybox_rooms.json: a town hub, a yard with enemies, a vault checkpoint) prove the camera and combat
## switches, the director in every room, the old Door and StoryDirector working in it, health and sword carried through
## doors, the persistent HUD re-binding, and the knock-out rule (Decision 2, recommended A) as a data switch.

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"

var _main: Main = null
var _router: Node = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")


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
	Placements.extra_job_ids = []
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	for action: StringName in [&"light", &"interact", &"jump"]:
		Input.action_release(action)


## A slice-mode Main pointed at the graybox rooms, a New Game in the hub.
func _start() -> void:
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
	_main.start_new_game()
	await _until_room("gb_hub")


func _until_room(room_id: String, limit: int = 120) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func _room() -> ActionRoom:
	return _main.get_room() as ActionRoom


func _go(room_id: String, spawn: String) -> void:
	_router.call("go_to", room_id, spawn)
	await _until_room(room_id)


func _door(room: ActionRoom, placement: String) -> Door:
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == placement:
			return node as Door
	return null


func _kill(hero: ActionPlayer) -> void:
	hero.apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})


# ---- the data ----

func test_the_graybox_rooms_file_is_consistent() -> void:
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID)["rooms"]
	var doors: Dictionary = DataDB.get_dict(PLACEMENTS_ID)["doors"]
	for room_id: String in rooms:
		var entry: Dictionary = rooms[room_id]
		assert_true(ResourceLoader.exists(str(entry["scene"])), "%s scene" % room_id)
		assert_has(entry["spawns"], entry["default_spawn"])
	for door_id: String in doors:
		var door: Dictionary = doors[door_id]
		assert_true(rooms.has(door["to_room"]), "%s leads somewhere that exists" % door_id)
		assert_has(rooms[door["to_room"]]["spawns"], door["to_spawn"], "%s lands on a spawn that exists" % door_id)


# ---- the three kinds of room ----

func test_a_town_room_has_the_diorama_camera_a_director_and_no_fighting() -> void:
	await _start()
	var room: ActionRoom = _room()
	assert_not_null(room, "Main wrapped the plain level in an ActionRoom")
	assert_eq(room.room_id, "gb_hub")
	assert_false(room.is_combat())
	assert_not_null(room.get_director(), "a director even in town")
	assert_not_null(room.get_player())
	assert_true(room.get_player() is ActionPlayer)
	assert_null(room.get_lock_on(), "no lock-on in town")
	assert_null(room.get_camera(), "no orbit camera in town")
	assert_not_null(room.camera_rig, "the fixed diorama camera")
	assert_eq(room.get_camera_3d(), room.camera_rig.get_camera())
	assert_true(room.hero.town_mode, "attacks and hacks are off")
	assert_false(room.interactor.combat_room)
	assert_eq(room.get_enemies().size(), 0)
	assert_eq(room.hero.camera, room.get_camera_3d(), "her run is camera-relative to the room camera")
	assert_eq(room.hero.death_mode, &"retry")


func test_a_dungeon_room_has_orbit_camera_lock_on_and_its_enemies() -> void:
	await _start()
	await _go("gb_yard", "from_hub")
	var room: ActionRoom = _room()
	assert_true(room.is_combat())
	assert_not_null(room.get_lock_on())
	assert_not_null(room.get_camera())
	assert_eq(room.get_camera_3d(), room.get_camera().get_camera())
	assert_false(room.hero.town_mode)
	assert_true(room.interactor.combat_room)
	assert_eq(room.get_enemies().size(), 2, "the two grunts in the rooms file")
	assert_eq(room.get_director().living_enemies().size(), 2, "and they are registered with this room's director")
	assert_eq(room.hero.lock_on, room.get_lock_on())
	var spawn: Marker3D = room.find_spawn("from_hub")
	assert_lt(room.hero.global_position.distance_to(spawn.global_position), 0.6, "Red starts on the spawn the door named")


func test_the_host_methods_the_hud_and_fx_bind_to() -> void:
	await _start()
	var room: ActionRoom = _room()
	for method: String in ["get_director", "get_player", "get_lock_on", "get_camera", "get_feel", "screen_pos_of", "get_ui_parent",
			"get_room_id", "get_robot_stage", "reset_arena"]:
		assert_true(room.has_method(method), method)
	assert_not_null(room.get_feel())
	assert_not_null(room.get_ui_parent())
	assert_eq(room.get_robot_stage(), null)
	await tree.physics_frame
	var at: Vector2 = room.screen_pos_of(&"red", &"head")
	assert_ne(at, Vector2.ZERO, "Red's head is somewhere on the stage")
	assert_eq(room.screen_pos_of(&"nobody"), Vector2.ZERO)


func test_the_look_profile_in_the_room_entry_is_applied() -> void:
	await _start()
	assert_eq(LookProfiles.active_id(), "grim_ps2")


# ---- doors and carrying ----

func test_a_door_in_data_takes_red_to_the_next_room() -> void:
	await _start()
	var room: ActionRoom = _room()
	var door: Door = _door(room, "gb_hub_to_yard")
	assert_not_null(door, "the old Door finds its ActionRoom")
	assert_eq(door.get_player(), room.hero, "RoomProp.get_player works for an ActionRoom")
	assert_eq(door.get_interactor(), room.interactor)
	door.use(room.hero, room.interactor)
	await _until_room("gb_yard")
	assert_eq(_room().room_id, "gb_yard")
	assert_eq(str(_router.get("current_spawn_id")), "from_hub")
	assert_eq(_state.call("get_location"), {"room": "gb_yard", "spawn": "from_hub"})


func test_walking_into_a_door_works_with_the_action_red() -> void:
	await _start()
	var room: ActionRoom = _room()
	var door: Door = _door(room, "gb_hub_to_yard")
	room.hero.read_engine_input = false
	room.hero.global_position = door.global_position + Vector3(0.0, 0.05, 1.6)
	room.hero.velocity = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	for i: int in 90:
		room.hero.set_move_input(Vector2(0.0, -1.0))
		await tree.physics_frame
		if _room() != room:
			break
	await _until_room("gb_yard")
	assert_eq(_room().room_id, "gb_yard", "she walked into the door")


func test_health_and_sword_are_carried_through_doors() -> void:
	await _start()
	var room: ActionRoom = _room()
	var full: int = room.hero.hp_max
	room.hero.hp = 70
	var sword: StringName = room.hero.current_sword()
	await _go("gb_yard", "from_hub")
	var yard: ActionRoom = _room()
	assert_eq(yard.hero.hp, 70, "she walked in with the health she had")
	assert_lt(yard.hero.hp, full)
	assert_eq(yard.hero.current_sword(), sword)
	assert_eq(yard.get_entry_session().hp, 70)
	assert_eq(HeroSession.from_dict((_state.get("slice_run") as Dictionary)["session"]).hp, 70)
	yard.hero.hp = 41
	await _go("gb_vault", "from_yard")
	assert_eq(_room().hero.hp, 41)


func test_a_swapped_sword_is_carried() -> void:
	await _start()
	var room: ActionRoom = _room()
	var swords: Array = DataDB.get_dict("combat/swords").get("swords", {}).keys() if DataDB.get_dict("combat/swords").has("swords") else []
	if swords.is_empty() or room.hero.current_sword() == &"":
		return          # the sword art is not in this build; nothing to carry
	var other: StringName = &""
	for id: Variant in swords:
		if StringName(str(id)) != room.hero.current_sword():
			other = StringName(str(id))
			break
	if other == &"" or not room.hero.equip_sword(other):
		return
	await _go("gb_yard", "from_hub")
	assert_eq(_room().hero.current_sword(), other)


## A stand-in for the hack battery (VS-8) with the three calls ActionRoom uses.
class StubBattery extends RefCounted:
	var value: float = 100.0

	func charge() -> float:
		return value

	func capacity() -> float:
		return 100.0

	func set_charge(amount: float) -> void:
		value = amount


func test_the_battery_is_carried_and_restored_on_a_knock_out() -> void:
	await _start()
	var battery: StubBattery = StubBattery.new()
	_room().battery_override = battery
	battery.value = 62.0
	_room().hero.hp = 80
	_room().save_session()
	assert_almost_eq(HeroSession.from_dict((_state.get("slice_run") as Dictionary)["session"]).battery, 62.0, 0.001)
	_router.call("go_to", "gb_yard", "from_hub")
	await _until_room("gb_yard")
	var yard: ActionRoom = _room()
	var yard_battery: StubBattery = StubBattery.new()
	yard.battery_override = yard_battery
	yard._apply_session()
	assert_almost_eq(yard_battery.value, 62.0, 0.001, "she walked in with 62 charge")
	yard_battery.value = 5.0
	_kill(yard.hero)
	assert_true(yard.continue_after_knockout())
	await _until_room_replaced(yard)
	var again: ActionRoom = _room()
	var again_battery: StubBattery = StubBattery.new()
	again.battery_override = again_battery
	again._apply_session()
	assert_almost_eq(again_battery.value, 62.0, 0.001, "and after the knock-out she has 62 again, not 5")


func test_the_directors_real_battery_is_carried_through_a_door() -> void:
	await _start()
	var battery: Object = _room().get_director().get("battery") as Object
	if battery == null:
		return          # a build without the hack battery (VS-8)
	battery.call("set_charge", 33.0)
	await _go("gb_yard", "from_hub")
	var carried: Object = _room().get_director().get("battery") as Object
	assert_almost_eq(float(carried.call("charge")), 33.0, 0.001, "the charge she left with")


func test_classic_mode_does_not_wrap_rooms() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	assert_eq(_main.get_mode(), GameMode.Mode.CLASSIC)
	assert_false(_main.get_room() is ActionRoom, "the old game's room is a FieldRoom, as before")
	assert_true(_main.get_room() is FieldRoom)


func test_the_form_is_carried_and_a_room_can_force_one() -> void:
	var session: HeroSession = HeroSession.new()
	session.form = &"small"
	assert_eq(session.form_for_room("red"), &"small", "a room that says red does not take her out of the loader")
	assert_eq(session.form_for_room("huge"), &"huge", "a room that names a robot form puts her in it")
	assert_eq(HeroSession.new().form_for_room(""), &"red")


# ---- the persistent HUD ----

func test_one_hud_survives_the_doors_and_rebinds_to_each_room() -> void:
	await _start()
	var first_room: ActionRoom = _room()
	var hud: Node = first_room.get_hud()
	assert_not_null(hud, "the HUD scene in slice.json")
	assert_true(hud.is_in_group(ActionRoom.GROUP_HUD))
	assert_eq(hud.get_meta(ActionRoom.META_HOST), first_room)
	await _go("gb_yard", "from_hub")
	var second_room: ActionRoom = _room()
	assert_eq(second_room.get_hud(), hud, "the same HUD node, not a new one per room")
	assert_eq(hud.get_meta(ActionRoom.META_HOST), second_room, "re-bound to the new room")
	assert_eq(tree.get_nodes_in_group(ActionRoom.GROUP_HUD).size(), 1)
	if "sandbox" in hud:
		assert_eq(hud.get("sandbox"), second_room, "and it listens to the new director")


# ---- Decision 3 in a real room ----

func test_in_the_town_room_the_attack_button_uses_what_is_in_front() -> void:
	await _start()
	var room: ActionRoom = _room()
	var used: Array = []
	var spot: Interactable = Interactable.new()
	spot.kind = Interactable.Kind.EXAMINE
	spot.conversation = "x"
	spot.handler = func(_hero: CharacterBody3D, _interactor: PlayerInteractor) -> bool:
		used.append(1)
		return true
	room.add_child(spot)
	spot.global_position = room.hero.global_position + room.hero.get_facing() * 1.0
	room.hero.read_engine_input = false
	await tree.physics_frame
	room.interactor.refresh()
	room.hero.press(&"light")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(used.size(), 1, "the attack button used it")
	assert_ne(room.hero.get_state(), ActionPlayer.State.ATTACK)


# ---- knock-out ----

func test_a_knock_out_keeps_red_down_and_names_the_rule() -> void:
	await _start()
	await _go("gb_yard", "from_hub")
	var room: ActionRoom = _room()
	var rules: Array[String] = []
	room.knocked_out_rule.connect(func(rule: String) -> void: rules.append(rule))
	_kill(room.hero)
	assert_true(room.hero.is_knocked_out())
	assert_eq(rules, ["room_entrance"] as Array[String])
	for i: int in 240:
		await tree.physics_frame
		if _room() != room:
			break
	assert_true(_room() != room or room.hero.dead, "retry mode: she does not just get up")


func test_continue_restarts_the_room_with_the_health_she_walked_in_with() -> void:
	await _start()
	_room().hero.hp = 66
	_state.call("add_credits", 40)
	await _go("gb_yard", "from_hub")
	var room: ActionRoom = _room()
	assert_eq(room.hero.hp, 66)
	_state.call("add_credits", 15)           # earned in the yard: lost on a restart
	room.hero.global_position = Vector3(3.0, 0.1, 3.0)
	_kill(room.hero)
	assert_true(room.continue_after_knockout())
	await _until_room_replaced(room)
	var again: ActionRoom = _room()
	assert_eq(again.room_id, "gb_yard", "the room's entrance")
	assert_eq(again.hero.hp, 66, "the health and nothing more, not full and not zero")
	assert_false(again.hero.dead)
	assert_false(again.hero.is_knocked_out())
	assert_eq(again.get_enemies().size(), 2, "and the enemies are fresh")
	var spawn: Marker3D = again.find_spawn("from_hub")
	assert_lt(again.hero.global_position.distance_to(spawn.global_position), 0.6, "at the spawn she entered by")
	assert_eq(_state.call("get_credits"), 40, "back to the credits she walked in with; no cost by default")
	assert_false(is_instance_valid(room) and room.continue_after_knockout(), "an old room cannot restart twice")


func test_a_checkpoint_room_restarts_at_its_own_entrance_and_later_rooms_return_to_it() -> void:
	await _start()
	_room().hero.hp = 90
	await _go("gb_yard", "from_hub")
	_room().hero.hp = 55
	await _go("gb_vault", "from_yard")
	var vault: ActionRoom = _room()
	assert_true(vault.is_checkpoint())
	vault.hero.hp = 20
	_kill(vault.hero)
	assert_true(vault.continue_after_knockout())
	await _until_room_replaced(vault)
	assert_eq(_room().room_id, "gb_vault")
	assert_eq(_room().hero.hp, 55, "the health she had when she walked into the vault")
	# Back out to the yard, which is not a checkpoint: a knock-out there returns to the vault checkpoint.
	await _go("gb_yard", "from_vault")
	var yard: ActionRoom = _room()
	_kill(yard.hero)
	assert_true(yard.continue_after_knockout())
	await _until_room_replaced(yard)
	assert_eq(_room().room_id, "gb_vault", "the last checkpoint")
	assert_eq(_room().hero.hp, 55)


func test_the_credit_cost_is_a_data_switch() -> void:
	await _start()
	_state.call("add_credits", 100)
	await _go("gb_yard", "from_hub")
	var room: ActionRoom = _room()
	room._slice["retry"] = {"rule": "room_entrance", "credit_cost": 25, "auto_continue_s": 0.0}
	_kill(room.hero)
	assert_true(room.continue_after_knockout())
	assert_eq(_state.call("get_credits"), 75, "option C: a small cost")


func test_the_rule_none_lets_her_get_up_like_the_sandbox() -> void:
	var rules_none: Dictionary = {"rule": "none"}
	await _start()
	var room: ActionRoom = _room()
	room._slice["retry"] = rules_none
	assert_eq(room._death_mode(), &"sandbox")
	room._slice["retry"] = {"rule": "room_entrance"}
	assert_eq(room._death_mode(), &"retry")


func test_the_auto_continue_timer_stands_in_for_the_continue_screen() -> void:
	await _start()
	await _go("gb_yard", "from_hub")
	var room: ActionRoom = _room()
	room._slice["retry"] = {"rule": "room_entrance", "auto_continue_s": 0.2}
	_kill(room.hero)
	await _until_room_replaced(room, 120)
	assert_ne(_room(), room, "the room restarted by itself")


func _until_room_replaced(old: ActionRoom, limit: int = 120) -> void:
	for i: int in limit:
		await tree.physics_frame
		var now: ActionRoom = _main.get_room() as ActionRoom
		if now != null and now != old and now.hero != null and not bool(_router.call("is_busy")):
			await tree.physics_frame
			return
	fail("the room never restarted")


# ---- the story director still works in an ActionRoom ----

func test_the_story_director_is_set_up_in_an_action_room() -> void:
	await _start()
	var room: ActionRoom = _room()
	assert_not_null(room.story)
	assert_eq(room.story.room, room)


func test_the_story_director_walks_the_action_red_and_gives_her_back() -> void:
	await _start()
	var room: ActionRoom = _room()
	room.story.instant = true
	var goal: Vector2 = Vector2(room.hero.global_position.x + 2.0, room.hero.global_position.z)
	await room.story._steps([{"do": "move", "actor": "red", "to": [goal.x, goal.y]}])
	assert_almost_eq(room.hero.global_position.x, goal.x, 0.05, "the scene moved her")
	assert_false(room.hero.scripted, "and handed control back")
	assert_eq(room.hero.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
