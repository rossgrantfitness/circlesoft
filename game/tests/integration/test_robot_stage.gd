extends TestCase
## VS-21: RobotStage, the robots of a slice room. Robots are placed from robot_rooms data, boarding starts from a script or a
## hack (the loader's wake button), a room can start with Red already inside a robot (place_in), docking and climbing out are
## scriptable, and the hacks are off in robot forms. The CS-21 code (RobotYard, ScaleController, RobotBoarding) does the work; these
## tests prove the stage drives it. The real-room tests go through Main and the graybox rooms (gb_loader, gb_cab).

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"

var _kit: RobotStageKit = null
var _state: Node = null
var _main: Main = null
var _router: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_state.call("reset")


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_main = null
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = [] as Array[String]
	Placements.extra_job_ids = [] as Array[String]
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()


func _loader_data(sleeping: bool = true, with_colossus: bool = false) -> Dictionary:
	var small: Dictionary = {"pos": [0.0, 0.0, 10.0], "yaw_deg": 0.0}
	if sleeping:
		small["wake_flag"] = "loader_awake"
	var data: Dictionary = {"ground": false, "small_robot": small, "props": [{"kind": "crate_small", "pos": [6.0, 0.0, 6.0], "yaw_deg": 0.0},
			{"kind": "car", "pos": [-8.0, 0.0, 6.0], "yaw_deg": 0.0}]}
	if with_colossus:
		data["huge_robot"] = {"pos": [0.0, 0.0, 120.0], "yaw_deg": 180.0}
	return data


func _flag(id: String) -> bool:
	return bool(_state.call("get_flag", id))


# ---- the data ----

func test_the_two_junkyard_robot_rooms_are_wellformed() -> void:
	var j4: Dictionary = DataDB.get_dict("slice/robot_rooms/junk_j4")
	var j5: Dictionary = DataDB.get_dict("slice/robot_rooms/junk_j5")
	for doc: Dictionary in [j4, j5]:
		assert_false(bool(doc.get("ground", true)), "the level supplies the floor")
		assert_true(doc.has("small_robot"), "the loader")
		assert_false(doc.has("huge_robot"), "no colossus until the arena")
		var pos: Array = (doc["small_robot"] as Dictionary)["pos"]
		assert_eq(pos.size(), 3)
	assert_true((j4["small_robot"] as Dictionary).has("wake_flag"), "J4's loader sleeps")
	assert_false((j5["small_robot"] as Dictionary).has("wake_flag"), "J5 starts inside it")
	var kinds: Dictionary = DataDB.get_dict("combat/robot_yard")["kinds"]
	for raw: Variant in j5["props"]:
		assert_true(kinds.has(str((raw as Dictionary)["kind"])), "J5 prop kinds exist in the yard file")


# ---- building it ----

func test_the_stage_places_the_loader_and_the_props_from_data_and_builds_no_ground() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	var stage: RobotStage = _kit.stage
	assert_true(stage.is_in_group(RobotStage.GROUP))
	assert_not_null(stage.yard.small_display, "the loader")
	assert_null(stage.yard.huge_display, "no colossus in this room")
	assert_almost_eq(stage.yard.small_display.global_position.z, 10.0, 0.01, "where the data put it")
	assert_eq(stage.yard.props.size(), 2)
	assert_null(stage.yard.get_node_or_null("Ground"), "ground false: the level's own floor")
	assert_true(stage.yard.missing.is_empty(), "nothing missing: %s" % [stage.yard.missing])
	assert_eq(stage.form(), &"red")
	assert_eq(stage.mode(), RobotBoarding.Mode.RED)
	assert_false(stage.is_in_robot())


func test_the_stage_reuses_the_cs21_scale_numbers() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false))
	_kit.stage.place_in(&"small")
	_kit.step(4)
	assert_eq(_kit.player.get_form_id(), &"small")
	assert_almost_eq(_kit.player.get_scale_profile().height_m(), ScaleProfile.get_form(&"small").height_m(), 0.001)
	assert_eq(_kit.stage.controller.get_form().id, &"small", "the same ScaleController and scale_profiles.json")


# ---- the sleeping loader and the wake button ----

func test_a_sleeping_loader_does_not_board_when_red_walks_into_its_ring() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	var ring: Vector3 = _kit.stage.yard.small_display.boarding_point()
	_kit.place(ring + Vector3(0, 0.02, 0), 0.0)
	_kit.step(60)
	assert_false(_kit.stage.is_awake())
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED, "she stands in the ring and nothing happens")
	assert_eq(_kit.stage.boarding.compute_prompt(), "", "and no prompt")
	assert_eq(_kit.player.get_form_id(), &"red")


func test_waking_the_loader_sets_a_saved_flag_and_lets_her_board_by_walking_in() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	var woke: Array[bool] = []
	_kit.stage.woke.connect(func() -> void: woke.append(true))
	assert_true(_kit.stage.wake())
	assert_false(_kit.stage.wake(), "only wakes once")
	assert_eq(woke.size(), 1)
	assert_true(_flag("loader_awake"), "in GameState, so a save keeps it")
	assert_true(_kit.stage.is_awake())
	var ring: Vector3 = _kit.stage.yard.small_display.boarding_point()
	_kit.place(ring + Vector3(0, 0.02, 0), 0.0)
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.SMALL, 600)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "walked in and boarded")
	assert_eq(_kit.player.get_form_id(), &"small")


func test_a_loader_woken_in_an_earlier_visit_is_awake_in_a_new_stage() -> void:
	_state.call("set_flag", "loader_awake", true)
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	assert_true(_kit.stage.is_awake())
	assert_true(_kit.stage.boarding.boarding_enabled)
	assert_false(_kit.stage.wake(), "already awake")


func test_the_wake_button_wakes_the_loader_and_starts_the_boarding_sequence() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	var button: HackLoader = HackLoader.new()
	button.target_id = &"loader_j4"
	button.data = {"flag": "loader_awake", "accepts": ["interact"]}
	button.stage = _kit.stage
	add_to_root(button)
	button.position = Vector3(2, 0, 6)
	_kit.place(Vector3(2.0, 0.02, 4.0), 0.0)
	assert_not_null(button.interactable, "the button finds an Interactable")
	assert_true(button.can_take(&"interact"))
	var woke: Array[StringName] = []
	button.woke.connect(func(id: StringName) -> void: woke.append(id))
	var started: Array[bool] = []
	_kit.stage.boarding_started.connect(func() -> void: started.append(true))
	assert_true(button.interactable.handler.call(_kit.player, null), "pressing it")
	assert_eq(woke, [&"loader_j4"] as Array[StringName])
	assert_eq(_kit.mode(), RobotBoarding.Mode.BOARDING, "the boarding sequence is running")
	assert_eq(started.size(), 1)
	assert_true(_flag("loader_awake"))
	assert_true(button.is_done(), "the button is spent")
	assert_false(button.interactable.is_in_group(Interactable.GROUP), "no prompt any more")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.SMALL, 900)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "Red is in the loader")
	assert_eq(_kit.stage.form(), &"small")
	assert_true(_kit.forms.has(&"small"), "form_changed told the room")


func test_a_script_can_start_the_boarding_without_the_button() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data())
	_kit.place(Vector3(4.0, 0.02, 3.0), 0.0)
	assert_true(_kit.stage.board(), "a script boards her (and wakes the loader first)")
	assert_true(_kit.stage.is_awake())
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.SMALL, 900)
	assert_eq(_kit.player.get_form_id(), &"small")
	assert_false(_kit.stage.board(), "already inside: nothing to start")


# ---- starting inside a robot ----

func test_place_in_small_starts_inside_the_loader_with_no_sequence() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false))
	_kit.forms.clear()
	assert_true(_kit.stage.place_in(&"small"))
	assert_eq(_kit.stage.form(), &"small")
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "straight to the loader's control")
	assert_eq(_kit.player.get_form_id(), &"small")
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
	assert_false(_kit.player.input_locked)
	assert_false(_kit.stage.yard.small_display.is_active(), "the parked loader is hidden: she is wearing it")
	assert_eq(_kit.forms, [&"small"] as Array[StringName], "form_changed tells the room once")
	_kit.step(30)
	assert_true(_kit.stage.is_in_robot())
	assert_gt(_kit.player.get_scale_profile().height_m(), 3.0, "3.5 m tall")


func test_place_in_huge_and_back_to_red() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false, true))
	assert_true(_kit.stage.place_in(&"huge"))
	assert_eq(_kit.mode(), RobotBoarding.Mode.HUGE)
	assert_eq(_kit.player.get_form_id(), &"huge")
	assert_false(_kit.stage.yard.huge_display.is_active())
	assert_false(_kit.stage.yard.small_display.is_active(), "the loader is docked inside the colossus: nothing parked to see")
	assert_true(_kit.stage.place_in(&"red"))
	assert_eq(_kit.player.get_form_id(), &"red")
	assert_true(_kit.stage.yard.huge_display.is_active())
	assert_false(_kit.stage.place_in(&"giant"), "an unknown form is refused")


# ---- hacks are off in robot forms ----

func test_hacks_are_off_in_robot_forms_and_come_back_on_foot() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false))
	_kit.director.battery.set_charge(100.0)
	var caster: HackCaster = _kit.player.hack_caster()
	assert_not_null(caster)
	assert_true(caster.cast_direct(&"emp"), "on foot a request is made")
	_kit.step(90)
	_kit.director.battery.set_charge(100.0)
	_kit.stage.place_in(&"small")
	_kit.step(4)
	assert_false(caster.cast_direct(&"emp"), "in the loader the hack button does nothing")
	assert_false(caster.cast_direct(&"zap_drone"))
	_kit.stage.place_in(&"red")
	_kit.step(4)
	assert_true(caster.cast_direct(&"emp"), "back on foot, hacks work again")


# ---- docking and climbing out ----

func test_the_loader_docks_with_the_colossus_on_a_script_and_climbs_out_again() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false, true), Vector3(0, 0.02, 100.0))
	assert_not_null(_kit.stage.yard.huge_display, "the colossus is in this room")
	_kit.stage.place_in(&"small")
	_kit.place(Vector3(0, 0.02, 80.0), 0.0)
	assert_true(_kit.stage.dock(), "the boss transition starts the docking")
	assert_eq(_kit.mode(), RobotBoarding.Mode.DOCKING)
	assert_false(_kit.stage.dock(), "not twice")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.HUGE, 900)
	assert_eq(_kit.mode(), RobotBoarding.Mode.HUGE, "docked: Red is the colossus")
	assert_eq(_kit.stage.form(), &"huge")
	assert_eq(_kit.player.get_form_id(), &"huge")
	assert_true(_kit.forms.has(&"huge"))


func test_climbing_out_puts_her_on_foot_and_the_loader_back_in_the_room() -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_loader_data(false))
	_kit.stage.place_in(&"small")
	_kit.place(Vector3(10.0, 0.02, 30.0), 0.0)
	_kit.stage.disembark()
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.RED, 900)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	assert_eq(_kit.player.get_form_id(), &"red")
	assert_true(_kit.stage.yard.small_display.is_active(), "the loader stays parked where she climbed out")
	assert_lt(_kit.stage.yard.small_display.global_position.distance_to(Vector3(10.0, 0.0, 30.0)), 1.0)


# ---- inside a real room ----

func _start_room(room_id: String, hurt_to: int = 0) -> void:
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
	if hurt_to > 0:
		(_main.get_room() as ActionRoom).hero.hp = hurt_to
	_router.call("go_to", room_id, "from_hub")
	await _until_room(room_id)


func _until_room(room_id: String, limit: int = 160) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func test_a_room_whose_entry_names_robots_gets_a_stage_and_other_rooms_do_not() -> void:
	await _start_room("gb_loader")
	var room: ActionRoom = _main.get_room() as ActionRoom
	assert_not_null(room.get_robot_stage(), "gb_loader names robots")
	assert_true(room.get_robot_stage() is RobotStage)
	assert_eq(room.get_robot_stage().get_parent(), room)
	assert_eq(room.get_form(), &"red")
	assert_true(room.saving_blocked(), "robot rooms are not save points")
	assert_false((room.get_robot_stage() as RobotStage).is_awake(), "the loader sleeps")
	_router.call("go_to", "gb_yard", "from_hub")
	await _until_room("gb_yard")
	assert_null((_main.get_room() as ActionRoom).get_robot_stage(), "a room with no robots has no stage")


func test_a_room_that_starts_in_the_loader_puts_red_in_it_and_carries_the_form_on() -> void:
	await _start_room("gb_cab")
	var room: ActionRoom = _main.get_room() as ActionRoom
	var stage: RobotStage = room.get_robot_stage() as RobotStage
	assert_not_null(stage)
	assert_eq(room.get_form(), &"small")
	assert_eq(room.hero.get_form_id(), &"small", "Red is the loader")
	assert_eq(stage.mode(), RobotBoarding.Mode.SMALL)
	assert_false(stage.yard.small_display.is_active())
	assert_eq(room.capture_session().form, &"small", "the next room hears that she is still in it")
	assert_true(room.saving_blocked())
	assert_eq(room.hero.hp, room.hero.hp_max, "full health in the loader's own terms")
	assert_gt(room.hero.hp_max, 200, "the loader's 480, not Red's")
	var caster: HackCaster = room.hero.hack_caster()
	if caster != null:
		room.get_director().battery.set_charge(100.0)
		assert_false(caster.cast_direct(&"emp"), "no hacks in the loader")


func test_a_hurt_red_keeps_her_fraction_of_health_when_a_room_starts_her_in_the_loader() -> void:
	await _start_room("gb_cab", 60)
	var room: ActionRoom = _main.get_room() as ActionRoom
	assert_eq(room.hero.get_form_id(), &"small")
	var red_max: int = int(ScaleProfile.get_form(&"red").merged_player_data(DataDB.get_dict("combat/player_action")).get("hp_max", 120))
	var expected: float = 60.0 / float(red_max) * float(room.hero.hp_max)
	assert_almost_eq(float(room.hero.hp), expected, 1.0, "half health in Red is half health in the loader")
	assert_lt(room.hero.hp, room.hero.hp_max)


func test_the_pause_menus_reset_in_a_robot_room_puts_her_back_in_the_robot() -> void:
	await _start_room("gb_cab")
	var room: ActionRoom = _main.get_room() as ActionRoom
	var stage: RobotStage = room.get_robot_stage() as RobotStage
	stage.disembark()
	for i: int in 400:
		await tree.physics_frame
		if room.hero.get_form_id() == &"red":
			break
	assert_eq(room.hero.get_form_id(), &"red", "she climbed out")
	assert_eq(room.get_form(), &"red", "the room follows the stage")
	room.reset_arena()
	await tree.physics_frame
	assert_eq(room.get_form(), &"small", "reset goes back to how she walked in")
	assert_eq(room.hero.get_form_id(), &"small")


func test_the_dormant_loader_is_woken_by_its_button_inside_a_real_room() -> void:
	await _start_room("gb_loader")
	var room: ActionRoom = _main.get_room() as ActionRoom
	var stage: RobotStage = room.get_robot_stage() as RobotStage
	var button: HackLoader = HackLoader.new()
	button.target_id = &"loader_gb"
	button.data = {"flag": "gb_loader_awake", "accepts": ["interact"]}
	room.add_child(button)
	button.global_position = room.hero.global_position
	await tree.physics_frame
	assert_eq(button.stage, null, "found through the group, not handed over")
	assert_true(button.can_take(&"interact"), "the stage is found in group robot_stage")
	assert_true(button.take_hack(&"interact", {"source": room.hero}))
	assert_true(stage.is_awake())
	for i: int in 900:
		await tree.physics_frame
		if room.hero.get_form_id() == &"small":
			break
	assert_eq(room.hero.get_form_id(), &"small", "boarded in the real room")
	assert_eq(room.get_form(), &"small", "and the room knows")
